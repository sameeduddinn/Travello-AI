# =============================================================================
# FILE: services/aviationstack_service.py
# PURPOSE: AviationStack real-time flights integration.
#          Uses /v1/flights (supported on free plan) to get real airline names,
#          flight numbers, and scheduled times for Pakistani routes.
#          Prices are mock (AviationStack doesn't provide fares).
#
# Free tier: unlimited API calls, /v1/flights endpoint only.
# Flights are cached 6 hours per route to minimise calls.
#
# Docs: https://aviationstack.com/documentation
# =============================================================================

from __future__ import annotations

import logging
import random
from datetime import datetime, timedelta
from typing import Any

import httpx

from core.config import settings
from models.flight import FlightOffer, FlightItinerary, FlightSegment

logger = logging.getLogger(__name__)

AVIATIONSTACK_BASE = "http://api.aviationstack.com/v1"

# Cache: "KHI-LHE" -> (flights_list, fetched_at)
_flight_cache: dict[str, tuple[list[dict], datetime]] = {}
CACHE_TTL = timedelta(hours=6)


# ---------------------------------------------------------------------------
# Fetch real-time flights from AviationStack
# ---------------------------------------------------------------------------

async def _fetch_flights(dep_iata: str, arr_iata: str) -> list[dict]:
    """Call AviationStack /v1/flights and return raw flight dicts. Cached 6 h."""
    cache_key = f"{dep_iata.upper()}-{arr_iata.upper()}"
    cached = _flight_cache.get(cache_key)
    if cached:
        flights, fetched_at = cached
        if datetime.utcnow() - fetched_at < CACHE_TTL:
            logger.debug("AviationStack cache hit for %s", cache_key)
            return flights

    if not settings.AVIATIONSTACK_KEY:
        return []

    params = {
        "access_key": settings.AVIATIONSTACK_KEY,
        "dep_iata": dep_iata.upper(),
        "arr_iata": arr_iata.upper(),
        "limit": 20,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{AVIATIONSTACK_BASE}/flights",
                params=params,
            )
        if response.status_code != 200:
            logger.error(
                "AviationStack /flights failed (%s): %s",
                response.status_code, response.text[:200],
            )
            return []

        data = response.json()

        # Handle API-level errors (e.g., restricted endpoint, quota exceeded)
        if "error" in data:
            logger.error("AviationStack API error: %s", data["error"])
            return []

        flights: list[dict] = data.get("data", [])
        _flight_cache[cache_key] = (flights, datetime.utcnow())
        logger.info(
            "AviationStack: %d flights fetched for %s (cached 6 h)",
            len(flights), cache_key,
        )
        return flights

    except Exception as exc:
        logger.error("AviationStack request error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Parse ISO datetime safely
# ---------------------------------------------------------------------------

def _parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        # Remove timezone offset for naive comparison
        clean = value[:19]  # "2026-04-17T18:20:00"
        return datetime.strptime(clean, "%Y-%m-%dT%H:%M:%S")
    except (ValueError, TypeError):
        return None


# ---------------------------------------------------------------------------
# Build FlightOffer objects from AviationStack /v1/flights data
# ---------------------------------------------------------------------------

def _flights_to_offers(
    raw_flights: list[dict],
    origin: str,
    destination: str,
    travel_date: datetime,
    adults: int,
    cabin_class: str,
) -> list[FlightOffer]:
    """
    Convert AviationStack flight dicts into FlightOffer objects.
    Departure/arrival times are real but shifted to the requested travel_date.
    Prices are realistic mock PKR values.
    """
    from core.config import settings as cfg

    base_prices = {
        "ECONOMY":         {"min": 8_000,  "max": 25_000},
        "PREMIUM_ECONOMY": {"min": 15_000, "max": 45_000},
        "BUSINESS":        {"min": 35_000, "max": 120_000},
        "FIRST":           {"min": 80_000, "max": 250_000},
    }
    band = base_prices.get(cabin_class, base_prices["ECONOMY"])

    offers: list[FlightOffer] = []
    seen: set[str] = set()

    for i, flight in enumerate(raw_flights[:10]):
        try:
            airline = flight.get("airline", {})
            flight_info = flight.get("flight", {})
            dep_info = flight.get("departure", {})
            arr_info = flight.get("arrival", {})

            carrier_code = (airline.get("iata") or "XX")[:2].upper()
            flight_iata = flight_info.get("iata", "")
            flight_number = flight_info.get("number", str(random.randint(100, 999)))

            # Deduplicate
            key = flight_iata or f"{carrier_code}{flight_number}"
            if key in seen:
                continue
            seen.add(key)

            # Use scheduled time; fall back to estimated or actual
            dep_raw = (
                dep_info.get("scheduled") or
                dep_info.get("estimated") or
                dep_info.get("actual")
            )
            arr_raw = (
                arr_info.get("scheduled") or
                arr_info.get("estimated") or
                arr_info.get("actual")
            )

            dep_dt_orig = _parse_iso(dep_raw)
            arr_dt_orig = _parse_iso(arr_raw)

            if dep_dt_orig is None:
                dep_dt_orig = travel_date.replace(
                    hour=random.choice([6, 8, 10, 13, 16, 19]),
                    minute=0, second=0, microsecond=0,
                )

            # Shift to travel_date while keeping time-of-day
            dep_dt = travel_date.replace(
                hour=dep_dt_orig.hour,
                minute=dep_dt_orig.minute,
                second=0, microsecond=0,
            )

            if arr_dt_orig is not None:
                arr_dt = travel_date.replace(
                    hour=arr_dt_orig.hour,
                    minute=arr_dt_orig.minute,
                    second=0, microsecond=0,
                )
                # Handle next-day arrival
                if arr_dt <= dep_dt:
                    arr_dt += timedelta(days=1)
            else:
                arr_dt = dep_dt + timedelta(hours=1, minutes=30)

            duration_mins = int((arr_dt - dep_dt).total_seconds() / 60)
            if duration_mins <= 0:
                duration_mins = 90
            h, m = divmod(duration_mins, 60)
            duration_str = f"{h}h {m}m" if m else f"{h}h"

            price_pkr = round(random.uniform(band["min"], band["max"]) * adults, 2)

            offers.append(
                FlightOffer(
                    offer_id=f"AS-{carrier_code}-{flight_number}-{i:03d}",
                    itineraries=[
                        FlightItinerary(
                            duration=duration_str,
                            segments=[
                                FlightSegment(
                                    carrier_code=carrier_code,
                                    flight_number=flight_number,
                                    departure_airport=origin.upper(),
                                    arrival_airport=destination.upper(),
                                    departure_time=dep_dt,
                                    arrival_time=arr_dt,
                                    duration=duration_str,
                                    cabin_class=cabin_class,
                                    aircraft_code="738",
                                )
                            ],
                        )
                    ],
                    total_price_pkr=price_pkr,
                    total_price_usd=round(price_pkr / cfg.USD_TO_PKR_RATE, 2),
                    currency="PKR",
                    seats_available=random.randint(3, 45),
                    is_refundable=random.choice([True, False]),
                    baggage_allowance="23kg" if cabin_class == "ECONOMY" else "32kg",
                )
            )
        except Exception as exc:
            logger.warning("Skipping flight %d: %s", i, exc)

    return offers


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def search_flights_aviationstack(
    origin: str,
    destination: str,
    date: str,
    adults: int = 1,
    cabin_class: str = "ECONOMY",
) -> list[FlightOffer]:
    """
    Search flights via AviationStack /v1/flights.
    Returns real airline/flight data with mock PKR pricing.
    Returns empty list if key not set or route has no data (caller uses mock fallback).
    """
    if not settings.AVIATIONSTACK_KEY:
        return []

    try:
        travel_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        travel_date = datetime.utcnow()

    raw_flights = await _fetch_flights(origin, destination)
    if not raw_flights:
        logger.info(
            "AviationStack: no flights for %s->%s, using mock fallback.",
            origin, destination,
        )
        return []

    offers = _flights_to_offers(
        raw_flights, origin, destination, travel_date, adults, cabin_class
    )
    logger.info(
        "AviationStack: %d offers built for %s->%s on %s",
        len(offers), origin, destination, date,
    )
    return offers
