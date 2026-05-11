# =============================================================================
# FILE: services/flight_service.py
# PURPOSE: Domestic flight search (Pakistan routes) with seeded mock data.
#          AviationStack supplements real domestic flights when available.
# =============================================================================

from __future__ import annotations

import logging
import random
from datetime import date, datetime, timedelta

import httpx

from core.config import settings
from models.flight import FlightItinerary, FlightOffer, FlightSegment

logger = logging.getLogger(__name__)
_TARGET_FLIGHT_RESULT_COUNT = 20

# ---------------------------------------------------------------------------
# Pakistan IATA codes
# ---------------------------------------------------------------------------

PAKISTAN_IATA_CODES: set[str] = {
    "KHI", "LHE", "ISB", "SKD", "GIL", "PEW",
    "MUX", "UET", "LYP", "SKT", "BHV", "SWN", "RWP",
}

IATA_CITIES: dict[str, str] = {
    "KHI": "Karachi",    "LHE": "Lahore",      "ISB": "Islamabad",
    "SKD": "Skardu",     "GIL": "Gilgit",      "PEW": "Peshawar",
    "MUX": "Multan",     "UET": "Quetta",       "LYP": "Faisalabad",
    "SKT": "Sialkot",    "BHV": "Bahawalpur",   "SWN": "Sukkur",
    "RWP": "Rawalpindi", "ATK": "Attock",
    "DXB": "Dubai",      "DOH": "Doha",         "AUH": "Abu Dhabi",
    "LHR": "London",     "JFK": "New York",     "YYZ": "Toronto",
    "BKK": "Bangkok",    "KUL": "Kuala Lumpur", "SIN": "Singapore",
}

# ---------------------------------------------------------------------------
# Domestic route catalogue
# ---------------------------------------------------------------------------

