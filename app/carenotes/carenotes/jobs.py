"""Cloud Run jobs: hl7-sim (MLLP/TLS sender) and daily-report (analytics + de-identified export)."""
import csv
import datetime as dt
import io
import json
import time

from . import config
from .logs import log


def _secret(name: str) -> str:
    from google.cloud import secretmanager
    client = secretmanager.SecretManagerServiceClient()
    path = f"projects/{config.PROJECT_APP}/secrets/{name}/versions/latest"
    return client.access_secret_version(name=path).payload.data.decode()


def hl7_sim() -> int:
    from .hl7 import send, synthetic_adt

    started = time.monotonic()
    messages = [synthetic_adt()[0] for _ in range(config.HL7_COUNT)]
    try:
        acks = send(config.HL7_HOST, config.HL7_PORT, messages, _secret("hl7-ca-cert"))
    except Exception as exc:
        log("ERROR", "HL7 simulation failed — check the MIG health, firewall policy rule 1000 and TLS",
            host=config.HL7_HOST, port=config.HL7_PORT, error=str(exc))
        return 1
    log("INFO", "HL7 simulation complete", sent=len(messages), acks=acks,
        seconds=round(time.monotonic() - started, 2), target=f"{config.HL7_HOST}:{config.HL7_PORT}")
    return 0 if acks["AA"] == len(messages) else 2


def daily_report() -> int:
    from google.cloud import bigquery, storage

    bq = bigquery.Client(project=config.PROJECT_DATA)
    day = dt.date.today() - dt.timedelta(days=1)
    params = [bigquery.ScalarQueryParameter("d", "DATE", day)]

    from .bq import query
    visits = query(bq, f"SELECT note_id, processed_at, phi_findings, summary FROM `{config.table('visits')}` "
                       "WHERE DATE(processed_at) = @d", params)
    hl7 = query(bq, f"SELECT COUNT(*) AS n FROM `{config.table('hl7_messages')}` WHERE DATE(publish_time) = @d",
                params)[0].n

    phi_totals: dict[str, int] = {}
    for v in visits:
        findings = v.phi_findings if isinstance(v.phi_findings, dict) else json.loads(v.phi_findings or "{}")
        for k, n in findings.items():
            phi_totals[k] = phi_totals.get(k, 0) + int(n)

    row = {"report_date": day.isoformat(), "notes_processed": len(visits), "hl7_messages": hl7,
           "phi_by_type": json.dumps(phi_totals), "generated_at": dt.datetime.now(dt.timezone.utc).isoformat()}
    errors = bq.insert_rows_json(config.table("daily_reports"), [row], row_ids=[day.isoformat()])
    if errors:
        log("ERROR", "daily report insert failed", errors=errors)
        return 1

    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["note_id", "processed_at", "phi_types_found", "summary"])
    for v in visits:  # de-identified data only: no raw note text leaves the dataset
        writer.writerow([v.note_id, v.processed_at.isoformat(), ";".join(sorted(phi_totals)), v.summary])
    blob = storage.Client().bucket(config.CLAIMS_BUCKET).blob(f"daily/{day.isoformat()}.csv")
    blob.upload_from_string(out.getvalue(), content_type="text/csv")
    log("INFO", "daily report complete", **row, export=f"gs://{config.CLAIMS_BUCKET}/{blob.name}")
    return 0
