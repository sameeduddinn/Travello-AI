# =============================================================================
# FILE: routers/email.py
# PREFIX: /email
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // POST /email/booking-confirmation
# // Useful for "Resend Email" button on the booking detail screen
# Future<Map<String, dynamic>> resendBookingEmail(String bookingId) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/email/booking-confirmation'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({'booking_id': bookingId}),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
#   // response: {sent: true, to: "email@example.com", resend_id: "..."}
# }
#
# NOTE: Confirmation emails are also sent automatically after payment
#       verification in POST /payments/verify-otp. This endpoint is only
#       needed if the user wants to manually resend the email.
# =============================================================================

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


class BookingConfirmationRequest(BaseModel):
    booking_id: str   # UUID of the booking


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
    (flight / train / hotel), and sends via Gmail SMTP or Resend API.
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

    email_configured = bool(settings.SMTP_USER and settings.SMTP_PASSWORD) or bool(settings.RESEND_API_KEY)
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
