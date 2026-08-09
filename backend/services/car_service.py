# =============================================================================
# PURPOSE: Car transfer booking service.
#          After payment succeeds, reads car transfer selections from the
#          booking's raw_payload, assigns a random driver by vehicle type,
#          saves to car_bookings, and sends a driver assignment email per leg.
# =============================================================================

from __future__ import annotations

import logging
import random
import re
import string
import uuid
from math import asin, cos, radians, sin, sqrt
from typing import Any

from core.supabase_client import supabase_admin
from services.northern_routes import price_for_route
from services.weather_service import CITY_COORDS

logger = logging.getLogger(__name__)

_TRANSFER_LABELS = {
    "departure":        "Departure Transfer (Your Location → Airport)",
    "arrival":          "Arrival Transfer (Airport → Your Destination)",
    "return_departure": "Return Transfer (Your Location → Airport)",
    "return_arrival":   "Final Arrival Transfer (Airport → Your Home)",
    "standalone":       "On-Demand Driver Booking",
}

_VEHICLE_PRICES: dict[str, int] = {
    "Sedan": 3000,
    "SUV":   6000,
    "Van":   9000,
}


def _price_for(vehicle_type: str) -> int:
    return _VEHICLE_PRICES.get(vehicle_type, 3000)


# ── Long-distance (out-of-city) fallback pricing ──────────────────────────
#
# The flat rates above are an in-city rate — fine for an airport transfer or
# a ride across town, absurd for a genuine point-to-point road trip (e.g.
# Karachi -> Skardu, ~1,900km) that names no known hub<->northern-destination
# route (price_for_route only covers the 6 sourced legs in northern_routes.py).
# Reuses weather_service.CITY_COORDS (already maintained for weather lookups)
# rather than a second city table, and prices per straight-line km once both
# ends name a KNOWN city and the distance clears an in-city threshold — so an
# ordinary same-city ride is untouched. Estimate, not a real routing engine:
# haversine distance undercounts actual road distance on mountain routes, so
# this is a floor, not a precise quote.
_PER_KM_RATES: dict[str, float] = {
    "Sedan": 30,
    "SUV":   40,
    "Van":   50,
}
_LONG_DISTANCE_MIN_KM = 100
_CITY_NAME_TOKENS = sorted(CITY_COORDS, key=len, reverse=True)


def _city_in(text: str) -> tuple[str, float, float] | None:
    low = (text or "").lower()
    for name in _CITY_NAME_TOKENS:
        if re.search(rf"\b{re.escape(name.lower())}\b", low):
            lat, lon = CITY_COORDS[name]
            return name, lat, lon
    return None


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0  # earth radius, km
    p1, p2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lon2 - lon1)
    h = sin(dphi / 2) ** 2 + cos(p1) * cos(p2) * sin(dlambda / 2) ** 2
    return 2 * r * asin(sqrt(h))


def _estimate_by_distance(vehicle_type: str, pickup_location: str, dropoff_location: str) -> int | None:
    """PKR fare for a genuine long-distance ride between two KNOWN, DIFFERENT
    cities named in the pickup/dropoff text — or None so the caller falls
    back to the flat in-city rate (an unrecognised address, a same-city ride,
    or an unrecognised vehicle type all fall through here on purpose)."""
    rate = _PER_KM_RATES.get(vehicle_type)
    if rate is None:
        return None
    pickup = _city_in(pickup_location)
    dropoff = _city_in(dropoff_location)
    if not pickup or not dropoff or pickup[0] == dropoff[0]:
        return None
    distance_km = _haversine_km(pickup[1], pickup[2], dropoff[1], dropoff[2])
    if distance_km < _LONG_DISTANCE_MIN_KM:
        return None
    return round(distance_km * rate / 100) * 100


def estimate_fare(vehicle_type: str, pickup_location: str = "", dropoff_location: str = "") -> int:
    """
    Route-aware fare: a known hub<->northern-destination route (Islamabad/
    Rawalpindi->Naran, Gilgit->Hunza, Islamabad/Rawalpindi->Swat) prices by
    real (sourced/estimated) distance first; failing that, a genuine
    long-distance ride between two other known cities prices per km
    (_estimate_by_distance); everything else — an ordinary in-city ride or
    an airport/station transfer, or an address naming no known city — keeps
    the flat rate. Called with no addresses (as every existing transfer-leg
    call site does), this behaves exactly like `_price_for` always has.
    """
    if pickup_location or dropoff_location:
        routed = price_for_route(pickup_location, dropoff_location, vehicle_type)
        if routed is not None:
            return routed
        by_distance = _estimate_by_distance(vehicle_type, pickup_location, dropoff_location)
        if by_distance is not None:
            return by_distance
    return _price_for(vehicle_type)


