# =============================================================================
# FILE: core/email.py
# PURPOSE: Thin wrapper around the Resend API for sending transactional emails.
#          Uses onboarding@resend.dev as sender — works without domain
#          verification on Resend free tier (FYP demo-safe).
#
# Usage:
#   from core.email import send_email
#   await send_email(
#       to="user@example.com",
#       subject="Your booking confirmation",
#       html="<h1>Confirmed!</h1>",
#   )
# =============================================================================

from __future__ import annotations

import logging
from typing import Sequence

import httpx

from core.config import settings

logger = logging.getLogger(__name__)

RESEND_API_URL = "https://api.resend.com/emails"


async def send_email(
    to: str | Sequence[str],
    subject: str,
    html: str,
    reply_to: str | None = None,
) -> dict:
    """
    Send an HTML email via the Resend API.

    Args:
        to:       Recipient address(es).
        subject:  Email subject line.
        html:     Full HTML body.
        reply_to: Optional reply-to address.

    Returns:
        Resend API response dict containing {"id": "<message-id>"}.

    Raises:
        RuntimeError if the API returns a non-2xx status or RESEND_API_KEY is missing.
    """
    if not settings.RESEND_API_KEY:
        logger.warning("RESEND_API_KEY not set — email sending is disabled.")
        return {"id": "disabled", "skipped": True}

    recipients = [to] if isinstance(to, str) else list(to)

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

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(RESEND_API_URL, json=payload, headers=headers)

    if response.status_code not in (200, 201):
        logger.error(
            "Resend API error %s: %s", response.status_code, response.text
        )
        raise RuntimeError(
            f"Email delivery failed (HTTP {response.status_code}): {response.text}"
        )

    data = response.json()
    logger.info("Email sent via Resend — message id: %s", data.get("id"))
    return data


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
