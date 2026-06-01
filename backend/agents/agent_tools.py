from __future__ import annotations
# =============================================================================
# PURPOSE: Tool layer for the agentic orchestrator.
#
#   - TOOL_SCHEMAS : OpenAI/Groq function-calling schemas the LLM can call
#   - execute_tool : dispatches a tool call to the REAL service and returns a
#                    COMPACT JSON string the LLM reasons over directly.
#
# Design principle (the Tier 2 win): tools return STRUCTURED DATA, not prose.
# The orchestrator LLM writes the single final reply — no per-agent LLM
# summarisation. This kills the old double-LLM cost and preserves data fidelity
# (exact prices, flight numbers, seat counts survive into the answer).
# =============================================================================

import asyncio
import json
import logging
from datetime import date, datetime, timedelta

from services.flight_service import search_flights
from services.train_service import search_trains
from services.hotel_service import search_hotels
from services.weather_service import get_weather
from agents.clarification_agent import CITY_TO_IATA, _parse_relative_date

logger = logging.getLogger(__name__)


# ── Tool schemas (what the model sees) ────────────────────────────────────────

TOOL_SCHEMAS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "search_flights",
            "description": (
                "Search real domestic Pakistan flights for a route and date. "
                "Use when the user wants to fly or is planning a trip to a city with an airport. "
                "Northern areas like Skardu and Gilgit have airports; Hunza does not."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "origin_city": {"type": "string", "description": "Departure city, e.g. Karachi"},
                    "destination_city": {"type": "string", "description": "Arrival city, e.g. Lahore"},
                    "travel_date": {"type": "string", "description": "Departure date as YYYY-MM-DD"},
                    "passengers": {"type": "integer", "description": "Number of passengers (default 1)"},
                    "cabin_class": {
                        "type": "string",
                        "enum": ["ECONOMY", "BUSINESS", "FIRST"],
                        "description": "Cabin class (default ECONOMY)",
                    },
                },
                "required": ["origin_city", "destination_city", "travel_date"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_trains",
            "description": (
                "Search Pakistan Railways trains for a route and date. Use for intercity rail travel "
                "between major cities. Returns road/bus guidance for northern areas with no rail line."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "origin_city": {"type": "string", "description": "Departure city, e.g. Karachi"},
                    "destination_city": {"type": "string", "description": "Arrival city, e.g. Lahore"},
                    "travel_date": {"type": "string", "description": "Travel date as YYYY-MM-DD"},
                    "passengers": {"type": "integer", "description": "Number of passengers (default 1)"},
                },
                "required": ["origin_city", "destination_city", "travel_date"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_hotels",
            "description": "Search hotels in a city for given check-in/check-out dates. Use for accommodation.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City to find hotels in"},
                    "check_in": {"type": "string", "description": "Check-in date as YYYY-MM-DD"},
                    "check_out": {"type": "string", "description": "Check-out date as YYYY-MM-DD"},
                    "guests": {"type": "integer", "description": "Number of guests (default 2)"},
                    "rooms": {"type": "integer", "description": "Number of rooms (default 1)"},
                },
                "required": ["city", "check_in", "check_out"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather and any travel warnings for a city. Use before trips or when asked about weather.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City to check weather for"},
                },
                "required": ["city"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "find_healthcare",
            "description": "Find nearby hospitals and pharmacies and a short safety briefing for a city. Use for medical/safety questions.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City to find healthcare in"},
                },
                "required": ["city"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "prepare_booking",
            "description": (
                "Call this ONLY when the user has clearly chosen a specific option to book "
                "(e.g. 'book flight 2', 'reserve the Tezgam', 'book the Pearl Continental'). "
                "Fill the fields from the EXACT option shown in earlier search results — never invent "
                "a price, flight number, or train name. This shows the user a payment screen; it does "
                "NOT charge them. If you are unsure which option they mean, ask instead of calling this."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "booking_type": {"type": "string", "enum": ["flight", "train", "hotel"]},
                    "origin": {"type": "string"},
                    "destination": {"type": "string"},
                    "travel_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "departure_time": {"type": "string", "description": "HH:MM, 24h"},
                    "arrival_time": {"type": "string", "description": "HH:MM, 24h"},
                    "flight_number": {"type": "string", "description": "e.g. PK304"},
                    "train_name": {"type": "string", "description": "e.g. Tezgam Express"},
                    "airline_or_train_name": {"type": "string"},
                    "hotel_name": {"type": "string"},
                    "check_in": {"type": "string", "description": "YYYY-MM-DD"},
                    "check_out": {"type": "string", "description": "YYYY-MM-DD"},
                    "travelers": {"type": "integer"},
                    "total_price_pkr": {"type": "number"},
                    "selected_option": {"type": "string", "description": "Short human label of the chosen option"},
                },
                "required": ["booking_type"],
            },
        },
    },
]


# ── Date helper ───────────────────────────────────────────────────────────────

def _to_date(value: str | None, *, default_days: int = 7) -> date:
    """Parse a YYYY-MM-DD or relative phrase to a date; default N days out."""
    if not value:
        return date.today() + timedelta(days=default_days)
    s = str(value).strip()
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError:
        rel = _parse_relative_date(s)
        if rel:
            return datetime.strptime(rel, "%Y-%m-%d").date()
        return date.today() + timedelta(days=default_days)


# ── Compact serializers (keep tool results small & token-cheap) ───────────────

