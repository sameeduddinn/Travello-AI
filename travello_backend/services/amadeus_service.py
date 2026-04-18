# =============================================================================
# FILE: services/amadeus_service.py
# PURPOSE: Amadeus Flight Offers Search API integration.
#          Uses the free test environment (test.api.amadeus.com).
#          Converts all prices to PKR using the fixed rate in config.
#
# Amadeus free test tier limitations:
#   - Only returns results for a limited set of routes
#   - No real bookings — offer IDs are for demo/pricing only
#   - Token expires every 30 minutes (we re-fetch automatically)
# =============================================================================

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Any

import httpx

from core.config import settings
from models.flight import FlightOffer, FlightItinerary, FlightSegment

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Amadeus OAuth token cache (in-memory, per process)
# ---------------------------------------------------------------------------
_token_cache: dict[str, Any] = {
    "access_token": None,
    "expires_at": datetime.utcnow(),
}

AMADEUS_BASE = "https://test.api.amadeus.com"  # use production URL when going live


async def _get_access_token() -> str:
    """
    Fetch (or return cached) Amadeus OAuth2 access token.
    Tokens are valid for 1799 seconds (~30 min). We refresh 60s early.
    """
    now = datetime.utcnow()
    if _token_cache["access_token"] and now < _token_cache["expires_at"]:
        return _token_cache["access_token"]

    if not settings.AMADEUS_CLIENT_ID or not settings.AMADEUS_CLIENT_SECRET:
        raise ValueError(
            "AMADEUS_CLIENT_ID and AMADEUS_CLIENT_SECRET must be set in .env"
        )

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            f"{AMADEUS_BASE}/v1/security/oauth2/token",
            data={
                "grant_type": "client_credentials",
                "client_id": settings.AMADEUS_CLIENT_ID,
                "client_secret": settings.AMADEUS_CLIENT_SECRET,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

    if response.status_code != 200:
        raise RuntimeError(
            f"Amadeus auth failed ({response.status_code}): {response.text}"
        )

    data = response.json()
    expires_in: int = data.get("expires_in", 1799)

    _token_cache["access_token"] = data["access_token"]
    _token_cache["expires_at"] = now + timedelta(seconds=expires_in - 60)

    logger.info("Amadeus access token refreshed (expires in %ds)", expires_in)
    return _token_cache["access_token"]


# ---------------------------------------------------------------------------
# Price conversion helpers
# ---------------------------------------------------------------------------

def _to_pkr(amount: float, currency: str) -> float:
    """Convert amount in given currency to PKR using fixed rates from config."""
    currency = currency.upper()
    if currency == "PKR":
        return round(amount, 2)
    if currency == "USD":
        return round(amount * settings.USD_TO_PKR_RATE, 2)
    if currency == "EUR":
        return round(amount * settings.EUR_TO_PKR_RATE, 2)
    # Fallback: treat as USD
    return round(amount * settings.USD_TO_PKR_RATE, 2)


# ---------------------------------------------------------------------------
# Parse Amadeus offer into our FlightOffer model
# ---------------------------------------------------------------------------

def _parse_duration(iso_dur: str) -> str:
    """Convert PT2H30M → '2h 30m' for display."""
    iso_dur = iso_dur.replace("PT", "")
    result = ""
    if "H" in iso_dur:
        h, rest = iso_dur.split("H")
        result += f"{h}h "
        iso_dur = rest
    if "M" in iso_dur:
        m = iso_dur.replace("M", "")
        result += f"{m}m"
    return result.strip() or iso_dur


def _parse_offer(raw: dict, currency: str) -> FlightOffer:
    """Map a single Amadeus flight-offer dict to our FlightOffer model."""
    price_raw = float(raw.get("price", {}).get("grandTotal", 0))
    price_pkr = _to_pkr(price_raw, currency)
    price_usd = (
        price_raw if currency == "USD"
        else _to_pkr(price_raw, currency) / settings.USD_TO_PKR_RATE
    )

    itineraries: list[FlightItinerary] = []
    for itin in raw.get("itineraries", []):
        segments: list[FlightSegment] = []
        for seg in itin.get("segments", []):
            dep = seg.get("departure", {})
            arr = seg.get("arrival", {})
            cabin = "ECONOMY"
            try:
                cabin = (
                    raw["travelerPricings"][0]["fareDetailsBySegment"][0]
                    .get("cabin", "ECONOMY")
                )
            except (KeyError, IndexError):
                pass

            segments.append(
                FlightSegment(
                    carrier_code=seg.get("carrierCode", "XX"),
                    flight_number=seg.get("number", "0"),
                    departure_airport=dep.get("iataCode", ""),
                    arrival_airport=arr.get("iataCode", ""),
                    departure_time=datetime.fromisoformat(dep.get("at", "2024-01-01T00:00")),
                    arrival_time=datetime.fromisoformat(arr.get("at", "2024-01-01T00:00")),
                    duration=_parse_duration(seg.get("duration", "PT0H")),
                    cabin_class=cabin,
                    aircraft_code=seg.get("aircraft", {}).get("code"),
                )
            )

        itineraries.append(
            FlightItinerary(
                duration=_parse_duration(itin.get("duration", "PT0H")),
                segments=segments,
            )
        )

    # Baggage
    baggage = None
    try:
        checked = (
            raw["travelerPricings"][0]["fareDetailsBySegment"][0]
            .get("includedCheckedBags", {})
        )
        weight = checked.get("weight")
        quantity = checked.get("quantity")
        if weight:
            baggage = f"{weight}{checked.get('weightUnit','kg')}"
        elif quantity:
            baggage = f"{quantity} bag(s)"
    except (KeyError, IndexError):
        pass

    seats = raw.get("numberOfBookableSeats")

    return FlightOffer(
        offer_id=raw.get("id", ""),
        itineraries=itineraries,
        total_price_pkr=price_pkr,
        total_price_usd=round(price_usd, 2),
        currency="PKR",
        seats_available=int(seats) if seats else None,
        is_refundable=False,
        baggage_allowance=baggage,
        raw=None,  # we strip the raw payload from the API response
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def search_flights(
    origin: str,
    destination: str,
    date: str,          # "YYYY-MM-DD"
    adults: int = 1,
    cabin_class: str = "ECONOMY",
    return_date: str | None = None,
    max_results: int = 15,
) -> list[FlightOffer]:
    """
    Call Amadeus Flight Offers Search v2 and return a list of FlightOffer objects.
    Falls back to mock data if Amadeus credentials are not configured.
    """
    if not settings.AMADEUS_CLIENT_ID:
        logger.warning("Amadeus not configured — returning mock flight data.")
        return _mock_flights(origin, destination, date, adults, cabin_class)

    try:
        token = await _get_access_token()
    except (ValueError, RuntimeError) as exc:
        logger.error("Amadeus token error: %s — returning mock data.", exc)
        return _mock_flights(origin, destination, date, adults, cabin_class)

    params: dict[str, Any] = {
        "originLocationCode": origin.upper(),
        "destinationLocationCode": destination.upper(),
        "departureDate": date,
        "adults": adults,
        "travelClass": cabin_class,
        "max": max_results,
        "currencyCode": "USD",
    }
    if return_date:
        params["returnDate"] = return_date

    headers = {"Authorization": f"Bearer {token}"}

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                f"{AMADEUS_BASE}/v2/shopping/flight-offers",
                params=params,
                headers=headers,
            )
    except httpx.TimeoutException:
        logger.error("Amadeus search timed out — returning mock data.")
        return _mock_flights(origin, destination, date, adults, cabin_class)

    if response.status_code != 200:
        logger.error(
            "Amadeus search failed (%s): %s — returning mock data.",
            response.status_code, response.text[:300],
        )
        return _mock_flights(origin, destination, date, adults, cabin_class)

    data = response.json()
    raw_offers: list[dict] = data.get("data", [])
    currency: str = data.get("meta", {}).get("currency", "USD")

    offers: list[FlightOffer] = []
    for raw in raw_offers:
        try:
            offers.append(_parse_offer(raw, currency))
        except Exception as exc:
            logger.warning("Skipping malformed Amadeus offer: %s", exc)

    if not offers:
        return _mock_flights(origin, destination, date, adults, cabin_class)

    return offers


async def get_flight_offer_price(offer_id: str, raw_offer: dict) -> FlightOffer:
    """
    Call Amadeus Flight Offers Price API to confirm price for a specific offer.
    Used by GET /flights/{offer_id}.
    In test environment, we re-verify pricing before booking.
    """
    if not settings.AMADEUS_CLIENT_ID:
        raise ValueError("Amadeus not configured.")

    token = await _get_access_token()
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "data": {
            "type": "flight-offers-pricing",
            "flightOffers": [raw_offer],
        }
    }

    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.post(
            f"{AMADEUS_BASE}/v1/shopping/flight-offers/pricing",
            json=payload,
            headers=headers,
        )

    if response.status_code != 200:
        raise RuntimeError(
            f"Amadeus pricing failed ({response.status_code}): {response.text[:300]}"
        )

    data = response.json()
    raw = data.get("data", {}).get("flightOffers", [{}])[0]
    currency = data.get("data", {}).get("flightOffers", [{}])[0].get(
        "price", {}
    ).get("currency", "USD")
    return _parse_offer(raw, currency)


