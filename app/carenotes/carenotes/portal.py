"""CareNotes portal — reached only through the global load balancer, Cloud Armor and IAP."""
import datetime as dt
import html
import json
import os
import uuid

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from google.auth.transport import requests as ga_requests
from google.cloud import bigquery, run_v2, storage
from google.oauth2 import id_token

from . import bq as bqh
from . import config, proof
from .hl7 import synthetic_adt
from .logs import log

app = FastAPI(title="CareNotes portal", docs_url=None, redoc_url=None)


@app.middleware("http")
async def chaos(request: Request, call_next):
    """DR drill switch: CHAOS_FAIL=true makes this region fail so the LB fails over."""
    if os.environ.get("CHAOS_FAIL") == "true":
        return JSONResponse({"error": "chaos drill", "region": config.SERVING_REGION}, status_code=503)
    return await call_next(request)

_bq = bigquery.Client(project=config.PROJECT_DATA)
_storage = storage.Client(project=config.PROJECT_DATA)
_req = ga_requests.Request()

SAMPLE_NOTE = """VISIT NOTE — synthetic test data
Patient: Jordan Rivera   DOB: 03/12/1984   SSN: 372-21-4471   MRN: 448812
Phone: (602) 555-0147   Email: jordan.rivera@example.com
Address: 1420 W Camelback Rd, Phoenix, AZ 85013

Chief complaint: persistent cough for 10 days, low-grade fever.
Exam: T 100.1F, mild wheeze right lower lobe, SpO2 96% on room air.
Assessment: acute bronchitis, rule out community-acquired pneumonia.
Plan: chest X-ray today, albuterol inhaler PRN, follow up in 7 days or sooner if worse.
Seen by Dr. Casey Nguyen, NPI 1234567893.
"""


def user(request: Request) -> str:
    """Identity asserted by IAP. The signed JWT is verified (defense in depth)."""
    assertion = request.headers.get("x-goog-iap-jwt-assertion")
    if not assertion:
        return "unauthenticated (direct request?)"
    try:
        claims = id_token.verify_token(
            assertion, _req, audience=config.IAP_AUDIENCE or None,
            certs_url="https://www.gstatic.com/iap/verify/public_key")
        return claims.get("email", "unknown")
    except Exception as exc:
        log("WARNING", "IAP JWT verification failed", error=str(exc))
        raise HTTPException(status_code=401, detail="invalid IAP assertion")


