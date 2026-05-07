# =============================================================================
# FILE: core/email.py
# PURPOSE: Email sender via Gmail SMTP.
#
# Setup:
#   1. Enable 2-Step Verification on Google Account
#   2. Google Account → Security → App Passwords → create for "Mail"
#   3. Add to .env:  SMTP_USER=you@gmail.com  SMTP_PASSWORD=xxxx-xxxx-xxxx-xxxx
# =============================================================================

from __future__ import annotations

import asyncio
import logging
import re
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Sequence

from core.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Gmail SMTP backend
# ---------------------------------------------------------------------------

def _parse_sender_address(from_field: str) -> str:
    """Extract bare email from 'Display Name <email@x.com>' or return as-is."""
    m = re.search(r"<(.+?)>", from_field)
    return m.group(1) if m else from_field.strip()


def _send_via_smtp(recipients: list[str], subject: str, html: str, reply_to: str | None) -> dict:
    """Blocking SMTP send — run inside asyncio.to_thread."""
    sender_address = _parse_sender_address(settings.EMAIL_FROM)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = settings.EMAIL_FROM
    msg["To"] = ", ".join(recipients)
    if reply_to:
        msg["Reply-To"] = reply_to
    msg.attach(MIMEText(html, "html", "utf-8"))

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
        server.ehlo()
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD.replace(" ", ""))
        server.sendmail(sender_address, recipients, msg.as_string())

    logger.info("Email sent via Gmail SMTP to %s", recipients)
    return {"id": f"smtp-{recipients[0]}", "backend": "smtp"}


async def _send_smtp(recipients: list[str], subject: str, html: str, reply_to: str | None) -> dict:
    try:
        return await asyncio.to_thread(_send_via_smtp, recipients, subject, html, reply_to)
    except smtplib.SMTPAuthenticationError:
        logger.error("Gmail SMTP auth failed — check SMTP_USER and SMTP_PASSWORD (App Password)")
        return {"id": "failed", "reason": "smtp_auth_error"}
    except Exception as exc:
        logger.error("Gmail SMTP error: %s", exc)
        return {"id": "failed", "reason": str(exc)}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def send_email(
    to: str | Sequence[str],
    subject: str,
    html: str,
    reply_to: str | None = None,
) -> dict:
    """Send an HTML email via Gmail SMTP. Returns a dict with at least {"id": ...}."""
    recipients = [to] if isinstance(to, str) else list(to)

    if not recipients or not recipients[0]:
        logger.warning("Email skipped — no recipient address")
        return {"id": "skipped", "reason": "no_recipient"}

    if settings.SMTP_USER and settings.SMTP_PASSWORD:
        return await _send_smtp(recipients, subject, html, reply_to)

    logger.warning("No email backend configured — set SMTP_USER/SMTP_PASSWORD in .env")
    return {"id": "disabled", "skipped": True}

