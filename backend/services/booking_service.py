# =============================================================================
# FILE: services/booking_service.py
# PURPOSE: All booking creation, retrieval, and cancellation logic.
#          Centralises DB operations so routers stay thin.
#
# Uses supabase_admin client (service role) for writes to bypass RLS,
# then returns data that the router can pass straight back to Flutter.
# =============================================================================

from __future__ import annotations

import hashlib
import logging
import random
import string
import uuid
from datetime import date, datetime
from typing import Any

from fastapi import HTTPException, status
from postgrest.types import CountMethod

from core.supabase_client import supabase_admin
from models.booking import BookingOut, PassengerCreate, PassengerOut, TicketOut

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Booking ID generation
# ---------------------------------------------------------------------------

def _generate_booking_id(booking_type: str) -> str:
    """Generate a human-readable booking reference: TRV-FL-20240417-A1B2C3."""
    prefix = {"flight": "TRV-FL", "train": "TRV-TR", "hotel": "TRV-HT"}.get(
        booking_type, "TRV-XX"
    )
    date_part = datetime.utcnow().strftime("%Y%m%d")
    rand_part = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
    return f"{prefix}-{date_part}-{rand_part}"


def _generate_pnr(booking_type: str, booking_id: str) -> str:
    """
    Generate a realistic PNR code.
    - Flights: 6 alphanumeric (IATA standard)
    - Trains:  PR + 6 hex digits
    - Hotels:  HT + 6 digits
    """
    digest = hashlib.md5(f"{booking_id}-{booking_type}".encode()).hexdigest().upper()
    if booking_type == "flight":
        return digest[:6]
    if booking_type == "train":
        return f"PR{digest[:6]}"
    return f"HT{digest[:6]}"


# ---------------------------------------------------------------------------
# Create booking
# ---------------------------------------------------------------------------

async def create_booking(
    user_id: str,
    booking_type: str,                   # 'flight' | 'train' | 'hotel'
    contact_email: str,
    total_amount: float,
    raw_payload: dict[str, Any],         # full offer object from search service
    contact_phone: str | None = None,
    origin: str | None = None,
    destination: str | None = None,
    departure_at: datetime | None = None,
    arrival_at: datetime | None = None,
    hotel_name: str | None = None,
    check_in: date | None = None,
    check_out: date | None = None,
    currency: str = "PKR",
) -> BookingOut:
    """
    Insert a new booking row and return the BookingOut model.
    Status starts as 'pending' — updated to 'paid' after OTP verification.
    """
    booking_id = _generate_booking_id(booking_type)
    pnr = _generate_pnr(booking_type, booking_id)

    row: dict[str, Any] = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "booking_id": booking_id,
        "booking_type": booking_type,
        "pnr": pnr,
        "contact_email": contact_email,
        "contact_phone": contact_phone,
        "total_amount": total_amount,
        "currency": currency,
        "status": "pending",
        "raw_payload": raw_payload,
        "origin": origin,
        "destination": destination,
        "departure_at": departure_at.isoformat() if departure_at else None,
        "arrival_at": arrival_at.isoformat() if arrival_at else None,
        "hotel_name": hotel_name,
        "check_in": check_in.isoformat() if check_in else None,
        "check_out": check_out.isoformat() if check_out else None,
    }

    try:
        result = supabase_admin.table("bookings").insert(row).execute()
    except Exception as exc:
        logger.error("Failed to create booking: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create booking. Please try again.",
        )

    data = result.data[0] if result.data else row
    return _row_to_booking_out(data)


# ---------------------------------------------------------------------------
# Get booking(s)
# ---------------------------------------------------------------------------

async def get_booking(booking_uuid: str, user_id: str) -> BookingOut:
    """Fetch a single booking by UUID, including its passengers."""
    try:
        result = (
            supabase_admin.table("bookings")
            .select("*")
            .eq("id", booking_uuid)
            .eq("user_id", user_id)
            .single()
            .execute()
        )
    except Exception as exc:
        logger.error("get_booking error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found.",
        )

    if not result.data:
        raise HTTPException(status_code=404, detail="Booking not found.")

    booking = _row_to_booking_out(result.data)
    booking.passengers = await list_passengers(booking_uuid, user_id)
    return booking


