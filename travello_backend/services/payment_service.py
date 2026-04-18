# =============================================================================
# FILE: services/payment_service.py
# PURPOSE: Simulated JazzCash / EasyPaisa / Card payment flow.
#
# Flow for mobile wallets (JazzCash / EasyPaisa):
#   1. POST /payments/initiate
#       → create payment_attempt row (status='otp_sent')
#       → generate 6-digit OTP
#       → bcrypt-hash the OTP and store in payment_otps
#       → send OTP to user's email (simulating SMS — no paid SMS gateway needed)
#       → return {request_id, otp_required: true, expires_at}
#
#   2. POST /payments/verify-otp
#       → look up payment_otp by request_id
#       → verify bcrypt hash, check expiry, check attempts <= 3
#       → if valid: mark payment_attempt='completed', mark booking='paid',
#                   create notification, trigger confirmation email
#       → return {success, booking_id, transaction_id}
#
# Flow for card:
#   1. POST /payments/initiate
#       → create payment_attempt row (status='completed' after simulated 2s)
#       → return {request_id, otp_required: false}
#   (no step 2 needed — booking is marked paid immediately)
# =============================================================================

from __future__ import annotations

import logging
import random
import string
import uuid
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException, status
from passlib.context import CryptContext

from core.config import settings
from core.email import send_otp_email
from core.supabase_client import supabase_admin
from models.payment import PaymentAttemptOut, PaymentInitiateResponse, OTPVerifyResponse
from services.booking_service import mark_booking_paid

logger = logging.getLogger(__name__)

# bcrypt context for hashing OTPs
_bcrypt = CryptContext(schemes=["bcrypt"], deprecated="auto")

