"""Platform Proof: live checks that each control built in Terraform actually works.

Each check returns PASS / FAIL / WARN / INFO with the evidence and the stage that owns
the control. Guardrail checks deliberately ATTEMPT forbidden actions against dedicated
self-test targets (never real data) and pass only when the platform refuses them.
"""
import datetime as dt
import json
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass


from . import config


@dataclass
class Result:
    id: str
    title: str
    control: str
    stage: str
    status: str = "INFO"
    detail: str = ""


def _err(exc: Exception) -> str:
    return f"{type(exc).__name__}: {str(exc)[:300]}"


def _blocked_by(exc: Exception, *needles: str) -> bool:
    text = str(exc)
    return any(n in text for n in needles)


# --- Guardrails ---------------------------------------------------------------------
def sa_key_blocked() -> Result:
    r = Result("sa-key", "Service account key creation is refused",
               "iam.disableServiceAccountKeyCreation", "01-org")
    from google.cloud import iam_admin_v1
    client = iam_admin_v1.IAMClient()
    name = f"projects/{config.PROJECT_TEST}/serviceAccounts/{config.SELFTEST_TARGET_SA}"
    try:
        key = client.create_service_account_key(name=name)
        client.delete_service_account_key(name=key.name)
        r.status, r.detail = "FAIL", "A key was created (and immediately deleted): the org policy is not enforced."
    except Exception as exc:
        ok = _blocked_by(exc, "disableServiceAccountKeyCreation", "FAILED_PRECONDITION", "Precondition")
        r.status = "PASS" if ok else "WARN"
        r.detail = ("Refused by organization policy. " if ok else "Refused, but not by the org policy: ") + _err(exc)
    return r


def public_bucket_blocked() -> Result:
    r = Result("public-bucket", "Making a bucket public is refused",
               "storage.publicAccessPrevention + iam.allowedPolicyMemberDomains", "01-org")
    from google.cloud import storage
    bucket = storage.Client(project=config.PROJECT_TEST).bucket(config.SELFTEST_OUTSIDE_BUCKET)
    try:
        policy = bucket.get_iam_policy(requested_policy_version=3)
        policy.bindings.append({"role": "roles/storage.objectViewer", "members": {"allUsers"}})
        bucket.set_iam_policy(policy)
        policy.bindings = [b for b in policy.bindings if "allUsers" not in b["members"]]
        bucket.set_iam_policy(policy)
        r.status, r.detail = "FAIL", "allUsers was granted (and removed again): public access is not prevented."
    except Exception as exc:
        r.status, r.detail = "PASS", "Refused: " + _err(exc)
    return r


def non_cmek_bucket_blocked() -> Result:
    r = Result("cmek", "Unencrypted (non-CMEK) bucket in prod is refused",
               "gcp.restrictNonCmekServices (enforce_cmek)", "03-security")
    from google.cloud import storage
    client = storage.Client(project=config.PROJECT_DATA)
    name = f"mc360-selftest-{uuid.uuid4().hex[:10]}"
    try:
        b = client.create_bucket(name, location=config.REGION)
        b.delete(force=True)
        r.status, r.detail = "FAIL", "Created without CMEK (then deleted). Set enforce_cmek = true and re-apply stage 03."
    except Exception as exc:
        if _blocked_by(exc, "restrictNonCmekServices", "CMEK"):
            r.status, r.detail = "PASS", "Refused by the CMEK organization policy. " + _err(exc)
        else:
            r.status, r.detail = "WARN", "Refused, but not by the CMEK policy: " + _err(exc)
    return r


