import asyncio
import base64
import concurrent.futures
import json
import subprocess
import threading
import time
from unittest import mock

import pytest
from fastapi.testclient import TestClient


def test_health_endpoints():
    from carenotes import portal, processor, scc_router
    for module in (portal, processor, scc_router):
        assert TestClient(module.app).get("/healthz").status_code == 200


def test_portal_rejects_forged_iap_assertion():
    from carenotes import portal
    with mock.patch.object(portal.id_token, "verify_token", side_effect=ValueError("bad signature")):
        r = TestClient(portal.app).get("/", headers={"x-goog-iap-jwt-assertion": "forged"})
    assert r.status_code == 401


def test_processor_ignores_non_note_objects():
    from carenotes import processor
    data = base64.b64encode(json.dumps({"bucket": "intake", "name": "selftest/canary.txt"}).encode()).decode()
    r = TestClient(processor.app).post("/pubsub/note", json={"message": {"data": data}})
    assert r.status_code == 204


def test_scc_router_remediates_public_bucket_only_in_lab_project():
    from carenotes import scc_router

    def push(project):
        msg = {"finding": {"category": "PUBLIC_BUCKET_ACL", "severity": "HIGH",
                           "resourceName": "//storage.googleapis.com/lab-bucket"},
               "resource": {"projectDisplayName": project}}
        data = base64.b64encode(json.dumps(msg).encode()).decode()
        return TestClient(scc_router.app).post("/scc", json={"message": {"data": data}})

    with mock.patch.object(scc_router, "remediate_public_bucket", return_value="ok") as fix:
        assert push("mc360-prj-prod-data").status_code == 204
        fix.assert_not_called()
        assert push("mc360-prj-test").status_code == 204
        fix.assert_called_once_with("//storage.googleapis.com/lab-bucket")


def test_synthetic_hl7_is_valid_adt():
    from carenotes.hl7 import synthetic_adt
    msg, control = synthetic_adt()
    segments = msg.strip("\r").split("\r")
    assert segments[0].startswith("MSH|^~\\&|") and control in segments[0]
    assert [s[:3] for s in segments] == ["MSH", "EVN", "PID", "PV1"]


@pytest.fixture(scope="module")
def gateway(tmp_path_factory):
    """Starts the real MLLP/TLS gateway with a throwaway certificate and a fake Pub/Sub."""
    d = tmp_path_factory.mktemp("tls")
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256", "-nodes",
         "-keyout", str(d / "k.pem"), "-out", str(d / "c.pem"), "-days", "1", "-subj", "/CN=hl7.mc360.internal",
         "-addext", "subjectAltName=DNS:hl7.mc360.internal"], check=True, capture_output=True)

    import os
    os.environ.update(HL7_TOPIC="projects/data/topics/hl7-adt", TLS_CERT=str(d / "c.pem"),
                      TLS_KEY=str(d / "k.pem"), MLLP_PORT="25751")

    class FakePublisher:
        published = []

        def publish(self, topic, data, **attrs):
            FakePublisher.published.append((topic, data, attrs))
            f = concurrent.futures.Future()
            f.set_result(str(len(FakePublisher.published)))
            return f

    with mock.patch("google.cloud.pubsub_v1.PublisherClient", FakePublisher):
        import mllp_gateway

    def serve():
        loop = asyncio.new_event_loop()
        loop.add_signal_handler = lambda *a, **k: None  # signals only work in the main thread
        loop.run_until_complete(mllp_gateway.main())

    threading.Thread(target=serve, daemon=True).start()
    time.sleep(1.5)
    return {"port": 25751, "ca": (d / "c.pem").read_text(), "published": FakePublisher.published}


def test_mllp_tls_end_to_end(gateway):
    from carenotes.hl7 import send, synthetic_adt
    msgs = [synthetic_adt()[0] for _ in range(20)]
    acks = send("127.0.0.1", gateway["port"], msgs, gateway["ca"])
    assert acks["AA"] == 20
    topic, _, attrs = gateway["published"][-1]
    assert topic.endswith("/hl7-adt") and attrs["message_type"].startswith("ADT_")


def test_mllp_rejects_message_without_msh(gateway):
    from carenotes.hl7 import send
    acks = send("127.0.0.1", gateway["port"], ["PID|1||x\r"], gateway["ca"])
    assert acks["AE"] == 1