def _generate_verification_code() -> str:
    return "".join(random.choices(string.digits, k=4))


def _pick_driver(vehicle_type: str) -> dict[str, Any] | None:
    try:
        result = (
            supabase_admin.table("drivers")
            .select("*")
            .eq("vehicle_type", vehicle_type)
            .eq("is_active", True)
            .execute()
        )
        drivers = result.data or []
        if not drivers:
            return None
        return random.choice(drivers)
    except Exception as exc:
        logger.error("_pick_driver error vehicle_type=%s: %s", vehicle_type, exc)
        return None


def _create_car_booking_row(
    booking_uuid: str,
    user_id: str,
    driver: dict[str, Any],
    transfer_type: str,
    pickup_location: str,
    vehicle_type: str,
    contact_email: str,
    verification_code: str,
    dropoff_location: str = "",
) -> dict[str, Any] | None:
    row = {
        "id": str(uuid.uuid4()),
        "booking_id": booking_uuid,
        "user_id": user_id,
        "driver_id": str(driver["id"]),
        "transfer_type": transfer_type,
        "pickup_location": pickup_location,
        "dropoff_location": dropoff_location or None,
        "vehicle_type": vehicle_type,
        "verification_code": verification_code,
        "contact_email": contact_email,
        "status": "confirmed",
        "total_amount": estimate_fare(vehicle_type, pickup_location, dropoff_location),
        "currency": "PKR",
    }
    try:
        result = supabase_admin.table("car_bookings").insert(row).execute()
        return result.data[0] if result.data else row
    except Exception as exc:
        logger.error("_create_car_booking_row error: %s", exc)
        return None


async def book_car_transfers(booking_uuid: str) -> None:
    """
    Background task called after payment succeeds.
    Reads transfer selections from raw_payload, assigns a driver per leg,
    writes car_bookings rows, and sends driver emails.
    """
    from services.email_service import send_consolidated_car_booking_email, send_internal_car_booking_summary  # avoid circular import

    try:
        result = (
            supabase_admin.table("bookings")
            .select("id, user_id, contact_email, raw_payload, origin, destination, departure_at, booking_id, pnr")
            .eq("id", booking_uuid)
            .single()
            .execute()
        )
    except Exception as exc:
        logger.error("book_car_transfers: fetch booking %s failed: %s", booking_uuid, exc)
        return

    if not result.data:
        return

    booking = result.data
    raw = booking.get("raw_payload") or {}
    user_id = booking.get("user_id", "")
    contact_email = booking.get("contact_email", "")

    # Each transfer leg: flag key, vehicle type key, pickup location key,
    # dropoff location key (northern-trip legs only — empty for an ordinary
    # airport/station transfer), DB type value.
    legs = [
        ("transferAdded",            "transferVehicleType",            "transferPickupLocation",            "transferDropoffLocation",            "departure"),
        ("arrivalTransferAdded",     "arrivalTransferVehicleType",     "arrivalTransferPickupLocation",     "arrivalTransferDropoffLocation",     "arrival"),
        ("returnTransferAdded",      "returnTransferVehicleType",      "returnTransferPickupLocation",      "returnTransferDropoffLocation",      "return_departure"),
        ("finalArrivalTransferAdded","finalArrivalTransferVehicleType","finalArrivalTransferPickupLocation","finalArrivalTransferDropoffLocation","return_arrival"),
    ]

    confirmed_legs: list[dict] = []

    for added_key, type_key, location_key, dropoff_key, transfer_type in legs:
        if not raw.get(added_key):
            continue

        vehicle_type     = raw.get(type_key, "Sedan")
        pickup_location  = raw.get(location_key, "").strip()
        dropoff_location = raw.get(dropoff_key, "").strip()

        if not pickup_location:
            logger.warning("book_car_transfers: no pickup location for %s in booking %s", transfer_type, booking_uuid)
            continue

        driver = _pick_driver(vehicle_type)
        if not driver:
            logger.warning("book_car_transfers: no driver available type=%s booking=%s", vehicle_type, booking_uuid)
            continue

        code = _generate_verification_code()

        _create_car_booking_row(
            booking_uuid=booking_uuid,
            user_id=user_id,
            driver=driver,
            transfer_type=transfer_type,
            pickup_location=pickup_location,
            vehicle_type=vehicle_type,
            contact_email=contact_email,
            verification_code=code,
            dropoff_location=dropoff_location,
        )

        confirmed_legs.append({
            "transfer_type":    transfer_type,
            "vehicle_type":     vehicle_type,
            "pickup_location":  pickup_location,
            "dropoff_location": dropoff_location,
            "driver":           driver,
            "code":             code,
        })

        logger.info(
            "Car transfer confirmed: booking=%s type=%s driver=%s code=%s",
            booking_uuid, transfer_type, driver.get("name"), code,
        )

    # One consolidated email to user + one internal notification for all legs
    if confirmed_legs:
        if contact_email:
            try:
                await send_consolidated_car_booking_email(
                    contact_email=contact_email,
                    legs=confirmed_legs,
                    booking=booking,
                )
            except Exception as exc:
                logger.warning("Consolidated car email failed booking=%s: %s", booking_uuid, exc)

        await send_internal_car_booking_summary(
            user_email=contact_email or "unknown",
            booking_ref=booking.get("booking_id", booking_uuid),
            booking_route=f"{booking.get('origin', '—')} → {booking.get('destination', '—')}",
            legs=confirmed_legs,
        )