WALLET_METHODS = {"jazzcash", "easypaisa"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _generate_otp(length: int = 6) -> str:
    """Generate a cryptographically random 6-digit numeric OTP."""
    return "".join(random.choices(string.digits, k=length))


def _generate_transaction_id(method: str) -> str:
    """Simulate a provider reference number."""
    prefix = {
        "jazzcash": "JC",
        "easypaisa": "EP",
        "card": "CRD",
        "bank_transfer": "BNK",
    }.get(method, "TRV")
    ts = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    rand = "".join(random.choices(string.digits, k=6))
    return f"{prefix}{ts}{rand}"


async def _get_booking_row(booking_uuid: str, user_id: str) -> dict[str, Any]:
    """Fetch and validate a booking exists and belongs to the user."""
    try:
        result = (
            supabase_admin.table("bookings")
            .select("id, user_id, status, contact_email, contact_phone, total_amount, booking_id")
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
    row: dict[str, Any] = {
        "id": attempt_id,
        "user_id": user_id,
        "booking_id": booking_uuid,
        "payment_method": method,
        "amount": amount,
        "currency": currency,
        "status": attempt_status,
        "provider_reference": provider_reference,
        "metadata": metadata or {},
    }
    try:
        supabase_admin.table("payment_attempts").insert(row).execute()
    except Exception as exc:
        logger.error("Failed to create payment attempt: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to initiate payment.")
    return attempt_id


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


# ---------------------------------------------------------------------------
# Initiate payment
# ---------------------------------------------------------------------------

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
    - Wallet methods → OTP flow
    - Card → instant simulated success
    """
    booking = await _get_booking_row(booking_uuid, user_id)
    contact_email = email_override or booking.get("contact_email", "")

    if method in WALLET_METHODS:
        # Rate limit: max 3 OTP requests per user in the last 15 minutes
        cutoff = (datetime.utcnow() - timedelta(minutes=15)).isoformat()
        try:
            rate_result = (
                supabase_admin.table("payment_otps")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .gte("created_at", cutoff)
                .execute()
            )
            if (rate_result.count or 0) >= 3:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many OTP requests. Please wait 15 minutes.",
                )
        except HTTPException:
            raise
        except Exception as exc:
            logger.warning("OTP rate limit check failed (continuing): %s", exc)

        # --- Wallet OTP flow ---
        otp = _generate_otp()
        otp_hash = _bcrypt.hash(otp)
        expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

        attempt_id = await _create_payment_attempt(
            user_id=user_id,
            booking_uuid=booking_uuid,
            method=method,
            amount=amount,
            currency=currency,
            attempt_status="otp_sent",
            metadata={"phone": phone, "email": contact_email},
        )

        # Store OTP record
        otp_row = {
            "id": str(uuid.uuid4()),
            "request_id": attempt_id,
            "user_id": user_id,
            "email": contact_email,
            "phone": phone or booking.get("contact_phone"),
            "provider": method,
            "otp_hash": otp_hash,
            "attempts": 0,
            "verified": False,
            "expires_at": expires_at.isoformat(),
        }
        try:
            supabase_admin.table("payment_otps").insert(otp_row).execute()
        except Exception as exc:
            logger.error("Failed to store OTP: %s", exc)
            raise HTTPException(status_code=500, detail="Failed to generate OTP.")

        # Send OTP email (simulates SMS for FYP demo)
        try:
            await send_otp_email(
                to=contact_email,
                otp=otp,
                provider=method,
                amount=amount,
                phone=phone or booking.get("contact_phone"),
            )
        except Exception as exc:
            logger.warning("OTP email failed (continuing): %s", exc)

        provider_display = "JazzCash" if method == "jazzcash" else "EasyPaisa"
        return PaymentInitiateResponse(
            request_id=attempt_id,
            otp_required=True,
            message=f"A 6-digit OTP has been sent to {contact_email}. "
                    f"Enter it to confirm your {provider_display} payment.",
            expires_at=expires_at,
        )

    else:
        # --- Card / bank transfer: instant simulated success ---
        transaction_id = _generate_transaction_id(method)

        attempt_id = await _create_payment_attempt(
            user_id=user_id,
            booking_uuid=booking_uuid,
            method=method,
            amount=amount,
            currency=currency,
            attempt_status="completed",
            provider_reference=transaction_id,
            metadata={"simulated": True},
        )

        # Mark booking as paid immediately
        await mark_booking_paid(booking_uuid, transaction_id)

        # Send booking confirmation email (non-fatal if it fails)
        try:
            from services.email_service import send_booking_confirmation
            await send_booking_confirmation(booking_uuid)
        except Exception as exc:
            logger.warning("Card payment confirmation email failed (non-fatal): %s", exc)

        # Create success notification
        await _create_notification(
            user_id=user_id,
            title="Payment Successful",
            body=f"Your payment of PKR {amount:,.0f} was processed successfully.",
            notif_type="payment_success",
            data={"booking_id": booking_uuid, "transaction_id": transaction_id},
        )

        return PaymentInitiateResponse(
            request_id=attempt_id,
            otp_required=False,
            message="Payment processed successfully. Your booking is confirmed.",
            expires_at=None,
        )


# ---------------------------------------------------------------------------
# Verify OTP
# ---------------------------------------------------------------------------

async def verify_otp(
    user_id: str,
    request_id: str,
    otp: str,
) -> OTPVerifyResponse:
    """
    Verify the OTP for a wallet payment.
    Returns success response with booking_id and transaction_id.
    """
    # Fetch OTP record
    try:
        result = (
            supabase_admin.table("payment_otps")
            .select("*")
            .eq("request_id", request_id)
            .eq("user_id", user_id)
            .eq("verified", False)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="OTP request not found.")

    if not result.data:
        raise HTTPException(status_code=404, detail="OTP request not found or already used.")

    otp_record = result.data

    # Check expiry
    expires_at = datetime.fromisoformat(str(otp_record["expires_at"]).replace("Z", "+00:00"))
    if datetime.utcnow().replace(tzinfo=expires_at.tzinfo) > expires_at:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="OTP has expired. Please initiate a new payment.",
        )

    # Check max attempts
    attempts = int(otp_record.get("attempts", 0))
    if attempts >= settings.OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Maximum OTP attempts ({settings.OTP_MAX_ATTEMPTS}) exceeded. "
                   "Please start a new payment.",
        )

    # Increment attempt counter first (prevents timing attacks)
    supabase_admin.table("payment_otps").update(
        {"attempts": attempts + 1}
    ).eq("id", otp_record["id"]).execute()

    # Verify OTP hash
    otp_valid = _bcrypt.verify(otp, otp_record["otp_hash"])
    if not otp_valid:
        remaining = settings.OTP_MAX_ATTEMPTS - (attempts + 1)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid OTP. {remaining} attempt(s) remaining.",
        )

    # --- OTP correct ---

    # Mark OTP as verified
    supabase_admin.table("payment_otps").update(
        {"verified": True, "verified_at": datetime.utcnow().isoformat()}
    ).eq("id", otp_record["id"]).execute()

    # Generate transaction ID and update payment attempt
    transaction_id = _generate_transaction_id(otp_record["provider"])
    supabase_admin.table("payment_attempts").update(
        {"status": "completed", "provider_reference": transaction_id}
    ).eq("id", request_id).execute()

    # Fetch the booking linked to this payment attempt
    attempt_result = (
        supabase_admin.table("payment_attempts")
        .select("booking_id")
        .eq("id", request_id)
        .single()
        .execute()
    )
    booking_uuid = attempt_result.data["booking_id"]

    # Mark booking as paid
    await mark_booking_paid(booking_uuid, transaction_id)

    # Create success notification
    await _create_notification(
        user_id=user_id,
        title="Payment Successful",
        body=f"Your {otp_record['provider'].title()} payment was confirmed. "
             "Your booking is now paid.",
        notif_type="payment_success",
        data={"booking_id": booking_uuid, "transaction_id": transaction_id},
    )

    # Fetch the booking_id (human-readable) for the response
    booking_result = (
        supabase_admin.table("bookings")
        .select("booking_id")
        .eq("id", booking_uuid)
        .single()
        .execute()
    )
    readable_booking_id = (
        booking_result.data.get("booking_id", booking_uuid)
        if booking_result.data else booking_uuid
    )

    return OTPVerifyResponse(
        success=True,
        booking_id=readable_booking_id,
        transaction_id=transaction_id,
        message="Payment verified successfully. Your booking is confirmed!",
    )


# ---------------------------------------------------------------------------
# Payment history
# ---------------------------------------------------------------------------

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
