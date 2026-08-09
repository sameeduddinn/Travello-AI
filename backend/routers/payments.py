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
from services.car_service import book_car_transfers
from services.email_service import send_booking_confirmation
from services.package_email import send_package_confirmation

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
        package_id=payload.package_id,
    )

    # Only reached when the charge actually succeeded — initiate_payment raises
    # on a rejected package (empty, already paid, or a total that doesn't match
    # the component rows), so a failed package can never get this far and can
    # never produce a confirmation email or a "trip confirmed" reply.
    if not result.otp_required:
        if payload.package_id:
            # ONE consolidated email for the whole trip. Deliberately NOT
            # send_booking_confirmation per component — that is what would turn
            # one package into three near-identical confirmation emails.
            background_tasks.add_task(send_package_confirmation, payload.package_id, user.id)
            # The hub transfer rides on ONE component's raw_payload (the
            # transport leg), so this still runs exactly once per package — the
            # same call the standalone path makes, on the same booking.
            background_tasks.add_task(book_car_transfers, payload.booking_id)
        else:
            background_tasks.add_task(send_booking_confirmation, payload.booking_id)
            background_tasks.add_task(book_car_transfers, payload.booking_id)

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
