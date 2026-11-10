"""Synthetic HL7 v2 messages (fictional patients only) and an MLLP/TLS client."""
import datetime as dt
import random
import socket
import ssl
import uuid

VT, FS, CR = b"\x0b", b"\x1c", b"\x0d"

FIRST = ["ALEX", "JORDAN", "TAYLOR", "MORGAN", "CASEY", "RILEY", "AVERY", "QUINN", "JAMIE", "DREW"]
LAST = ["RIVERA", "CHEN", "PATEL", "OKAFOR", "NGUYEN", "GARCIA", "KOWALSKI", "HASSAN", "BROWN", "SATO"]
EVENTS = [("ADT", "A01", "Admit"), ("ADT", "A03", "Discharge"), ("ADT", "A08", "Update")]


def synthetic_adt(facility: str = "MC360-CLINIC-01") -> tuple[str, str]:
    now = dt.datetime.utcnow().strftime("%Y%m%d%H%M%S")
    control = uuid.uuid4().hex[:20].upper()
    mtype, trigger, _ = random.choice(EVENTS)
    mrn = f"MRN{random.randint(100000, 999999)}"
    dob = f"{random.randint(1940, 2015)}{random.randint(1, 12):02d}{random.randint(1, 28):02d}"
    segs = [
        f"MSH|^~\\&|EPICSIM|{facility}|MC360-HL7GW|MEDCLOUD360|{now}||{mtype}^{trigger}|{control}|P|2.5",
        f"EVN|{trigger}|{now}",
        f"PID|1||{mrn}^^^MC360^MR||{random.choice(LAST)}^{random.choice(FIRST)}||{dob}|{random.choice('MFU')}",
        f"PV1|1|{random.choice(['I', 'O', 'E'])}|MED^{random.randint(100, 450)}^1|||||||||||||||V{random.randint(10000, 99999)}",
    ]
    return "\r".join(segs) + "\r", control


def tls_context(ca_pem: str) -> ssl.SSLContext:
    ctx = ssl.create_default_context(cadata=ca_pem)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    return ctx


def send(host: str, port: int, messages: list[str], ca_pem: str, timeout: float = 10.0) -> dict:
    """Send messages over one persistent MLLP/TLS connection; count AA/AE/AR acknowledgements."""
    acks = {"AA": 0, "AE": 0, "AR": 0, "none": 0}
    ctx = tls_context(ca_pem)
    with socket.create_connection((host, port), timeout=timeout) as raw:
        with ctx.wrap_socket(raw, server_hostname="hl7.mc360.internal") as conn:
            for m in messages:
                conn.sendall(VT + m.encode() + FS + CR)
                buf = b""
                while FS + CR not in buf:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
                text = buf.decode(errors="replace")
                code = next((seg.split("|")[1] for seg in text.split("\r") if seg.startswith("MSA")), "none")
                acks[code if code in acks else "none"] += 1
    return acks
