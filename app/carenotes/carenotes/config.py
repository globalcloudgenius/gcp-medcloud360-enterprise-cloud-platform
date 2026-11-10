"""Runtime configuration, injected by Terraform (stage 06) as environment variables."""
import os


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


ORG_ID = env("ORG_ID")
PROJECT_APP = env("PROJECT_APP")
PROJECT_DATA = env("PROJECT_DATA")
PROJECT_OBS = env("PROJECT_OBS")
PROJECT_TEST = env("PROJECT_TEST")
PROJECT_NETWORK = env("PROJECT_NETWORK")
REGION = env("REGION", "us-central1")
SERVING_REGION = env("SERVING_REGION", REGION)
INTAKE_BUCKET = env("INTAKE_BUCKET")
CLAIMS_BUCKET = env("CLAIMS_BUCKET")
DATASET = env("DATASET", "carenotes")
DLP_INSPECT_TEMPLATE = env("DLP_INSPECT_TEMPLATE")
DLP_DEID_TEMPLATE = env("DLP_DEID_TEMPLATE")
GEMINI_MODEL = env("GEMINI_MODEL", "gemini-2.5-flash")
HL7_HOST = env("HL7_HOST", "10.42.0.10")
HL7_PORT = int(env("HL7_PORT", "2575"))
HL7_JOB = env("HL7_JOB", "hl7-sim")
HL7_COUNT = int(env("HL7_COUNT", "100"))
SIEM_DATASET = env("SIEM_DATASET", "org_audit_siem")
SCC_DATASET = env("SCC_DATASET", "scc_findings")
SELFTEST_TARGET_SA = env("SELFTEST_TARGET_SA")
SELFTEST_OUTSIDE_BUCKET = env("SELFTEST_OUTSIDE_BUCKET")
REMEDIATE_PROJECTS = [p for p in env("REMEDIATE_PROJECTS").split(",") if p]
IAP_AUDIENCE = env("IAP_AUDIENCE")  # optional: /projects/NUM/global/backendServices/ID
PORT = int(env("PORT", "8080"))


def table(name: str) -> str:
    return f"{PROJECT_DATA}.{DATASET}.{name}"
BQ_KMS_KEY = env("BQ_KMS_KEY")  # query results in the PHI project are CMEK-encrypted too
