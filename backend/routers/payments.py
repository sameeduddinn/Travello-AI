# =============================================================================
# FILE: routers/payments.py
# PREFIX: /payments
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // STEP 1 — POST /payments/initiate
# Future<Map<String, dynamic>> initiatePayment({
#   required String bookingId,   // UUID from booking response
#   required String method,      // 'jazzcash' | 'easypaisa' | 'card'
#   required double amount,
#   String? phone,               // mobile wallet number
#   String? email,               // override OTP delivery email
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/payments/initiate'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({
#       'booking_id': bookingId,
#       'method': method,
#       'amount': amount,
#       if (phone != null) 'phone': phone,
#       if (email != null) 'email': email,
#     }),
#   );
#   final data = jsonDecode(res.body) as Map<String, dynamic>;
#   // data['otp_required'] == true  → show OTP input screen
#   // data['request_id']            → save this for step 2
#   return data;
# }
#
# // STEP 2 — POST /payments/verify-otp  (only for jazzcash/easypaisa)
# Future<Map<String, dynamic>> verifyOtp({
#   required String requestId,  // from initiatePayment response
#   required String otp,        // 6-digit code from email
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/payments/verify-otp'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({'request_id': requestId, 'otp': otp}),
#   );
#   final data = jsonDecode(res.body) as Map<String, dynamic>;
#   // data['success'] == true → booking is now paid, navigate to ticket screen
#   return data;
# }
#
# // GET /payments/{bookingId}
# Future<List<dynamic>> getPaymentHistory(String bookingId) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/payments/$bookingId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as List<dynamic>;
# }
# =============================================================================

import logging

from fastapi import APIRouter, BackgroundTasks, HTTPException, status

from core.auth import CurrentUser
from core.supabase_client import supabase_admin
from models.payment import (
    OTPVerifyRequest,
    OTPVerifyResponse,
    PaymentAttemptOut,
    PaymentInitiateRequest,
    PaymentInitiateResponse,
)
from services.payment_service import (
    get_payment_history,
    initiate_payment,
    verify_otp,
)
from services.email_service import send_booking_confirmation

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/payments", tags=["Payments"])


# ---------------------------------------------------------------------------
# POST /payments/initiate
# ---------------------------------------------------------------------------

@router.post("/initiate", response_model=PaymentInitiateResponse)
async def initiate_payment_endpoint(
    payload: PaymentInitiateRequest,
    user: CurrentUser,
    background_tasks: BackgroundTasks,
):
    """
    Start a payment for a booking.

    - **JazzCash / EasyPaisa**: Generates a 6-digit OTP, emails it to the
      contact email, returns `otp_required: true` and a `request_id`.
      OTP expires in 10 minutes. Max 3 attempts.

    - **Card**: Simulates instant approval, marks booking as paid,
      returns `otp_required: false`. Confirmation email sent in background.
    """
    # Verify passengers are on record before processing payment
    try:
        pax = (
            supabase_admin.table("passengers")
            .select("id")
            .eq("booking_id", payload.booking_id)
            .execute()
        )
        if not pax.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please add passenger details before proceeding to payment.",
            )
    except HTTPException:
        raise
    except Exception:
        pass  # Non-fatal; let payment service handle further validation

    result = await initiate_payment(
        user_id=user.id,
        booking_uuid=payload.booking_id,
        method=payload.method,
        amount=payload.amount,
        phone=payload.phone,
        email_override=payload.email,
    )

    # Card payment: booking is already paid — send confirmation in background
    if not result.otp_required:
        background_tasks.add_task(send_booking_confirmation, payload.booking_id)

    return result


# ---------------------------------------------------------------------------
# POST /payments/verify-otp
# ---------------------------------------------------------------------------

@router.post("/verify-otp", response_model=OTPVerifyResponse)
async def verify_otp_endpoint(
    payload: OTPVerifyRequest,
    user: CurrentUser,
    background_tasks: BackgroundTasks,
):
    """
    Verify the OTP for a JazzCash or EasyPaisa payment.

    On success:
      - Marks payment_attempt as 'completed'
      - Marks booking as 'paid'
      - Creates an in-app notification
      - Sends booking confirmation email (in background — does not delay response)

    On failure:
      - Increments attempt counter
      - Returns 401 with remaining attempts
      - Returns 410 if OTP is expired
      - Returns 429 if max attempts exceeded
    """
    result = await verify_otp(
        user_id=user.id,
        request_id=payload.request_id,
        otp=payload.otp,
    )

    if result.success:
        try:
            attempt = (
                supabase_admin.table("payment_attempts")
                .select("booking_id")
                .eq("id", payload.request_id)
                .single()
                .execute()
            )
            if attempt.data:
                background_tasks.add_task(
                    send_booking_confirmation, attempt.data["booking_id"]
                )
        except Exception as exc:
            logger.warning("Could not schedule confirmation email (non-fatal): %s", exc)

    return result


# ---------------------------------------------------------------------------
# GET /payments/{booking_id}
# ---------------------------------------------------------------------------

@router.get("/{booking_id}", response_model=list[PaymentAttemptOut])
async def get_payment_history_endpoint(booking_id: str, user: CurrentUser):
    """
    Return all payment attempts for a specific booking.
    The booking_id here is the UUID.
    """
    return await get_payment_history(booking_uuid=booking_id, user_id=user.id)
