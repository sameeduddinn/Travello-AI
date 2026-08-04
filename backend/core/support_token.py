# FILE: core/support_token.py
# PURPOSE: Short-lived, message-scoped, signed tokens for the support reply link.
#
# The support notification email used to carry the raw ADMIN_SECRET_KEY in the
# URL (?secret=...). That put a long-lived master key into the email body, the
# server access logs, and browser history: and, being the same key for every
# message, one leaked link could reply to ANY message.


from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time

from core.config import settings

# 7 days: an admin should get to a support reply within a week; after that the
# emailed link goes stale and a new message must be raised (or re-notified).
DEFAULT_TTL_SECONDS = 7 * 24 * 3600


def _b64u_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _b64u_decode(text: str) -> bytes:
    pad = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + pad)


def _sign(payload_b64: str) -> str:
    key = (settings.ADMIN_SECRET_KEY or "").encode("utf-8")
    digest = hmac.new(key, payload_b64.encode("ascii"), hashlib.sha256).digest()
    return _b64u_encode(digest)


def make_reply_token(message_id: str, ttl_seconds: int = DEFAULT_TTL_SECONDS) -> str:
    """A signed token authorising a reply to exactly this message_id, until it expires."""
    payload = {"mid": str(message_id), "exp": int(time.time()) + int(ttl_seconds)}
    payload_b64 = _b64u_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    return f"{payload_b64}.{_sign(payload_b64)}"


def verify_reply_token(token: str, message_id: str) -> bool:
    """True only for an unexpired, correctly-signed token issued for this message_id."""
    if not token or not settings.ADMIN_SECRET_KEY:
        return False
    try:
        payload_b64, signature = token.split(".", 1)
    except ValueError:
        return False
    # Constant-time compare so a forged token can't be probed byte by byte.
    if not hmac.compare_digest(signature, _sign(payload_b64)):
        return False
    try:
        payload = json.loads(_b64u_decode(payload_b64))
    except Exception:
        return False
    if str(payload.get("mid")) != str(message_id):
        return False
    if int(payload.get("exp", 0)) < int(time.time()):
        return False
    return True
