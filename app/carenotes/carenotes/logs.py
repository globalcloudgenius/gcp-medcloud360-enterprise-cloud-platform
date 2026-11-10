"""Structured JSON logging understood by Cloud Logging (jsonPayload, severity)."""
import json
import sys


def log(severity: str, message: str, **fields) -> None:
    print(json.dumps({"severity": severity, "message": message, **fields}, default=str), file=sys.stdout, flush=True)