def page(title: str, body: str, who: str, refresh: int | None = None) -> HTMLResponse:
    meta = f'<meta http-equiv="refresh" content="{refresh}">' if refresh else ""
    return HTMLResponse(f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">{meta}
<title>{html.escape(title)} · CareNotes</title>
<style>
:root{{--bg:#f6f7f9;--fg:#18202b;--mut:#5b6675;--card:#fff;--line:#dfe3e8;--acc:#0b6bcb;
--pass:#1a7f37;--fail:#c62828;--warn:#9a6700;--info:#5b6675}}
@media(prefers-color-scheme:dark){{:root{{--bg:#0f1318;--fg:#e6e9ee;--mut:#9aa4b2;--card:#171c23;--line:#2a313b;--acc:#5aa3f0}}}}
*{{box-sizing:border-box}}body{{margin:0;font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--fg)}}
header{{display:flex;gap:20px;align-items:center;padding:14px 20px;border-bottom:1px solid var(--line);background:var(--card);flex-wrap:wrap}}
header b{{font-size:17px}}nav a{{margin-right:14px;color:var(--acc);text-decoration:none}}.who{{margin-left:auto;color:var(--mut);font-size:13px}}
main{{max-width:1080px;margin:0 auto;padding:20px 16px}}.card{{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:18px;margin-bottom:16px}}
textarea{{width:100%;min-height:220px;font:13px ui-monospace,monospace;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--fg)}}
button{{background:var(--acc);color:#fff;border:0;border-radius:8px;padding:9px 16px;font-weight:600;cursor:pointer}}
table{{width:100%;border-collapse:collapse;font-size:14px}}td,th{{text-align:left;padding:8px;border-bottom:1px solid var(--line);vertical-align:top}}
.PASS{{color:var(--pass);font-weight:700}}.FAIL{{color:var(--fail);font-weight:700}}.WARN{{color:var(--warn);font-weight:700}}.INFO{{color:var(--info);font-weight:700}}
.mut{{color:var(--mut);font-size:13px}}pre{{white-space:pre-wrap;font:13px ui-monospace,monospace;margin:0}}
</style></head><body><header><b>CareNotes</b><nav><a href="/">Notes</a><a href="/hl7">HL7 feed</a><a href="/proof">Platform Proof</a></nav>
<span class="who">{html.escape(who)} · served from {html.escape(config.SERVING_REGION)}</span></header><main>{body}</main></body></html>""")


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "service": "portal", "region": config.SERVING_REGION}


@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    who = user(request)
    try:
        rows = bqh.query(_bq, f"SELECT note_id, processed_at, phi_findings FROM `{config.table('visits')}` "
                         "ORDER BY processed_at DESC LIMIT 10")
    except Exception as exc:
        rows = []
        log("WARNING", "visits query failed", error=str(exc))
    recent = "".join(
        f"<tr><td><a href='/note/{html.escape(r.note_id)}'>{html.escape(r.note_id)}</a></td>"
        f"<td>{r.processed_at:%Y-%m-%d %H:%M}</td><td class='mut'>{html.escape(json.dumps(r.phi_findings))}</td></tr>"
        for r in rows) or "<tr><td colspan=3 class='mut'>No notes processed yet.</td></tr>"
    body = f"""<div class="card"><h2>Upload a synthetic visit note</h2>
<p class="mut">Never paste real patient data. The note is stored encrypted with the company key (CMEK),
PHI is found and redacted by Sensitive Data Protection, and only the de-identified text is summarized by Gemini.</p>
<form method="post" action="/upload"><textarea name="note">{html.escape(SAMPLE_NOTE)}</textarea>
<p><button>Process note</button></p></form></div>
<div class="card"><h2>Recent notes</h2><table><tr><th>Note</th><th>Processed (UTC)</th><th>PHI found</th></tr>{recent}</table></div>"""
    return page("Notes", body, who)


@app.post("/upload")
def upload(request: Request, note: str = Form(...)):
    who = user(request)
    if len(note) > 20000:
        raise HTTPException(413, "note too long")
    note_id = dt.datetime.utcnow().strftime("%Y%m%d%H%M%S") + "-" + uuid.uuid4().hex[:6]
    blob = _storage.bucket(config.INTAKE_BUCKET).blob(f"notes/{note_id}.txt")
    blob.metadata = {"uploaded-by": who}
    blob.upload_from_string(note, content_type="text/plain")
    log("INFO", "note uploaded", note_id=note_id, user=who)
    return RedirectResponse(f"/note/{note_id}", status_code=303)


@app.get("/note/{note_id}", response_class=HTMLResponse)
def note(note_id: str, request: Request):
    who = user(request)
    rows = bqh.query(_bq, f"SELECT * FROM `{config.table('visits')}` WHERE note_id = @id LIMIT 1",
                     [bigquery.ScalarQueryParameter("id", "STRING", note_id)])
    if not rows:
        return page("Processing", f"<div class='card'><h2>Processing {html.escape(note_id)}…</h2>"
                    "<p class='mut'>GCS → Pub/Sub → processor → DLP → Gemini → BigQuery. This page refreshes every 3 seconds.</p></div>",
                    who, refresh=3)
    r = rows[0]
    body = f"""<div class="card"><h2>Note {html.escape(r.note_id)}</h2>
<p class="mut">Processed {r.processed_at:%Y-%m-%d %H:%M:%S} UTC in {r.processing_ms} ms ({html.escape(r.region or '')})</p>
<h3>PHI found by Sensitive Data Protection</h3><pre>{html.escape(json.dumps(r.phi_findings, indent=2))}</pre>
<h3>De-identified note</h3><pre>{html.escape(r.deidentified_text or '')}</pre>
<h3>Gemini summary (from the de-identified text only)</h3><pre>{html.escape(r.summary or '')}</pre></div>"""
    return page("Note", body, who)


@app.get("/hl7", response_class=HTMLResponse)
def hl7_page(request: Request):
    who = user(request)
    try:
        rows = bqh.query(_bq, f"SELECT COUNT(*) n, MAX(publish_time) last FROM `{config.table('hl7_messages')}` "
                         "WHERE publish_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)")
        n, last = rows[0].n, rows[0].last
    except Exception:
        n, last = 0, None
    sample = html.escape(synthetic_adt()[0].replace("\r", "\n"))
    body = f"""<div class="card"><h2>HL7 v2 feed</h2>
<p>Hospital systems send ADT messages over <b>MLLP/TLS on TCP 2575</b> — raw TCP, so the interface engine runs on a
<b>regional managed instance group</b> (3 zones, autohealing) behind an <b>internal passthrough load balancer</b>.</p>
<p><b>{n}</b> messages in BigQuery in the last hour{f' (latest {last:%H:%M:%S} UTC)' if last else ''}.</p>
<form method="post" action="/hl7/run"><button>Send {config.HL7_COUNT} HL7 messages</button></form>
<p class="mut">Runs the Cloud Run job <code>{config.HL7_JOB}</code> inside the prod VPC.</p></div>
<div class="card"><h3>Sample message (synthetic)</h3><pre>{sample}</pre></div>"""
    return page("HL7", body, who, refresh=15)


@app.post("/hl7/run")
def hl7_run(request: Request):
    who = user(request)
    client = run_v2.JobsClient()
    name = f"projects/{config.PROJECT_APP}/locations/{config.REGION}/jobs/{config.HL7_JOB}"
    client.run_job(name=name)  # long-running; the page polls BigQuery
    log("INFO", "hl7 simulation started", user=who)
    return RedirectResponse("/hl7", status_code=303)


@app.get("/proof", response_class=HTMLResponse)
def proof_page(request: Request):
    who = user(request)
    report = proof.run_all()
    log("NOTICE", "platform proof run", user=who,
        summary={s: sum(1 for r in report["results"] if r["status"] == s) for s in ("PASS", "FAIL", "WARN", "INFO")})
    rows = "".join(
        f"<tr><td class='{r['status']}'>{r['status']}</td><td><b>{html.escape(r['title'])}</b>"
        f"<div class='mut'>{html.escape(r['control'])} · stage {html.escape(r['stage'])}</div></td>"
        f"<td class='mut'>{html.escape(r['detail'])}</td></tr>" for r in report["results"])
    body = f"""<div class="card"><h2>Platform Proof</h2>
<p class="mut">Live checks of the controls built in Terraform. Guardrail checks deliberately attempt forbidden
actions against self-test targets and PASS only when the platform refuses them. Ran {report['ran_at']}.</p>
<table><tr><th>Result</th><th>Check</th><th>Evidence</th></tr>{rows}</table>
<p class="mut"><a href="/proof.json">JSON</a> · every attempt is also visible in the SIEM and as security alerts.</p></div>"""
    return page("Platform Proof", body, who)


@app.get("/proof.json")
def proof_json(request: Request):
    user(request)
    return JSONResponse(proof.run_all())