# ---------------------------------------------------------------------------
# Mock data (fallback when Amadeus is not configured)
# ---------------------------------------------------------------------------

def _mock_flights(
    origin: str,
    destination: str,
    date_str: str,
    adults: int,
    cabin_class: str,
) -> list[FlightOffer]:
    """
    Realistic mock flight data for Pakistani routes.
    Returned when Amadeus credentials are absent or the route has no results.
    """
    from datetime import date as dt_date, time
    import random

    try:
        travel_date = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        travel_date = datetime.utcnow()

    # Airport → city label mapping for display
    city_map = {
        "KHI": "Karachi",    "LHE": "Lahore",     "ISB": "Islamabad",
        "PEW": "Peshawar",   "MUX": "Multan",      "SKT": "Sialkot",
        "UET": "Quetta",     "LYP": "Faisalabad",
        "KDU": "Skardu",     "GIL": "Gilgit",      "BHV": "Bahawalpur",
        "SWN": "Sukkur",
        "DXB": "Dubai",      "DOH": "Doha",        "AUH": "Abu Dhabi",
        "LHR": "London",     "JFK": "New York",
    }

    airlines = [
        ("PK", "Pakistan International Airlines", "PIA"),
        ("PA", "Serene Air", "ER"),
        ("ER", "AirSial", "PF"),
        ("PF", "Airblue", "ED"),
    ]

    # Northern-area specific routes operated by PIA (KDU = Skardu real IATA code)
    northern_routes = {
        ("KHI", "KDU"), ("LHE", "KDU"), ("ISB", "KDU"),
        ("KHI", "GIL"), ("LHE", "GIL"), ("ISB", "GIL"),
        ("KDU", "KHI"), ("KDU", "LHE"), ("KDU", "ISB"),
        ("GIL", "KHI"), ("GIL", "LHE"), ("GIL", "ISB"),
    }
    is_northern = (origin.upper(), destination.upper()) in northern_routes

    base_prices = {
        "ECONOMY":         {"min": 8000, "max": 25000},
        "PREMIUM_ECONOMY": {"min": 15000, "max": 45000},
        "BUSINESS":        {"min": 35000, "max": 120000},
        "FIRST":           {"min": 80000, "max": 250000},
    }
    band = base_prices.get(cabin_class, base_prices["ECONOMY"])

    def make_offer(idx: int) -> FlightOffer:
        # Northern routes: only use PIA (index 0) for realistic coverage
        airline_idx = 0 if is_northern else idx % len(airlines)
        airline_code, airline_name, iata = airlines[airline_idx]
        # Northern routes have fewer departures — morning/afternoon only
        dep_hours_pool = [7, 10, 14] if is_northern else [6, 8, 10, 13, 16, 19, 22]
        dep_hour = random.choice(dep_hours_pool)
        dep_time = travel_date.replace(hour=dep_hour, minute=random.choice([0, 15, 30, 45]))
        flight_mins = random.randint(60, 180)
        arr_time = dep_time + timedelta(minutes=flight_mins)
        h, m = divmod(flight_mins, 60)
        dur = f"{h}h {m}m" if m else f"{h}h"
        price = round(random.uniform(band["min"], band["max"]) * adults, 2)

        return FlightOffer(
            offer_id=f"MOCK-{iata}-{idx+1:03d}",
            itineraries=[
                FlightItinerary(
                    duration=dur,
                    segments=[
                        FlightSegment(
                            carrier_code=iata,
                            flight_number=f"{random.randint(100, 999)}",
                            departure_airport=origin.upper(),
                            arrival_airport=destination.upper(),
                            departure_time=dep_time,
                            arrival_time=arr_time,
                            duration=dur,
                            cabin_class=cabin_class,
                            aircraft_code="738",
                        )
                    ],
                )
            ],
            total_price_pkr=price,
            total_price_usd=round(price / settings.USD_TO_PKR_RATE, 2),
            currency="PKR",
            seats_available=random.randint(2, 40),
            is_refundable=random.choice([True, False]),
            baggage_allowance="23kg" if cabin_class == "ECONOMY" else "32kg",
        )

    return [make_offer(i) for i in range(5)]
