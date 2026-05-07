import logging

from fastapi import APIRouter, BackgroundTasks, HTTPException, status

from core.auth import CurrentUser
from models.payment import (
    PaymentAttemptOut,
    PaymentInitiateRequest,
    PaymentInitiateResponse,
)
from services.payment_service import (
    get_payment_history,
    initiate_payment,
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

    Supported methods: `card`, `bank_transfer`.
    Marks the booking as paid and sends a confirmation email in the background.
    """
    result = await initiate_payment(
        user_id=user.id,
        booking_uuid=payload.booking_id,
        method=payload.method,
        amount=payload.amount,
        phone=payload.phone,
        email_override=payload.email,
    )

    # Bank transfer payment: booking is already paid — send confirmation in background
    if not result.otp_required:
        background_tasks.add_task(send_booking_confirmation, payload.booking_id)

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
