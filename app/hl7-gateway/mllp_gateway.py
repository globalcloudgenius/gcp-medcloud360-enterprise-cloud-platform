#!/usr/bin/env python3
"""MedCloud360 HL7 v2 MLLP/TLS gateway.

Why a VM and not Cloud Run: hospital interfaces speak HL7 v2 over MLLP, a persistent
raw-TCP protocol (port 2575). Cloud Run only accepts HTTP/gRPC, so the interface
engine stays on Compute Engine. Every message is ACKed only after Pub/Sub has
durably accepted it; from there the serverless pipeline takes over.

Framing: <VT=0x0b> message <FS=0x1c><CR=0x0d>
"""
import asyncio
import datetime as dt
import json
import logging
import os
import signal
import ssl
import sys

from google.cloud import pubsub_v1

VT, FS, CR = b"\x0b", b"\x1c", b"\x0d"
PORT = int(os.environ.get("MLLP_PORT", "2575"))
TOPIC = os.environ["HL7_TOPIC"]  # projects/<p>/topics/hl7-adt
CERT = os.environ.get("TLS_CERT", "/etc/mc360/tls/server.crt")
KEY = os.environ.get("TLS_KEY", "/etc/mc360/tls/server.key")
MAX_MESSAGE = 1_048_576

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")
log = logging.getLogger("mllp")
publisher = pubsub_v1.PublisherClient()
draining = asyncio.Event()


def jlog(severity: str, message: str, **fields) -> None:
    """Structured log line picked up by the Ops Agent as jsonPayload."""
    log.info(json.dumps({"severity": severity, "message": message, **fields}))


def parse_msh(message: str) -> dict:
    segments = [s for s in message.replace("\n", "\r").split("\r") if s]
    msh = next((s for s in segments if s.startswith("MSH")), "")
    if not msh:
        raise ValueError("missing MSH segment")
    sep = msh[3]
    f = msh.split(sep)
    get = lambda i: f[i] if len(f) > i else ""  # noqa: E731
    return {
        "sending_app": get(2),
        "sending_facility": get(3),
        "message_type": get(8).replace("^", "_"),
        "control_id": get(9),
        "version": get(11),
        "sep": sep,
        "msh": f,
    }


def build_ack(meta: dict, code: str, text: str = "") -> bytes:
    sep = meta.get("sep", "|")
    f = meta.get("msh", [])
    get = lambda i: f[i] if len(f) > i else ""  # noqa: E731
    now = dt.datetime.utcnow().strftime("%Y%m%d%H%M%S")
    msh = sep.join(["MSH", get(1) or "^~\\&", "MC360-HL7GW", "MEDCLOUD360", get(2), get(3),
                    now, "", "ACK", f"ACK{meta.get('control_id', '')}", "P", get(11) or "2.5"])
    msa = sep.join(["MSA", code, meta.get("control_id", ""), text])
    return VT + (msh + "\r" + msa + "\r").encode() + FS + CR


async def handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    peer = writer.get_extra_info("peername")
    buf = b""
    try:
        while not draining.is_set():
            chunk = await reader.read(65536)
            if not chunk:
                break
            buf += chunk
            if len(buf) > MAX_MESSAGE:
                jlog("WARNING", "message too large, closing", peer=str(peer))
                break
            while VT in buf and FS + CR in buf:
                start = buf.index(VT)
                end = buf.index(FS + CR, start)
                raw, buf = buf[start + 1:end], buf[end + 2:]
                text = raw.decode("utf-8", errors="replace")
                meta: dict = {}
                try:
                    meta = parse_msh(text)
                    future = publisher.publish(
                        TOPIC, raw,
                        message_type=meta["message_type"],
                        control_id=meta["control_id"],
                        sending_facility=meta["sending_facility"],
                        gateway=os.uname().nodename,
                    )
                    msg_id = await asyncio.wrap_future(future)
                    writer.write(build_ack(meta, "AA"))
                    jlog("INFO", "hl7 accepted", control_id=meta["control_id"],
                         message_type=meta["message_type"], pubsub_id=msg_id)
                except Exception as exc:  # NACK so the sender retries
                    writer.write(build_ack(meta, "AE", str(exc)[:80]))
                    jlog("ERROR", "hl7 rejected", error=str(exc), peer=str(peer))
                await writer.drain()
    except (ConnectionResetError, ssl.SSLError) as exc:
        jlog("WARNING", "connection error", error=str(exc), peer=str(peer))
    finally:
        writer.close()


async def main() -> None:
    ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(CERT, KEY)
    server = await asyncio.start_server(handle, "0.0.0.0", PORT, ssl=ctx)
    jlog("INFO", "MLLP/TLS gateway listening", port=PORT, topic=TOPIC)

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, draining.set)  # pre-patch script / MIG shutdown

    async with server:
        await draining.wait()
        jlog("INFO", "draining: no new connections")
        server.close()
        await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(main())
