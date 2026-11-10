"""Tests run offline: Google clients get anonymous credentials, no network calls are made."""
import os
import sys

import google.auth
from google.auth.credentials import AnonymousCredentials

google.auth.default = lambda *a, **k: (AnonymousCredentials(), "test-project")
os.environ.update(PROJECT_APP="app", PROJECT_DATA="data", PROJECT_OBS="obs", INTAKE_BUCKET="intake",
                  REGION="us-central1", REMEDIATE_PROJECTS="mc360-prj-test")

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "carenotes"))
sys.path.insert(0, os.path.join(HERE, "..", "hl7-gateway"))