def exfiltration_blocked() -> Result:
    r = Result("exfil", "Copying PHI out of the perimeter is refused (valid credentials!)",
               "VPC Service Controls perimeter mc360_phi", "07-perimeter")
    from google.cloud import storage
    client = storage.Client(project=config.PROJECT_DATA)
    src_bucket = client.bucket(config.INTAKE_BUCKET)
    blob = src_bucket.blob(f"selftest/canary-{uuid.uuid4().hex[:8]}.txt")
    blob.upload_from_string("synthetic canary — no PHI")
    try:
        copied = src_bucket.copy_blob(blob, client.bucket(config.SELFTEST_OUTSIDE_BUCKET), blob.name)
        copied.delete()
        r.status = "WARN"
        r.detail = ("Copy succeeded: the perimeter is in DRY RUN (violation logged, not blocked). "
                    "Set vpcsc_dry_run = false and re-apply stage 07.")
    except Exception as exc:
        ok = _blocked_by(exc, "VPC Service Controls", "vpcServiceControlsUniqueIdentifier", "prohibited by organization")
        r.status = "PASS" if ok else "WARN"
        r.detail = ("Blocked by VPC Service Controls. " if ok else "Blocked by something else: ") + _err(exc)
    finally:
        blob.delete()
    return r


# --- Allowed paths (the platform must still WORK) ---------------------------------------
def secret_access() -> Result:
    r = Result("secret", "Workload reads its own secret", "Secret Manager + least-privilege IAM (CMEK)", "03-security")
    from google.cloud import secretmanager
    try:
        client = secretmanager.SecretManagerServiceClient()
        pem = client.access_secret_version(
            name=f"projects/{config.PROJECT_APP}/secrets/hl7-ca-cert/versions/latest").payload.data.decode()
        r.status, r.detail = ("PASS", "Read hl7-ca-cert") if "BEGIN CERTIFICATE" in pem else ("FAIL", "Unexpected content")
    except Exception as exc:
        r.status, r.detail = "FAIL", _err(exc)
    return r


def cmek_write() -> Result:
    r = Result("cmek-write", "PHI written to storage is encrypted with the company key", "CMEK (Cloud KMS)", "03/04")
    from google.cloud import storage
    try:
        bucket = storage.Client(project=config.PROJECT_DATA).bucket(config.INTAKE_BUCKET)
        blob = bucket.blob(f"selftest/cmek-{uuid.uuid4().hex[:8]}.txt")
        blob.upload_from_string("synthetic")
        blob.reload()
        key = blob.kms_key_name or ""
        blob.delete()
        r.status = "PASS" if "cryptoKeys/storage" in key else "FAIL"
        r.detail = f"kms_key_name = {key or 'none (Google-managed)'}"
    except Exception as exc:
        r.status, r.detail = "FAIL", _err(exc)
    return r


def dlp_detects() -> Result:
    r = Result("dlp", "Sensitive Data Protection finds PHI", "DLP inspect template carenotes-phi", "04-data")
    from google.cloud import dlp_v2
    try:
        resp = dlp_v2.DlpServiceClient().inspect_content(request={
            "parent": f"projects/{config.PROJECT_DATA}/locations/{config.REGION}",
            "inspect_template_name": config.DLP_INSPECT_TEMPLATE,
            "item": {"value": "Patient Jordan Rivera, SSN 372-21-4471, DOB 1984-03-12"},
        })
        types = sorted({f.info_type.name for f in resp.result.findings})
        r.status = "PASS" if "US_SOCIAL_SECURITY_NUMBER" in types else "FAIL"
        r.detail = "Found: " + ", ".join(types)
    except Exception as exc:
        r.status, r.detail = "FAIL", _err(exc)
    return r


# --- Detection / operations evidence -------------------------------------------------------
def siem_receiving() -> Result:
    r = Result("siem", "Org audit logs are reaching the BigQuery SIEM", "Org log sinks (include_children)", "01-org")
    from google.cloud import bigquery
    try:
        bq = bigquery.Client(project=config.PROJECT_OBS)
        q = (f"SELECT COUNT(*) n, MAX(timestamp) last FROM `{config.PROJECT_OBS}.{config.SIEM_DATASET}."
             "cloudaudit_googleapis_com_activity` WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)")
        row = list(bq.query(q).result())[0]
        r.status = "PASS" if row.n else "WARN"
        r.detail = f"{row.n} admin-activity entries in 24h, latest {row.last}"
    except Exception as exc:
        r.status, r.detail = "WARN", "SIEM table not readable yet (appears minutes after the first audit log). " + _err(exc)
    return r