PAKISTAN_ROUTES: dict[str, dict] = {
    "KHI-LHE": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
            {"code": "ER", "name": "AirSial", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 85, "price_min_pkr": 8000, "price_max_pkr": 22000,
        "departure_times": ["06:00", "09:30", "13:00", "17:30", "21:00"],
    },
    "KHI-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 110, "price_min_pkr": 10000, "price_max_pkr": 28000,
        "departure_times": ["07:00", "11:00", "15:00", "19:30"],
    },
    "KHI-SKD": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 150, "price_min_pkr": 18000, "price_max_pkr": 45000,
        "departure_times": ["08:00", "14:00"],
    },
    "KHI-GIL": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 160, "price_min_pkr": 20000, "price_max_pkr": 48000,
        "departure_times": ["07:30", "13:30"],
    },
    "KHI-PEW": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 115, "price_min_pkr": 11000, "price_max_pkr": 30000,
        "departure_times": ["06:30", "10:00", "14:30", "18:00"],
    },
    "KHI-MUX": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 70, "price_min_pkr": 7000, "price_max_pkr": 18000,
        "departure_times": ["09:00", "15:00"],
    },
    "LHE-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
            {"code": "ER", "name": "AirSial", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 55, "price_min_pkr": 6000, "price_max_pkr": 16000,
        "departure_times": ["07:00", "10:30", "14:00", "18:30", "21:30"],
    },
    "LHE-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
            {"code": "ER", "name": "AirSial", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 85, "price_min_pkr": 8000, "price_max_pkr": 22000,
        "departure_times": ["06:00", "09:30", "13:00", "17:30", "21:00"],
    },
    "LHE-SKD": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 130, "price_min_pkr": 16000, "price_max_pkr": 40000,
        "departure_times": ["08:30", "14:30"],
    },
    "LHE-GIL": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 140, "price_min_pkr": 17000, "price_max_pkr": 42000,
        "departure_times": ["09:00", "15:00"],
    },
    "LHE-PEW": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
        ],
        "duration_minutes": 60, "price_min_pkr": 6500, "price_max_pkr": 17000,
        "departure_times": ["08:00", "12:00", "16:30"],
    },
    "ISB-SKD": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 75, "price_min_pkr": 12000, "price_max_pkr": 32000,
        "departure_times": ["07:00", "11:00", "15:00"],
    },
    "ISB-GIL": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 60, "price_min_pkr": 10000, "price_max_pkr": 28000,
        "departure_times": ["07:30", "11:30", "15:30"],
    },
    "ISB-PEW": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 40, "price_min_pkr": 5000, "price_max_pkr": 14000,
        "departure_times": ["06:00", "09:00", "13:00", "17:00", "20:00"],
    },
    "ISB-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 110, "price_min_pkr": 10000, "price_max_pkr": 28000,
        "departure_times": ["07:00", "11:00", "15:00", "19:30"],
    },
    "ISB-LHE": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
            {"code": "ER", "name": "AirSial", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 55, "price_min_pkr": 6000, "price_max_pkr": 16000,
        "departure_times": ["07:00", "10:30", "14:00", "18:30", "21:30"],
    },
    "PEW-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
        ],
        "duration_minutes": 115, "price_min_pkr": 11000, "price_max_pkr": 30000,
        "departure_times": ["07:00", "11:30", "16:00"],
    },
    "PEW-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "Boeing 737"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 40, "price_min_pkr": 5000, "price_max_pkr": 14000,
        "departure_times": ["06:00", "09:00", "13:00", "17:00", "20:00"],
    },
    "MUX-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 70, "price_min_pkr": 7000, "price_max_pkr": 18000,
        "departure_times": ["08:00", "14:00", "18:00"],
    },
    "MUX-LHE": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 55, "price_min_pkr": 6000, "price_max_pkr": 15000,
        "departure_times": ["09:00", "15:00"],
    },
    "SKD-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 75, "price_min_pkr": 12000, "price_max_pkr": 32000,
        "departure_times": ["10:00", "16:00"],
    },
    "GIL-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 60, "price_min_pkr": 10000, "price_max_pkr": 28000,
        "departure_times": ["10:30", "16:30"],
    },
    "UET-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 90, "price_min_pkr": 9000, "price_max_pkr": 24000,
        "departure_times": ["09:00", "15:00"],
    },
    "LYP-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 95, "price_min_pkr": 9500, "price_max_pkr": 25000,
        "departure_times": ["08:30", "14:30"],
    },
    "SKT-LHE": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 42"},
        ],
        "duration_minutes": 30, "price_min_pkr": 4000, "price_max_pkr": 10000,
        "departure_times": ["08:00", "14:00", "18:00"],
    },
    "LHE-UET": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 120, "price_min_pkr": 12000, "price_max_pkr": 32000,
        "departure_times": ["08:00", "14:00"],
    },
    "UET-LHE": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 120, "price_min_pkr": 12000, "price_max_pkr": 32000,
        "departure_times": ["09:00", "15:00"],
    },
    "ISB-UET": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 90, "price_min_pkr": 10000, "price_max_pkr": 28000,
        "departure_times": ["07:30", "13:30"],
    },
    "UET-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 90, "price_min_pkr": 10000, "price_max_pkr": 28000,
        "departure_times": ["09:00", "15:00"],
    },
    "ISB-MUX": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 55, "price_min_pkr": 6000, "price_max_pkr": 16000,
        "departure_times": ["08:00", "12:00", "17:00"],
    },
    "MUX-ISB": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
            {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        ],
        "duration_minutes": 55, "price_min_pkr": 6000, "price_max_pkr": 16000,
        "departure_times": ["09:30", "14:00", "19:00"],
    },
    "KHI-SWN": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 60, "price_min_pkr": 6500, "price_max_pkr": 17000,
        "departure_times": ["08:30", "14:30"],
    },
    "SWN-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 60, "price_min_pkr": 6500, "price_max_pkr": 17000,
        "departure_times": ["10:00", "16:00"],
    },
    "KHI-BHV": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 75, "price_min_pkr": 7500, "price_max_pkr": 20000,
        "departure_times": ["09:00", "15:00"],
    },
    "BHV-KHI": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        ],
        "duration_minutes": 75, "price_min_pkr": 7500, "price_max_pkr": 20000,
        "departure_times": ["10:30", "16:30"],
    },
    "LHE-LYP": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 42"},
        ],
        "duration_minutes": 30, "price_min_pkr": 4000, "price_max_pkr": 10000,
        "departure_times": ["08:30", "13:00", "17:30"],
    },
    "LYP-LHE": {
        "airlines": [
            {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 42"},
        ],
        "duration_minutes": 30, "price_min_pkr": 4000, "price_max_pkr": 10000,
        "departure_times": ["09:30", "14:00", "18:30"],
    },
}


# ---------------------------------------------------------------------------
# Cabin class configuration
# ---------------------------------------------------------------------------

_CABIN_CONFIG: dict[str, dict] = {
    "ECONOMY":         {"multiplier": 1.0,  "baggage": "23kg", "refundable": False},
    "PREMIUM_ECONOMY": {"multiplier": 1.6,  "baggage": "30kg", "refundable": True},
    "BUSINESS":        {"multiplier": 2.8,  "baggage": "40kg", "refundable": True},
    "FIRST":           {"multiplier": 4.5,  "baggage": "50kg", "refundable": True},
}