def _serialize_flights(offers: list) -> list[dict]:
    out: list[dict] = []
    for o in offers[:6]:
        if not o.itineraries or not o.itineraries[0].segments:
            continue
        seg = o.itineraries[0].segments[0]
        out.append({
            "flight_number": seg.flight_number,
            "airline_code": seg.carrier_code,
            "from": seg.departure_airport,
            "to": seg.arrival_airport,
            "depart": seg.departure_time.strftime("%Y-%m-%d %H:%M"),
            "arrive": seg.arrival_time.strftime("%H:%M"),
            "cabin": seg.cabin_class,
            "price_pkr": round(o.total_price_pkr),
            "seats_left": o.seats_available,
            "refundable": o.is_refundable,
        })
    return out


def _serialize_trains(resp) -> dict:
    if resp is None:
        return {"trains": [], "notes": "No train data found."}
    trains: list[dict] = []
    for t in (resp.trains or [])[:5]:
        classes = [
            {"class": c.class_name, "price_pkr": round(c.price_pkr), "seats_left": c.seats_available}
            for c in t.classes
        ]
        trains.append({
            "train_name": t.train_name,
            "train_number": t.train_number,
            "from": t.origin,
            "to": t.destination,
            "depart": t.departure_at.strftime("%Y-%m-%d %H:%M"),
            "arrive": t.arrival_at.strftime("%Y-%m-%d %H:%M"),
            "duration": t.duration,
            "classes": classes,
        })
    return {"trains": trains, "notes": resp.notes}


def _serialize_hotels(resp) -> list[dict]:
    out: list[dict] = []
    for h in (resp.hotels or [])[:6]:
        out.append({
            "name": h.name,
            "stars": h.star_rating,
            "area": h.address,
            "price_per_night_pkr": round(h.min_price_per_night_pkr),
            "review_score": h.review_score,
            "amenities": (h.amenities or [])[:5],
        })
    return out


# ── Executors ─────────────────────────────────────────────────────────────────

async def _exec_flights(args: dict) -> dict:
    origin = (args.get("origin_city") or "").strip()
    dest = (args.get("destination_city") or "").strip()
    o_iata = CITY_TO_IATA.get(origin.lower())
    d_iata = CITY_TO_IATA.get(dest.lower())
    if not o_iata:
        return {"error": f"No domestic airport found for '{origin}'. Ask the user for a city with an airport."}
    if not d_iata:
        return {"error": f"No domestic airport found for '{dest}'. {dest} may be reachable only by road (e.g. Hunza via Gilgit)."}
    d = _to_date(args.get("travel_date"))
    pax = int(args.get("passengers") or 1)
    cabin = (args.get("cabin_class") or "ECONOMY").upper()
    offers = await search_flights(o_iata, d_iata, d, pax, cabin_class=cabin)
    if not offers:
        return {"flights": [], "note": f"No flights found {origin}->{dest} on {d.isoformat()}."}
    return {"search_date": d.isoformat(), "passengers": pax, "flights": _serialize_flights(offers)}


async def _exec_trains(args: dict) -> dict:
    origin = (args.get("origin_city") or "").strip()
    dest = (args.get("destination_city") or "").strip()
    d = _to_date(args.get("travel_date"))
    pax = int(args.get("passengers") or 1)
    resp = await asyncio.to_thread(search_trains, origin, dest, d, pax)
    result = _serialize_trains(resp)
    result["search_date"] = d.isoformat()
    return result


async def _exec_hotels(args: dict) -> dict:
    city = (args.get("city") or "").strip()
    ci = _to_date(args.get("check_in"))
    co = _to_date(args.get("check_out"), default_days=10)
    if co <= ci:
        co = ci + timedelta(days=2)
    guests = int(args.get("guests") or 2)
    rooms = int(args.get("rooms") or 1)
    resp = await search_hotels(city, ci, co, guests, rooms)
    return {
        "city": city,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "nights": max((co - ci).days, 1),
        "hotels": _serialize_hotels(resp),
    }


async def _exec_weather(args: dict) -> dict:
    city = (args.get("city") or "").strip()
    w = await get_weather(city)
    return {"city": city, "weather": w}


async def _exec_healthcare(args: dict) -> dict:
    city = (args.get("city") or "").strip()
    # Lazy import to avoid a heavy import chain at module load.
    from agents.healthcare_agent import get_safety_briefing
    briefing = await get_safety_briefing(city)
    return {"city": city, "briefing": briefing or "No healthcare data available."}


_EXECUTORS = {
    "search_flights": _exec_flights,
    "search_trains": _exec_trains,
    "search_hotels": _exec_hotels,
    "get_weather": _exec_weather,
    "find_healthcare": _exec_healthcare,
}


async def execute_tool(name: str, args: dict) -> str:
    """
    Run a tool by name and return a compact JSON string for the model.
    Never raises — tool failures come back as {"error": ...} so the loop survives.
    Note: 'prepare_booking' is handled by the orchestrator, not here.
    """
    executor = _EXECUTORS.get(name)
    if executor is None:
        return json.dumps({"error": f"Unknown tool '{name}'."})
    try:
        result = await executor(args or {})
        return json.dumps(result, default=str)
    except Exception as exc:
        logger.warning("tool '%s' failed: %s", name, exc)
        return json.dumps({"error": f"{name} failed: {exc}"})
