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
    sender_email: str = ""   # user's own email - used as Reply-To
    user_id: str = ""        # Supabase user UUID - used to persist in DB


# POST /email/contact-support

@router.post("/contact-support")
async def contact_support(payload: ContactSupportRequest):
    """
    Save support message to DB, then forward to travelloo.ai@gmail.com.
    Admin email includes the message ID for use with the reply endpoint.
    """
    reply_to = payload.sender_email.strip() or None
    sender_label = reply_to or "Anonymous user"
    message_id: str | None = None

    # Persist to DB if user_id provided
    if payload.user_id.strip():
        try:
            result = supabase_admin.table("support_messages").insert({
                "user_id":     payload.user_id.strip(),
                "user_email":  payload.sender_email.strip(),
                "topic":       payload.topic,
                "subject":     payload.subject,
                "description": payload.description,
                "status":      "pending",
            }).execute()
            if result.data:
                message_id = result.data[0].get("id")
        except Exception as exc:
            logger.warning("Could not save support message to DB: %s", exc)

    id_section = f"""
        <div class="label">Message ID</div>
        <div class="value" style="font-family:monospace;font-size:13px;color:#888;">{message_id}</div>
    """ if message_id else ""

    reply_link = (
        f"{settings.BACKEND_BASE_URL.rstrip('/')}/support/reply-form"
        f"?message_id={message_id}&secret={settings.ADMIN_SECRET_KEY}"
    ) if message_id and settings.ADMIN_SECRET_KEY else None

    admin_secret_hint = f"""
        <div style="margin-top:20px;text-align:center;">
          <a href="{reply_link}"
             style="display:inline-block;background:#C9A84C;color:#fff;
                    text-decoration:none;padding:13px 32px;border-radius:10px;
                    font-size:15px;font-weight:700;letter-spacing:0.3px;">
            &#128393;&nbsp; Reply in App
          </a>
          <p style="font-size:11px;color:#aaa;margin-top:8px;">
            Click the button above to open the reply form — no API calls needed.
          </p>
        </div>
    """ if reply_link else ""

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
        <div class="value">{sender_label}</div>

        <div class="label">Subject</div>
        <div class="value">{payload.subject}</div>

        {id_section}

        <div class="label">Message</div>
        <div class="msg-box">{payload.description}</div>

        {admin_secret_hint}

        <div class="footer">
          &copy; Travello AI &mdash; Support Inbox
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

    return {"sent": sent, "message_id": message_id, "result": result}


# POST /email/booking-confirmation

@router.post("/booking-confirmation")
async def send_booking_confirmation_endpoint(
    payload: BookingConfirmationRequest,
    user: CurrentUser,
):
    """
    Send  the HTML booking confirmation email for a booking.
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

