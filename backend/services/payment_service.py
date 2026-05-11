# =============================================================================
# PURPOSE: Card / bank transfer payment flow (instant simulated success).
#
# POST /payments/initiate  (method: 'card')
#   → create payment_attempt row (status='pending')
#   → mark booking as paid
#   → create in-app notification
#   → update payment_attempt to 'completed'
#   → return {request_id, otp_required: false, transaction_id}
# =============================================================================

from __future__ import annotations

import logging
import random
import string
import uuid
from datetime import datetime
from typing import Any

from fastapi import HTTPException, status

from core.supabase_client import supabase_admin
from models.payment import PaymentAttemptOut, PaymentInitiateResponse
from services.booking_service import mark_booking_paid

logger = logging.getLogger(__name__)

INSTANT_METHODS = {"card", "bank_transfer"}


# Helpers

def _generate_transaction_id(method: str) -> str:
    """Simulate a provider reference number."""
    prefix = {"bank_transfer": "BNK"}.get(method, "TRV")
    ts = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    rand = "".join(random.choices(string.digits, k=6))
    return f"{prefix}{ts}{rand}"


async def _get_booking_row(booking_uuid: str, user_id: str) -> dict[str, Any]:
    """Fetch and validate a booking exists and belongs to the user."""
    try:
        result = (
            supabase_admin.table("bookings")
            .select("id, user_id, status, contact_email, contact_phone, total_amount, booking_id, pnr")
            .eq("id", booking_uuid)
            .eq("user_id", user_id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Booking not found.")

    if not result.data:
        raise HTTPException(status_code=404, detail="Booking not found.")

    booking = result.data
    if booking.get("status") in ("paid", "confirmed"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This booking has already been paid.",
        )
    if booking.get("status") == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot pay for a cancelled booking.",
        )
    return booking


async def _create_payment_attempt(
    user_id: str,
    booking_uuid: str,
    method: str,
    amount: float,
    currency: str,
    attempt_status: str,
    provider_reference: str | None = None,
    metadata: dict | None = None,
) -> str:
    """Insert a payment_attempt row and return its UUID."""
    attempt_id = str(uuid.uuid4())
    row_without_status: dict[str, Any] = {
        "id": attempt_id,
        "user_id": user_id,
        "booking_id": booking_uuid,
        "payment_method": method,
        "amount": amount,
        "currency": currency,
        "provider_reference": provider_reference,
        "metadata": metadata or {},
    }

    # Try explicit statuses first so both migrated and legacy DB constraints work.
    for status_value in _status_insert_candidates(attempt_status):
        row = dict(row_without_status)
        row["status"] = status_value
        try:
            supabase_admin.table("payment_attempts").insert(row).execute()
            return attempt_id
        except Exception as exc:
            if _is_status_constraint_error(exc):
                logger.warning(
                    "payment_attempt insert status '%s' rejected for booking %s; trying fallback",
                    status_value,
                    booking_uuid,
                )
                continue
            logger.error("Failed to create payment attempt: %s", exc)
            raise HTTPException(status_code=500, detail="Failed to initiate payment.")

    # Final fallback: omit status and use DB default value.
    try:
        supabase_admin.table("payment_attempts").insert(row_without_status).execute()
    except Exception as exc:
        logger.error("Failed to create payment attempt: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to initiate payment.")
    return attempt_id


def _is_status_constraint_error(exc: Exception) -> bool:
    text = str(exc).lower()
    return (
        "payment_attempts_status_check" in text
        or ("23514" in text and "status" in text)
    )


def _status_insert_candidates(preferred_status: str) -> list[str]:
    """Return candidate statuses from most preferred to broad compatibility fallbacks."""
    candidates = [
        preferred_status,
        "pending",
        "otp_sent",
        "initiated",
        "created",
        "processing",
        "completed",
        "paid",
        "success",
        "failed",
    ]

    seen: set[str] = set()
    ordered: list[str] = []
    for value in candidates:
        if value in seen:
            continue
        seen.add(value)
        ordered.append(value)
    return ordered


def _update_payment_attempt_status_best_effort(
    attempt_id: str,
    preferred_status: str,
    provider_reference: str | None = None,
) -> str | None:
    """Try multiple status labels to handle drift between local and live DB constraints."""
    candidates = [preferred_status, "paid", "success", "completed", "pending"]
    seen: set[str] = set()
    for status_value in candidates:
        if status_value in seen:
            continue
        seen.add(status_value)

        payload: dict[str, Any] = {"status": status_value}
        if provider_reference:
            payload["provider_reference"] = provider_reference

        try:
            supabase_admin.table("payment_attempts").update(payload).eq("id", attempt_id).execute()
            return status_value
        except Exception as exc:
            if _is_status_constraint_error(exc):
                logger.warning(
                    "payment_attempt status '%s' rejected for %s; trying fallback",
                    status_value,
                    attempt_id,
                )
                continue
            logger.warning("Failed updating payment_attempt %s status: %s", attempt_id, exc)
            return None

    logger.warning("All fallback statuses rejected for payment_attempt %s", attempt_id)
    return None


async def _create_notification(
    user_id: str,
    title: str,
    body: str,
    notif_type: str,
    data: dict | None = None,
) -> None:
    """Insert a notification row via service role (bypasses RLS)."""
    row = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "title": title,
        "body": body,
        "type": notif_type,
        "data": data or {},
    }
    try:
        supabase_admin.table("notifications").insert(row).execute()
    except Exception as exc:
        logger.warning("Failed to create notification: %s", exc)