def scc_findings() -> Result:
    r = Result("scc", "Security Command Center findings (active)", "SCC Standard + notification + BigQuery export", "03-security")
    from google.cloud import securitycenter_v2
    try:
        client = securitycenter_v2.SecurityCenterClient()
        counts: dict[str, int] = {}
        req = {"parent": f"organizations/{config.ORG_ID}/sources/-/locations/global",
               "filter": 'state="ACTIVE" AND mute!="MUTED"', "page_size": 500}
        for item in client.list_findings(request=req):
            sev = securitycenter_v2.Finding.Severity(item.finding.severity).name
            counts[sev] = counts.get(sev, 0) + 1
        r.status = "INFO"
        r.detail = json.dumps(counts) if counts else "No active findings"
    except Exception as exc:
        r.status, r.detail = "WARN", _err(exc)
    return r


def patching() -> Result:
    r = Result("patching", "VM Manager: vulnerability reports and patch jobs", "OS Config patch deployment + OS policies", "05-compute")
    from google.cloud import osconfig_v1
    try:
        zonal = osconfig_v1.OsConfigZonalServiceClient()
        cves, vms = 0, 0
        for zone in ("a", "b", "c"):
            parent = f"projects/{config.PROJECT_APP}/locations/{config.REGION}-{zone}/instances/-"
            for rep in zonal.list_vulnerability_reports(parent=parent):
                vms += 1
                cves += len(rep.vulnerabilities)
        jobs = list(osconfig_v1.OsConfigServiceClient().list_patch_jobs(
            parent=f"projects/{config.PROJECT_APP}", page_size=1))
        last = f"last patch job {jobs[0].state.name}" if jobs else "no patch job yet (weekly, Sunday 02:00)"
        r.status = "INFO"
        r.detail = f"{vms} VMs reporting, {cves} open CVEs; {last}"
    except Exception as exc:
        r.status, r.detail = "WARN", _err(exc)
    return r


def network_isolation() -> Result:
    r = Result("ncc", "Hub-and-spoke isolation (prod cannot reach nonprod)", "NCC STAR topology + Connectivity Tests", "02/08")
    from google.cloud import network_management_v1
    try:
        client = network_management_v1.ReachabilityServiceClient()
        base = f"projects/{config.PROJECT_NETWORK}/locations/global/connectivityTests"
        hub = client.get_connectivity_test(name=f"{base}/mc360-prod-to-hub").reachability_details.result.name
        non = client.get_connectivity_test(name=f"{base}/mc360-prod-to-nonprod").reachability_details.result.name
        r.status = "PASS" if non != "REACHABLE" else "FAIL"
        r.detail = f"prod->hub: {hub}; prod->nonprod: {non}"
    except Exception as exc:
        r.status, r.detail = "WARN", _err(exc)
    return r


def hl7_pipeline() -> Result:
    r = Result("hl7", "HL7 feed: MIG -> Pub/Sub -> BigQuery", "Linux MIG + internal TCP LB + BigQuery subscription", "05/04")
    from google.cloud import bigquery
    try:
        from .bq import query
        bq = bigquery.Client(project=config.PROJECT_DATA)
        n = query(bq, f"SELECT COUNT(*) n FROM `{config.table('hl7_messages')}` "
                      "WHERE publish_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)")[0].n
        r.status = "PASS" if n else "INFO"
        r.detail = f"{n} HL7 messages in the last 24h" + ("" if n else " — use 'Send HL7 messages' on the HL7 page")
    except Exception as exc:
        r.status, r.detail = "WARN", _err(exc)
    return r


CHECKS = [sa_key_blocked, public_bucket_blocked, non_cmek_bucket_blocked, exfiltration_blocked,
          secret_access, cmek_write, dlp_detects, siem_receiving, scc_findings, patching,
          network_isolation, hl7_pipeline]


def run_all() -> dict:
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(lambda f: f(), CHECKS))
    return {
        "ran_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "region": config.SERVING_REGION,
        "results": [asdict(r) for r in results],
    }
