# =============================================================================
# FILE: core/email.py
# PURPOSE: Unified email sender — Gmail SMTP (preferred) or Resend API.
#
# Priority:
#   1. Gmail SMTP  — if SMTP_USER + SMTP_PASSWORD are set in .env
#   2. Resend API  — if RESEND_API_KEY is set (free tier: only own email)
#   3. Disabled    — logs a warning, returns {"id": "disabled"}
#
# Gmail setup (free, no domain needed, sends to any address):
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

import httpx

from core.config import settings

logger = logging.getLogger(__name__)

RESEND_API_URL = "https://api.resend.com/emails"


# ---------------------------------------------------------------------------
# Gmail SMTP backend
# ---------------------------------------------------------------------------

def _parse_sender_address(from_field: str) -> str:
    """Extract bare email from 'Display Name <email@x.com>' or return as-is."""
    m = re.search(r"<(.+?)>", from_field)
    return m.group(1) if m else from_field.strip()


def _send_via_smtp(recipients: list[str], subject: str, html: str) -> dict:
    """Blocking SMTP send — run inside asyncio.to_thread."""
    sender_address = _parse_sender_address(settings.EMAIL_FROM)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = settings.EMAIL_FROM
    msg["To"] = ", ".join(recipients)
    msg.attach(MIMEText(html, "html", "utf-8"))

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
        server.ehlo()
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD.replace(" ", ""))
        server.sendmail(sender_address, recipients, msg.as_string())

    logger.info("Email sent via Gmail SMTP to %s", recipients)
    return {"id": f"smtp-{recipients[0]}", "backend": "smtp"}


async def _send_smtp(recipients: list[str], subject: str, html: str) -> dict:
    try:
        return await asyncio.to_thread(_send_via_smtp, recipients, subject, html)
    except smtplib.SMTPAuthenticationError:
        logger.error("Gmail SMTP auth failed — check SMTP_USER and SMTP_PASSWORD (App Password)")
        return {"id": "failed", "reason": "smtp_auth_error"}
    except Exception as exc:
        logger.error("Gmail SMTP error: %s", exc)
        return {"id": "failed", "reason": str(exc)}


# ---------------------------------------------------------------------------
# Resend API backend
# ---------------------------------------------------------------------------

async def _send_resend(recipients: list[str], subject: str, html: str, reply_to: str | None) -> dict:
    payload: dict = {
        "from": settings.EMAIL_FROM,
        "to": recipients,
        "subject": subject,
        "html": html,
    }
    if reply_to:
        payload["reply_to"] = reply_to

    headers = {
        "Authorization": f"Bearer {settings.RESEND_API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(RESEND_API_URL, json=payload, headers=headers)

        if response.status_code in (200, 201):
            data = response.json()
            logger.info("Email sent via Resend — message id: %s", data.get("id"))
            return data
        else:
            logger.error("Resend API %s: %s", response.status_code, response.text[:200])
            return {"id": "failed", "reason": f"api_error_{response.status_code}"}
    except httpx.TimeoutException:
        logger.error("Resend timeout for %s", recipients)
        return {"id": "failed", "reason": "timeout"}
    except Exception as exc:
        logger.error("Resend error: %s", exc)
        return {"id": "failed", "reason": str(exc)}


# ---------------------------------------------------------------------------
# Public API — unchanged interface, auto-selects backend
# ---------------------------------------------------------------------------

async def send_email(
    to: str | Sequence[str],
    subject: str,
    html: str,
    reply_to: str | None = None,
) -> dict:
    """
    Send an HTML email. Uses Gmail SMTP if configured, else Resend API.
    Returns a dict with at least {"id": ...}.
    """
    recipients = [to] if isinstance(to, str) else list(to)

    if not recipients or not recipients[0]:
        logger.warning("Email skipped — no recipient address")
        return {"id": "skipped", "reason": "no_recipient"}

    if settings.SMTP_USER and settings.SMTP_PASSWORD:
        return await _send_smtp(recipients, subject, html)

    if settings.RESEND_API_KEY:
        return await _send_resend(recipients, subject, html, reply_to)

    logger.warning("No email backend configured — set SMTP_USER/SMTP_PASSWORD or RESEND_API_KEY")
    return {"id": "disabled", "skipped": True}


async def send_otp_email(
    to: str,
    otp: str,
    provider: str,
    amount: float,
    phone: str | None = None,
) -> dict:
    """
    Send OTP email for JazzCash / EasyPaisa payment simulation.
    Since we can't send real SMS without a paid gateway, we email the OTP.
    """
    provider_display = "JazzCash" if provider == "jazzcash" else "EasyPaisa"
    phone_hint = f" to {phone[-4:].rjust(len(phone), '*')}" if phone else ""

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body {{ font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 20px; }}
            .card {{ background: #fff; border-radius: 12px; padding: 32px; max-width: 480px;
                     margin: 0 auto; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }}
            .logo {{ color: #1a73e8; font-size: 24px; font-weight: bold; margin-bottom: 8px; }}
            .otp-box {{ background: #f0f7ff; border: 2px dashed #1a73e8; border-radius: 8px;
                        text-align: center; padding: 24px; margin: 24px 0; }}
            .otp {{ font-size: 42px; font-weight: bold; letter-spacing: 10px;
                    color: #1a73e8; font-family: monospace; }}
            .warning {{ color: #e53935; font-size: 13px; margin-top: 16px; }}
            .footer {{ color: #888; font-size: 12px; text-align: center; margin-top: 24px; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="logo">Travello AI</div>
            <h2 style="color:#222;margin-top:4px">{provider_display} Payment OTP</h2>
            <p>You are paying <strong>PKR {amount:,.0f}</strong>{phone_hint}.</p>
            <p>Use the following One-Time Password to confirm your payment:</p>
            <div class="otp-box">
                <div class="otp">{otp}</div>
                <p style="margin:8px 0 0;color:#555;font-size:14px">
                    This OTP expires in <strong>10 minutes</strong>.
                </p>
            </div>
            <p class="warning">
                &#9888; Never share this OTP with anyone.
                Travello AI will never ask for your OTP over call or chat.
            </p>
            <div class="footer">
                &copy; 2024 Travello AI &mdash; Pakistan's Smart Travel Companion
            </div>
        </div>
    </body>
    </html>
    """

    return await send_email(
        to=to,
        subject=f"Your {provider_display} OTP for Travello AI Payment",
        html=html,
    )
