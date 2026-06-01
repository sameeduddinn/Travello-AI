# =============================================================================
# PURPOSE: Standalone car (driver) booking endpoint.
#          POST /cars/book — lets a user book a driver without a travel booking.
#          Assigns a random available driver, saves to car_bookings,
#          and sends a driver assignment email.
# =============================================================================

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, HTTPException, status

from core.auth import CurrentUser
from core.supabase_client import supabase_admin
from pydantic import BaseModel, field_validator
from services.car_service import book_standalone_car

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/cars", tags=["Cars"])


class CarBookRequest(BaseModel):
    pickup_location: str
    dropoff_location: str
    vehicle_type: str   # Sedan | SUV | Van
    pickup_datetime: str  # ISO 8601 datetime string
    contact_email: str | None = None

    @field_validator("vehicle_type")
    @classmethod
    def validate_vehicle(cls, v: str) -> str:
        allowed = {"Sedan", "SUV", "Van"}
        if v not in allowed:
            raise ValueError(f"vehicle_type must be one of {sorted(allowed)}")
        return v

    @field_validator("pickup_location", "dropoff_location")
    @classmethod
    def not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Location cannot be empty")
        return v.strip()


@router.post("/book", status_code=status.HTTP_201_CREATED)
async def book_car(payload: CarBookRequest, user: CurrentUser):
    """
    Book a standalone driver (no flight/train/hotel booking required).

    Assigns the next available driver matching the requested vehicle type,
    saves the booking to car_bookings, and fires a driver-assignment email.

    Returns driver info, verification code, and booking confirmation.
    """
    contact_email = (payload.contact_email or "").strip() or None

    result = await book_standalone_car(
        user_id=user.id,
        pickup_location=payload.pickup_location,
        dropoff_location=payload.dropoff_location,
        vehicle_type=payload.vehicle_type,
        pickup_datetime=payload.pickup_datetime,
        contact_email=contact_email,
        user_email=user.email,
    )

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No drivers are currently available for the selected vehicle type. Please try again shortly.",
        )

    return result


@router.get("/bookings", status_code=status.HTTP_200_OK)
async def list_car_bookings(user: CurrentUser):
    """Return all car bookings for the authenticated user, newest first, with driver info."""
    def _query():
        return (
            supabase_admin
            .table("car_bookings")
            .select("*, drivers(*)")
            .eq("user_id", user.id)
            .order("created_at", desc=True)
            .execute()
        )
    try:
        result = await asyncio.to_thread(_query)
        return {"bookings": result.data or []}
    except Exception as exc:
        logger.error("list_car_bookings error user=%s: %s", user.id, exc)
        raise HTTPException(status_code=500, detail="Failed to fetch car bookings")
