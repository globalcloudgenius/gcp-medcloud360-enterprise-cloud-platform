"""scc-router: Security Command Center notifications -> structured alert -> auto-remediation.

Every HIGH/CRITICAL finding becomes one structured log line (event=scc_finding) that the
log-based metric and alert policy in stage 08 turn into an email. Public-bucket findings
in the lab project are remediated automatically and the action is logged.
"""
import base64
import json

from fastapi import FastAPI, Request, Response
from google.cloud import storage

from . import config
from .logs import log

app = FastAPI(title="scc-router")
_storage = storage.Client()

PUBLIC_BUCKET_CATEGORIES = {"PUBLIC_BUCKET_ACL", "PUBLIC_BUCKET", "BUCKET_POLICY_ONLY_DISABLED"}
PUBLIC_MEMBERS = {"allUsers", "allAuthenticatedUsers"}


def remediate_public_bucket(resource_name: str) -> str:
    bucket_name = resource_name.rsplit("/", 1)[-1]
    bucket = _storage.bucket(bucket_name)
    policy = bucket.get_iam_policy(requested_policy_version=3)
    removed = []
    for binding in policy.bindings:
        public = PUBLIC_MEMBERS & set(binding["members"])
        if public:
            binding["members"] = set(binding["members"]) - public
            removed.extend(f"{binding['role']}:{m}" for m in public)
    if removed:
        bucket.set_iam_policy(policy)
    bucket.iam_configuration.public_access_prevention = "enforced"
    bucket.iam_configuration.uniform_bucket_level_access_enabled = True
    bucket.patch()
    return f"removed {removed or 'nothing'}; public access prevention enforced"


@app.post("/scc")
async def scc(request: Request) -> Response:
    envelope = await request.json()
    data = base64.b64decode(envelope.get("message", {}).get("data", "")).decode() or "{}"
    msg = json.loads(data)
    finding = msg.get("finding", {})
    resource = msg.get("resource", {})
    project = resource.get("projectDisplayName") or resource.get("project_display_name", "")
    category = finding.get("category", "")

    log("ALERT" if finding.get("severity") == "CRITICAL" else "ERROR", f"SCC finding {category}",
        event="scc_finding", category=category, finding_severity=finding.get("severity"),
        resource=finding.get("resourceName"), project=project, finding=finding.get("name"),
        state=finding.get("state"), console=finding.get("externalUri"))

    if category in PUBLIC_BUCKET_CATEGORIES and project in config.REMEDIATE_PROJECTS:
        try:
            result = remediate_public_bucket(finding.get("resourceName", ""))
            log("NOTICE", "auto-remediation applied", event="scc_remediation", category=category,
                resource=finding.get("resourceName"), result=result)
        except Exception as exc:
            log("ERROR", "auto-remediation failed", event="scc_remediation", error=str(exc))
    return Response(status_code=204)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "service": "scc-router"}