def _cabin_cfg(cabin_class: str) -> dict:
    return _CABIN_CONFIG.get(cabin_class.upper(), _CABIN_CONFIG["ECONOMY"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _duration_str(minutes: int) -> str:
    h, m = divmod(minutes, 60)
    return f"PT{h}H{m}M" if m else f"PT{h}H"


def _seeded_int(seed: int, lo: int, hi: int) -> int:
    return random.Random(seed).randint(lo, hi)




def _flight_offer_key(offer: FlightOffer) -> tuple[str, str, str, str, str]:
    """Build a stable merge key from the first segment of the first itinerary."""
    if not offer.itineraries or not offer.itineraries[0].segments:
        return (offer.offer_id, "", "", "", "")

    seg = offer.itineraries[0].segments[0]
    dep_time = seg.departure_time.isoformat()
    return (
        seg.carrier_code,
        seg.flight_number,
        seg.departure_airport,
        seg.arrival_airport,
        dep_time,
    )


def _merge_flight_offers(
    base: list[FlightOffer],
    incoming: list[FlightOffer],
    *,
    limit: int,
) -> list[FlightOffer]:
    """Merge offers without duplicates while preserving source priority order."""
    merged = list(base)
    seen = {_flight_offer_key(offer) for offer in merged}

    for offer in incoming:
        key = _flight_offer_key(offer)
        if key in seen:
            continue
        merged.append(offer)
        seen.add(key)
        if len(merged) >= limit:
            break

    return merged


def _sort_flight_offers(offers: list[FlightOffer]) -> list[FlightOffer]:
    def _first_departure(offer: FlightOffer) -> datetime:
        if offer.itineraries and offer.itineraries[0].segments:
            return offer.itineraries[0].segments[0].departure_time
        return datetime.min

    return sorted(offers, key=lambda o: (_first_departure(o), o.total_price_pkr))


# ---------------------------------------------------------------------------
# Domestic offer generation
# ---------------------------------------------------------------------------

def _generate_domestic_offers(
    origin: str,
    destination: str,
    travel_date: date,
    adults: int,
    cabin_class: str = "ECONOMY",
) -> list[FlightOffer]:
    """Return deterministic mock offers for a domestic Pakistan route."""
    route_key = f"{origin}-{destination}"
    date_str = travel_date.strftime("%Y%m%d")
    cabin = cabin_class.upper()
    cfg = _cabin_cfg(cabin)

    route = PAKISTAN_ROUTES.get(route_key)
    reverse = False
    if route is None:
        route = PAKISTAN_ROUTES.get(f"{destination}-{origin}")
        reverse = True

    if route is None:
        return []

    duration_min = route["duration_minutes"]
    dep_times = route["departure_times"]

    # Reverse direction: shift all departure times +1 hour
    if reverse:
        def _shift(t: str) -> str:
            h, m = map(int, t.split(":"))
            return f"{(h + 1) % 24:02d}:{m:02d}"
        dep_times = [_shift(t) for t in dep_times]

    offers: list[FlightOffer] = []
    for airline in route["airlines"]:
        for dep_time in dep_times:
            seed = hash(f"{origin}{destination}{date_str}{airline['code']}{dep_time}{cabin}") % (2**31)
            base_price = _seeded_int(seed, route["price_min_pkr"], route["price_max_pkr"])
            price      = round(base_price * cfg["multiplier"])
            seats      = _seeded_int(seed ^ 0xABCD, 4, 30) if cabin != "ECONOMY" else _seeded_int(seed ^ 0xABCD, 8, 52)
            flt_num    = f"{airline['code']}{_seeded_int(seed ^ 0x1234, 100, 999)}"

            h, m = map(int, dep_time.split(":"))
            dep_dt = datetime(travel_date.year, travel_date.month, travel_date.day, h, m)
            arr_dt = dep_dt + timedelta(minutes=duration_min)

            offer_id = (
                f"PK-{origin}-{destination}-{airline['code']}"
                f"-{dep_time.replace(':', '')}-{date_str}-{cabin}"
            )

            segment = FlightSegment(
                carrier_code=airline["code"],
                flight_number=flt_num,
                departure_airport=origin,
                arrival_airport=destination,
                departure_time=dep_dt,
                arrival_time=arr_dt,
                duration=_duration_str(duration_min),
                cabin_class=cabin,
                aircraft_code=airline.get("aircraft"),
            )
            offers.append(
                FlightOffer(
                    offer_id=offer_id,
                    itineraries=[FlightItinerary(
                        duration=_duration_str(duration_min),
                        segments=[segment],
                    )],
                    total_price_pkr=float(price * adults),
                    total_price_usd=round(price * adults / settings.USD_TO_PKR_RATE, 2),
                    seats_available=seats,
                    is_refundable=cfg["refundable"],
                    baggage_allowance=cfg["baggage"],
                )
            )
    return offers


def _generate_domestic_generic_mock(
    origin: str,
    destination: str,
    travel_date: date,
    adults: int,
    cabin_class: str = "ECONOMY",
) -> list[FlightOffer]:
    """Generate domestic backup offers for unseeded Pakistan routes."""
    date_str = travel_date.strftime("%Y%m%d")
    cabin = cabin_class.upper()
    cfg = _cabin_cfg(cabin)
    carriers = [
        {"code": "PK", "name": "Pakistan International Airlines", "aircraft": "ATR 72"},
        {"code": "PA", "name": "Airblue", "aircraft": "Airbus A320"},
        {"code": "ER", "name": "AirSial", "aircraft": "Airbus A320"},
    ]
    departure_slots = ["07:00", "11:00", "15:00", "19:00"]

    offers: list[FlightOffer] = []
    for idx, carrier in enumerate(carriers):
        dep_time = departure_slots[idx % len(departure_slots)]
        seed = hash(f"DOM-{origin}-{destination}-{date_str}-{carrier['code']}-{dep_time}-{cabin}") % (2**31)
        rng = random.Random(seed)
        duration_min = rng.randint(50, 140)
        base_price = round(rng.randint(6000, 22000) * cfg["multiplier"])
        seats = rng.randint(4, 20) if cabin != "ECONOMY" else rng.randint(6, 55)
        flight_number = f"{carrier['code']}{rng.randint(100, 999)}"

        h, m = map(int, dep_time.split(":"))
        dep_dt = datetime(travel_date.year, travel_date.month, travel_date.day, h, m)
        arr_dt = dep_dt + timedelta(minutes=duration_min)

        segment = FlightSegment(
            carrier_code=carrier["code"],
            flight_number=flight_number,
            departure_airport=origin,
            arrival_airport=destination,
            departure_time=dep_dt,
            arrival_time=arr_dt,
            duration=_duration_str(duration_min),
            cabin_class=cabin,
            aircraft_code=carrier["aircraft"],
        )

        offers.append(
            FlightOffer(
                offer_id=f"DOM-{origin}-{destination}-{carrier['code']}-{dep_time.replace(':', '')}-{date_str}-{cabin}",
                itineraries=[FlightItinerary(
                    duration=_duration_str(duration_min),
                    segments=[segment],
                )],
                total_price_pkr=float(base_price * adults),
                total_price_usd=round(base_price * adults / settings.USD_TO_PKR_RATE, 2),
                seats_available=seats,
                is_refundable=cfg["refundable"],
                baggage_allowance=cfg["baggage"],
            )
        )

    return offers




# ---------------------------------------------------------------------------
# AviationStack (domestic supplement)
# ---------------------------------------------------------------------------

def _aviationstack_is_configured() -> bool:
    key = (settings.AVIATIONSTACK_KEY or "").strip()
    if not key:
        return False
    lowered = key.lower()
    return "your_aviationstack_key" not in lowered and not key.startswith("REPLACE_WITH")


async def _fetch_aviationstack(
    origin: str, destination: str, travel_date: date, cabin_class: str = "ECONOMY"
) -> list[FlightOffer]:
    """Call AviationStack /v1/flights for real-time domestic flight data.
    Free plan supports real-time flights only — no flight_date param (paid feature).
    Only called when travel_date is today so results are relevant.
    """
    if not _aviationstack_is_configured():
        return []

    # Free plan = real-time only; skip for future dates
    if travel_date != date.today():
        logger.info("AviationStack skipped: free plan only supports today's real-time flights")
        return []

    _requested_cabin = cabin_class.upper()
    cfg = _cabin_cfg(_requested_cabin)

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                "http://api.aviationstack.com/v1/flights",
                params={
                    "access_key": settings.AVIATIONSTACK_KEY,
                    "dep_iata": origin,
                    "arr_iata": destination,
                    # No flight_date — free plan restriction (paid feature only)
                },
            )
        if resp.status_code != 200:
            logger.warning("AviationStack %s: %s", resp.status_code, resp.text[:200])
            return []

        flights = resp.json().get("data", [])
        offers: list[FlightOffer] = []

        for f in flights[:10]:
            dep_info = f.get("departure", {})
            arr_info = f.get("arrival", {})
            airline_info = f.get("airline", {})
            flight_info = f.get("flight", {})

            dep_str = dep_info.get("scheduled", "")
            arr_str = arr_info.get("scheduled", "")
            if not dep_str or not arr_str:
                continue

            try:
                dep_dt = datetime.fromisoformat(dep_str.replace("Z", "+00:00")).replace(tzinfo=None)
                arr_dt = datetime.fromisoformat(arr_str.replace("Z", "+00:00")).replace(tzinfo=None)
            except ValueError:
                continue

            dur_min = max(int((arr_dt - dep_dt).total_seconds() / 60), 30)
            base_price = round(random.uniform(15000, 50000))
            price_pkr = round(base_price * cfg["multiplier"])

            segment = FlightSegment(
                carrier_code=airline_info.get("iata", "XX"),
                flight_number=flight_info.get("iata", "XX000"),
                departure_airport=dep_info.get("iata", origin),
                arrival_airport=arr_info.get("iata", destination),
                departure_time=dep_dt,
                arrival_time=arr_dt,
                duration=_duration_str(dur_min),
                cabin_class=_requested_cabin,
            )
            offers.append(
                FlightOffer(
                    offer_id=f"AS-{origin}-{destination}-{flight_info.get('iata', 'XX000')}-{travel_date}-{_requested_cabin}",
                    itineraries=[FlightItinerary(
                        duration=_duration_str(dur_min),
                        segments=[segment],
                    )],
                    total_price_pkr=float(price_pkr),
                    total_price_usd=round(price_pkr / settings.USD_TO_PKR_RATE, 2),
                    seats_available=random.randint(4, 20) if _requested_cabin != "ECONOMY" else random.randint(5, 80),
                    is_refundable=cfg["refundable"],
                    baggage_allowance=cfg["baggage"],
                )
            )
        return offers

    except Exception as exc:
        logger.error("AviationStack error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def search_flights(
    origin: str,
    destination: str,
    date: date,
    adults: int = 1,
    cabin_class: str = "ECONOMY",
    return_date: date | None = None,
) -> list[FlightOffer]:
    """
    Search for available flights.
    Merge strategy for robust coverage:
    - Domestic routes: seeded domestic mock -> AviationStack supplement -> domestic generic backup.
    - International routes: AviationStack primary -> international mock supplement.
    This ensures partial responses from one source are completed by the others.
    """
    origin = origin.upper()
    destination = destination.upper()

    offers: list[FlightOffer] = []
    is_domestic = origin in PAKISTAN_IATA_CODES and destination in PAKISTAN_IATA_CODES

    if is_domestic:
        domestic_seeded = _generate_domestic_offers(origin, destination, date, adults, cabin_class=cabin_class)
        offers = _merge_flight_offers(offers, domestic_seeded, limit=_TARGET_FLIGHT_RESULT_COUNT)

        aviationstack_count = 0
        if len(offers) < _TARGET_FLIGHT_RESULT_COUNT:
            aviationstack_offers = await _fetch_aviationstack(origin, destination, date, cabin_class=cabin_class)
            aviationstack_count = len(aviationstack_offers)
            offers = _merge_flight_offers(offers, aviationstack_offers, limit=_TARGET_FLIGHT_RESULT_COUNT)

        domestic_generic_count = 0
        if len(offers) < _TARGET_FLIGHT_RESULT_COUNT:
            domestic_generic = _generate_domestic_generic_mock(origin, destination, date, adults, cabin_class=cabin_class)
            domestic_generic_count = len(domestic_generic)
            offers = _merge_flight_offers(offers, domestic_generic, limit=_TARGET_FLIGHT_RESULT_COUNT)

        final_offers = _sort_flight_offers(offers)
        logger.info(
            "Flight search merged (domestic) %s->%s: seeded=%d, aviationstack=%d, generic=%d, final=%d",
            origin,
            destination,
            len(domestic_seeded),
            aviationstack_count,
            domestic_generic_count,
            len(final_offers),
        )
        return final_offers

    # Non-domestic route — return empty (app supports domestic Pakistan routes only)
    logger.info("Flight search skipped (non-domestic) %s->%s", origin, destination)
    return []
