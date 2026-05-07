import logging

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from core.auth import CurrentUser
from core.config import settings
from core.email import send_email
from core.supabase_client import supabase_admin
from services.email_service import send_booking_confirmation

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/email", tags=["Email"])


SUPPORT_INBOX = "travelloo.ai@gmail.com"


class BookingConfirmationRequest(BaseModel):
    booking_id: str   # UUID of the booking


class ContactSupportRequest(BaseModel):
    topic: str
    subject: str
    description: str
    sender_email: str = ""   # user's own email — used as Reply-To


# ---------------------------------------------------------------------------
# POST /email/contact-support
# ---------------------------------------------------------------------------

@router.post("/contact-support")
async def contact_support(payload: ContactSupportRequest):
    """
    Forward a user's support message to travelloo.ai@gmail.com via SMTP.
    Sets Reply-To to the sender's email so support can reply directly.
    """
    reply_to = payload.sender_email.strip() or None
    sender_label = reply_to or "Anonymous user"

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body {{ font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 24px; }}
        .card {{ background: #fff; border-radius: 12px; padding: 28px 32px;
                 max-width: 560px; margin: 0 auto;
                 box-shadow: 0 2px 10px rgba(0,0,0,0.09); }}
        .logo {{ color: #C9A84C; font-size: 22px; font-weight: bold; margin-bottom: 4px; }}
        .badge {{ display: inline-block; background: #FFF8E7; color: #C9A84C;
                  border: 1px solid #E6C86A; border-radius: 20px;
                  padding: 4px 14px; font-size: 13px; font-weight: 600;
                  margin-bottom: 16px; }}
        .label {{ font-size: 11px; font-weight: 700; color: #999;
                  text-transform: uppercase; letter-spacing: 0.6px;
                  margin-bottom: 4px; }}
        .value {{ font-size: 15px; color: #222; margin-bottom: 16px; }}
        .msg-box {{ background: #FAFAFA; border-left: 4px solid #C9A84C;
                    border-radius: 6px; padding: 16px 18px;
                    font-size: 14px; color: #333; line-height: 1.7;
                    white-space: pre-wrap; margin-top: 4px; }}
        .footer {{ color: #aaa; font-size: 12px; text-align: center;
                   margin-top: 28px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">Travello AI</div>
        <p style="color:#777;font-size:13px;margin-top:2px">New support message received</p>
        <div class="badge">&#128394; {payload.topic}</div>

        <div class="label">From</div>
        <div class="value">{ sender_label}</div>

        <div class="label">Subject</div>
        <div class="value">{ payload.subject}</div>

        <div class="label">Message</div>
        <div class="msg-box">{ payload.description}</div>

        <div class="footer">
          &copy; Travello AI &mdash; Support Inbox &mdash;
          Reply directly to this email to respond to the user.
        </div>
      </div>
    </body>
    </html>
    """

    result = await send_email(
        to=SUPPORT_INBOX,
        subject=f"[Support] {payload.topic}: {payload.subject}",
        html=html,
        reply_to=reply_to,
    )

    sent = result.get("id") not in ("failed", "disabled", "skipped", None)
    if not sent:
        logger.warning("Contact-support email not delivered: %s", result)

    return {"sent": sent, "result": result}


# ---------------------------------------------------------------------------
# POST /email/booking-confirmation
# ---------------------------------------------------------------------------

@router.post("/booking-confirmation")
async def send_booking_confirmation_endpoint(
    payload: BookingConfirmationRequest,
    user: CurrentUser,
):
    """
    Send (or resend) the HTML booking confirmation email for a booking.
    Fetches booking data from DB, chooses the correct template
    (flight / train / hotel), and sends via Gmail SMTP.
    The booking must belong to the authenticated user.
    """
    # Ownership check — ensure booking belongs to this user
    ownership = (
        supabase_admin.table("bookings")
        .select("id, user_id")
        .eq("id", payload.booking_id)
        .eq("user_id", user.id)
        .execute()
    )

    if not ownership.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found or does not belong to you.",
        )

    return await send_booking_confirmation(booking_uuid=payload.booking_id)


# ---------------------------------------------------------------------------
# GET /email/test
# ---------------------------------------------------------------------------

@router.get("/test")
async def test_email_config(user: CurrentUser):
    """
    Test email configuration — sends a test email to the authenticated user.
    Useful for verifying the Resend API key is working before demo.
    """
    user_email = getattr(user, "email", "") or ""

    email_configured = bool(settings.SMTP_USER and settings.SMTP_PASSWORD) 
    if not user_email:
        return {
            "email_configured": email_configured,
            "error": "No email found for current user",
        }

    result = await send_email(
        to=user_email,
        subject="Travello AI — Email Test",
        html="""
        <!DOCTYPE html>
        <html>
        <body style="font-family:Arial,sans-serif;padding:20px">
          <h2 style="color:#1a73e8">Email is working!</h2>
          <p>Your Travello AI email system is configured correctly.</p>
          <p>Booking confirmation emails will be delivered to this address after payment.</p>
          <p style="color:#888;font-size:12px;margin-top:24px">
            Travello AI &mdash; Pakistan&apos;s Smart Travel App
          </p>
        </body>
        </html>
        """,
    )

    status_value = (
        "sent"
        if result.get("id") not in ("skipped", "failed", "disabled", None)
        else result.get("reason", "unknown")
    )
    return {
        "email_configured": email_configured,
        "sent_to": user_email,
        "result": result,
        "from_address": settings.EMAIL_FROM,
        "status": status_value,
    }
