"""Processor: GCS upload -> Pub/Sub push -> DLP inspect + de-identify -> Gemini -> BigQuery.

Design rule: the raw note never leaves the PHI project boundary in clear form except to
Sensitive Data Protection. Gemini only ever sees the DE-IDENTIFIED text.
"""
import base64
import datetime as dt
import json
import time
from collections import Counter

from fastapi import FastAPI, Request, Response
from google.cloud import bigquery, dlp_v2, storage

from . import config
from .logs import log

app = FastAPI(title="CareNotes processor")

_storage = storage.Client()
_bq = bigquery.Client(project=config.PROJECT_DATA)
_dlp = dlp_v2.DlpServiceClient()
_genai = None

DLP_PARENT = f"projects/{config.PROJECT_DATA}/locations/{config.REGION}"

SUMMARY_PROMPT = (
    "You are a clinical documentation assistant. Summarize this de-identified visit note "
    "in at most 4 bullet points: reason for visit, key findings, plan, follow-up. "
    "Placeholders like [PERSON_NAME] are intentional; do not try to guess them.\n\nNOTE:\n"
)


def _gemini():
    global _genai
    if _genai is None:
        from google import genai  # imported lazily: only the processor needs it
        _genai = genai.Client(vertexai=True, project=config.PROJECT_APP, location=config.REGION)
    return _genai


def inspect(text: str) -> dict:
    resp = _dlp.inspect_content(request={
        "parent": DLP_PARENT,
        "inspect_template_name": config.DLP_INSPECT_TEMPLATE,
        "item": {"value": text},
    })
    return dict(Counter(f.info_type.name for f in resp.result.findings))


def deidentify(text: str) -> str:
    resp = _dlp.deidentify_content(request={
        "parent": DLP_PARENT,
        "inspect_template_name": config.DLP_INSPECT_TEMPLATE,
        "deidentify_template_name": config.DLP_DEID_TEMPLATE,
        "item": {"value": text},
    })
    return resp.item.value


def summarize(deid_text: str) -> str:
    try:
        resp = _gemini().models.generate_content(model=config.GEMINI_MODEL, contents=SUMMARY_PROMPT + deid_text)
        return (resp.text or "").strip()
    except Exception as exc:  # the pipeline must not fail because the model is unavailable
        log("WARNING", "gemini summary failed", error=str(exc))
        return f"(summary unavailable: {type(exc).__name__})"


def process_object(bucket: str, name: str) -> dict:
    started = time.monotonic()
    note_id = name.rsplit("/", 1)[-1].removesuffix(".txt")
    text = _storage.bucket(bucket).blob(name).download_as_text()

    findings = inspect(text)
    deid = deidentify(text)
    summary = summarize(deid)

    row = {
        "note_id": note_id,
        "object_name": f"gs://{bucket}/{name}",
        "processed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "phi_findings": json.dumps(findings),
        "deidentified_text": deid,
        "summary": summary,
        "processing_ms": int((time.monotonic() - started) * 1000),
        "region": config.REGION,
    }
    errors = _bq.insert_rows_json(config.table("visits"), [row], row_ids=[note_id])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")
    log("INFO", "note processed", note_id=note_id, phi_types=findings, ms=row["processing_ms"])
    return row


@app.post("/pubsub/note")
async def pubsub_note(request: Request) -> Response:
    envelope = await request.json()
    msg = envelope.get("message", {})
    attrs = msg.get("attributes", {})
    if attrs.get("eventType") not in (None, "OBJECT_FINALIZE"):
        return Response(status_code=204)
    obj = json.loads(base64.b64decode(msg.get("data", "")).decode() or "{}")
    name, bucket = obj.get("name", ""), obj.get("bucket", "")
    if not name.startswith("notes/"):
        return Response(status_code=204)  # self-test objects and anything else are ignored
    try:
        process_object(bucket, name)
    except Exception as exc:
        log("ERROR", "processing failed (Pub/Sub will retry, then dead-letter)", object=name, error=str(exc))
        return Response(status_code=500)
    return Response(status_code=204)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "service": "processor"}