# Initiate payment

async def initiate_payment(
    user_id: str,
    booking_uuid: str,
    method: str,
    amount: float,
    phone: str | None = None,
    email_override: str | None = None,
    currency: str = "PKR",
) -> PaymentInitiateResponse:
    """
    Start a payment attempt.
    - card / bank_transfer → instant simulated success, booking marked paid immediately
    """
    if method not in INSTANT_METHODS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported payment method '{method}'. Use 'card' or 'bank_transfer'.",
        )

    booking = await _get_booking_row(booking_uuid, user_id)

    # --- Card / bank transfer: instant simulated success ---
    transaction_id = _generate_transaction_id(method)

    attempt_id = await _create_payment_attempt(
        user_id=user_id,
        booking_uuid=booking_uuid,
        method=method,
        amount=amount,
        currency=currency,
        attempt_status="pending",
        provider_reference=transaction_id,
        metadata={"simulated": True},
    )

    await mark_booking_paid(booking_uuid, transaction_id, total_amount=amount)

    await _create_notification(
        user_id=user_id,
        title="Payment Successful",
        body=f"Your payment of PKR {amount:,.0f} was processed successfully.",
        notif_type="payment_success",
        data={"booking_id": booking_uuid, "transaction_id": transaction_id},
    )

    _update_payment_attempt_status_best_effort(
        attempt_id=attempt_id,
        preferred_status="completed",
        provider_reference=transaction_id,
    )

    return PaymentInitiateResponse(
        request_id=attempt_id,
        otp_required=False,
        message="Payment processed successfully. Your booking is confirmed.",
        expires_at=None,
        booking_id=booking.get("booking_id"),
        pnr=booking.get("pnr"),
        transaction_id=transaction_id,
    )

# Payment history

async def get_payment_history(booking_uuid: str, user_id: str) -> list[PaymentAttemptOut]:
    """Return all payment attempts for a booking."""
    try:
        result = (
            supabase_admin.table("payment_attempts")
            .select("*")
            .eq("booking_id", booking_uuid)
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception as exc:
        logger.error("get_payment_history error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch payment history.")

    return [
        PaymentAttemptOut(
            id=str(r.get("id", "")),
            booking_id=str(r.get("booking_id", "")),
            payment_method=str(r.get("payment_method", "")),
            amount=float(r.get("amount", 0)),
            currency=str(r.get("currency", "PKR")),
            status=str(r.get("status", "")),
            provider_reference=r.get("provider_reference"),
            metadata=r.get("metadata"),
            created_at=r.get("created_at"),
            updated_at=r.get("updated_at"),
        )
        for r in (result.data or [])
    ]