async def list_bookings(
    user_id: str,
    page: int = 1,
    per_page: int = 20,
    status_filter: str | None = None,
    booking_type: str | None = None,
) -> tuple[list[BookingOut], int]:
    """
    Return paginated bookings for a user.
    Returns (list_of_BookingOut, total_count).
    """
    offset = (page - 1) * per_page

    query = (
        supabase_admin.table("bookings")
        .select("*", count=CountMethod.exact)
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .range(offset, offset + per_page - 1)
    )

    if status_filter:
        query = query.eq("status", status_filter)
    if booking_type:
        query = query.eq("booking_type", booking_type)

    try:
        result = query.execute()
    except Exception as exc:
        logger.error("list_bookings error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch bookings.")

    bookings = [_row_to_booking_out(row) for row in (result.data or [])]
    total = result.count or len(bookings)
    return bookings, total


# ---------------------------------------------------------------------------
# Cancel booking
# ---------------------------------------------------------------------------

async def cancel_booking(booking_uuid: str, user_id: str) -> BookingOut:
    """Set booking status to 'cancelled'. Only allowed if not already paid/confirmed."""
    # First fetch to check ownership and current status
    try:
        result = (
            supabase_admin.table("bookings")
            .select("id, user_id, status")
            .eq("id", booking_uuid)
            .eq("user_id", user_id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Booking not found.")

    if not result.data:
        raise HTTPException(status_code=404, detail="Booking not found.")

    current_status = result.data.get("status", "")
    if current_status in ("cancelled", "refunded"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Booking is already {current_status}.",
        )

    try:
        update_result = (
            supabase_admin.table("bookings")
            .update({"status": "cancelled"})
            .eq("id", booking_uuid)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        logger.error("cancel_booking error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to cancel booking.")

    if not update_result.data:
        raise HTTPException(status_code=500, detail="Cancellation failed.")

    return _row_to_booking_out(update_result.data[0])


# ---------------------------------------------------------------------------
# Delete (remove from history) — cancelled bookings only
# ---------------------------------------------------------------------------

async def delete_booking(booking_uuid: str, user_id: str) -> None:
    """Permanently delete a cancelled booking from the user's history."""
    try:
        result = (
            supabase_admin.table("bookings")
            .select("id, user_id, status")
            .eq("id", booking_uuid)
            .eq("user_id", user_id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Booking not found.")

    if not result.data:
        raise HTTPException(status_code=404, detail="Booking not found.")

    if result.data.get("status") not in ("cancelled", "refunded"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only cancelled bookings can be removed from history.",
        )

    try:
        supabase_admin.table("bookings").delete().eq("id", booking_uuid).eq("user_id", user_id).execute()
    except Exception as exc:
        logger.error("delete_booking error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to remove booking.")


# ---------------------------------------------------------------------------
# Ticket data
# ---------------------------------------------------------------------------

async def get_ticket(booking_uuid: str, user_id: str) -> TicketOut:
    """Build structured ticket data for Flutter PDF/card rendering."""
    booking = await get_booking(booking_uuid, user_id)

    # Calculate nights for hotels
    nights = None
    if booking.check_in and booking.check_out:
        nights = (booking.check_out - booking.check_in).days

    # Duration string for flights/trains
    duration = None
    if booking.departure_at and booking.arrival_at:
        delta = booking.arrival_at - booking.departure_at
        total_mins = int(delta.total_seconds() / 60)
        h, m = divmod(total_mins, 60)
        duration = f"{h}h {m}m" if m else f"{h}h"

    return TicketOut(
        booking_id=booking.booking_id,
        pnr=booking.pnr,
        booking_type=booking.booking_type,
        status=booking.status,
        contact_email=booking.contact_email,
        contact_phone=booking.contact_phone,
        total_amount=booking.total_amount,
        currency=booking.currency,
        origin=booking.origin,
        destination=booking.destination,
        departure_at=booking.departure_at,
        arrival_at=booking.arrival_at,
        duration=duration,
        hotel_name=booking.hotel_name,
        hotel_address=None,  # not stored separately — available in raw_payload
        check_in=booking.check_in,
        check_out=booking.check_out,
        nights=nights,
        passengers=booking.passengers,
    )


# ---------------------------------------------------------------------------
# Mark booking as paid (called from payment service)
# ---------------------------------------------------------------------------

async def mark_booking_paid(
    booking_uuid: str,
    transaction_id: str,
    total_amount: float | None = None,
) -> None:
    """Update booking status to 'confirmed', store transaction_id, and sync total_amount."""
    try:
        payload: dict = {"status": "confirmed", "transaction_id": transaction_id}
        if total_amount is not None:
            payload["total_amount"] = total_amount
        supabase_admin.table("bookings").update(payload).eq("id", booking_uuid).execute()
    except Exception as exc:
        logger.error("mark_booking_paid error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update booking status.")


# ---------------------------------------------------------------------------
# Passengers
# ---------------------------------------------------------------------------

async def add_passengers(
    booking_uuid: str,
    user_id: str,
    passengers: list[PassengerCreate],
) -> list[PassengerOut]:
    """Insert passenger rows linked to a booking."""
    rows = []
    for p in passengers:
        row = {
            "id": str(uuid.uuid4()),
            "booking_id": booking_uuid,
            "user_id": user_id,
            **p.model_dump(exclude_none=True),
        }
        if row.get("date_of_birth"):
            row["date_of_birth"] = str(row["date_of_birth"])
        rows.append(row)

    try:
        result = supabase_admin.table("passengers").insert(rows).execute()
    except Exception as exc:
        logger.error("add_passengers error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to add passengers.")

    return [_row_to_passenger_out(r) for r in (result.data or [])]


async def list_passengers(booking_uuid: str, user_id: str) -> list[PassengerOut]:
    """Fetch all passengers for a booking."""
    try:
        result = (
            supabase_admin.table("passengers")
            .select("*")
            .eq("booking_id", booking_uuid)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        logger.error("list_passengers error: %s", exc)
        return []

    return [_row_to_passenger_out(r) for r in (result.data or [])]


async def delete_passenger(passenger_uuid: str, user_id: str) -> bool:
    """Remove a passenger row."""
    try:
        supabase_admin.table("passengers").delete().eq("id", passenger_uuid).eq(
            "user_id", user_id
        ).execute()
        return True
    except Exception as exc:
        logger.error("delete_passenger error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to delete passenger.")


# ---------------------------------------------------------------------------
# Row → model helpers
# ---------------------------------------------------------------------------

def _row_to_booking_out(row: dict[str, Any]) -> BookingOut:
    def _dt(val: Any) -> datetime | None:
        if not val:
            return None
        if isinstance(val, datetime):
            return val
        try:
            return datetime.fromisoformat(str(val))
        except ValueError:
            return None

    def _d(val: Any) -> date | None:
        if not val:
            return None
        if isinstance(val, date):
            return val
        try:
            return date.fromisoformat(str(val)[:10])
        except ValueError:
            return None

    return BookingOut(
        id=str(row.get("id", "")),
        user_id=str(row.get("user_id", "")),
        booking_id=str(row.get("booking_id", "")),
        booking_type=str(row.get("booking_type", "")),
        pnr=row.get("pnr"),
        transaction_id=row.get("transaction_id"),
        contact_email=str(row.get("contact_email", "")),
        contact_phone=row.get("contact_phone"),
        total_amount=float(row.get("total_amount", 0)),
        currency=str(row.get("currency", "PKR")),
        status=str(row.get("status", "pending")),
        origin=row.get("origin"),
        destination=row.get("destination"),
        departure_at=_dt(row.get("departure_at")),
        arrival_at=_dt(row.get("arrival_at")),
        hotel_name=row.get("hotel_name"),
        check_in=_d(row.get("check_in")),
        check_out=_d(row.get("check_out")),
        raw_payload=row.get("raw_payload"),
        passengers=[],
        created_at=_dt(row.get("created_at")),
        updated_at=_dt(row.get("updated_at")),
    )


def _row_to_passenger_out(row: dict[str, Any]) -> PassengerOut:
    return PassengerOut(
        id=str(row.get("id", "")),
        booking_id=str(row.get("booking_id", "")),
        user_id=str(row.get("user_id", "")),
        title=row.get("title"),
        first_name=str(row.get("first_name", "")),
        last_name=str(row.get("last_name", "")),
        date_of_birth=row.get("date_of_birth"),
        gender=row.get("gender"),
        nationality=row.get("nationality", "Pakistani"),
        cnic=row.get("cnic"),
        passport_number=row.get("passport_number"),
        seat_number=row.get("seat_number"),
        passenger_type=str(row.get("passenger_type", "adult")),
        created_at=row.get("created_at"),
    )