# =============================================================================
# Standalone car booking (Car tab on home screen — no parent booking)
# =============================================================================

async def book_standalone_car(
    user_id: str,
    pickup_location: str,
    dropoff_location: str,
    vehicle_type: str,
    pickup_datetime: str,
    contact_email: str | None,
    user_email: str | None = None,
) -> dict[str, Any] | None:
    """
    Book a driver without an existing travel booking.
    Picks a random active driver by vehicle type, saves to car_bookings,
    and sends a confirmation email.
    Returns the booking result dict, or None if no driver is available.
    """
    from services.email_service import send_car_booking_email, send_internal_car_notification  # avoid circular import

    driver = _pick_driver(vehicle_type)
    if not driver:
        logger.warning("book_standalone_car: no driver available type=%s", vehicle_type)
        return None

    code            = _generate_verification_code()
    booking_uuid    = str(uuid.uuid4())
    email_to_use    = contact_email or user_email or ""
    price           = estimate_fare(vehicle_type, pickup_location, dropoff_location)

    row = {
        "id":                booking_uuid,
        "booking_id":        None,        # standalone — no parent travel booking
        "user_id":           user_id,
        "driver_id":         str(driver["id"]),
        "transfer_type":     "standalone",
        "pickup_location":   pickup_location,
        "dropoff_location":  dropoff_location,
        "vehicle_type":      vehicle_type,
        "pickup_datetime":   pickup_datetime,
        "verification_code": code,
        "contact_email":     email_to_use,
        "status":            "confirmed",
        "total_amount":      price,
        "currency":          "PKR",
    }

    try:
        supabase_admin.table("car_bookings").insert(row).execute()
    except Exception as exc:
        logger.error("book_standalone_car: DB insert failed: %s", exc)
        return None

    # Send driver-assignment email to user + internal notification (best-effort)
    booking_meta = {
        "booking_id": booking_uuid,
        "origin":      pickup_location,
        "destination": dropoff_location,
        "departure_at": pickup_datetime,
    }
    if email_to_use:
        try:
            await send_car_booking_email(
                contact_email=email_to_use,
                driver=driver,
                transfer_type="standalone",
                pickup_location=pickup_location,
                verification_code=code,
                booking=booking_meta,
            )
        except Exception as exc:
            logger.warning("book_standalone_car: user email failed: %s", exc)

    await send_internal_car_notification(
        user_email=email_to_use or "unknown",
        driver=driver,
        transfer_type="standalone",
        pickup_location=pickup_location,
        dropoff_location=dropoff_location,
        vehicle_type=vehicle_type,
        verification_code=code,
        booking_id=booking_uuid,
        pickup_datetime=pickup_datetime,
        total_amount=price,
    )

    logger.info(
        "Standalone car confirmed: id=%s type=%s driver=%s code=%s",
        booking_uuid, vehicle_type, driver.get("name"), code,
    )

    return {
        "booking_id":       booking_uuid,
        "driver": {
            "name":          driver.get("name"),
            "phone":         driver.get("phone"),
            "vehicle_type":  driver.get("vehicle_type"),
            "vehicle_make":  driver.get("vehicle_make"),
            "vehicle_model": driver.get("vehicle_model"),
            "vehicle_plate": driver.get("vehicle_plate"),
            "vehicle_color": driver.get("vehicle_color"),
            "rating":        driver.get("rating"),
        },
        "verification_code":  code,
        "pickup_location":    pickup_location,
        "dropoff_location":   dropoff_location,
        "vehicle_type":       vehicle_type,
        "pickup_datetime":    pickup_datetime,
        "status":             "confirmed",
        "total_amount":       price,
        "currency":           "PKR",
    }
