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
import re
from datetime import date, datetime, timedelta

from core.pk_time import pk_now, pk_today

from services.flight_service import search_flights
from services.train_service import search_trains
from services.hotel_service import search_hotels, CITY_ALIASES
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
                    "max_budget_pkr": {
                        "type": "number",
                        "description": (
                            "Only set this if the user gave a specific PKR ceiling for this "
                            "fare (e.g. 'under 20000'). Results are filtered to that price and "
                            "sorted cheapest first. Omit entirely if no number was given."
                        ),
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
                    "max_budget_pkr": {
                        "type": "number",
                        "description": (
                            "Only set this if the user gave a specific PKR ceiling for this fare "
                            "class. Classes over budget are dropped and results sorted cheapest "
                            "first. Omit entirely if no number was given."
                        ),
                    },
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
                    # NOT "(default 2)". That wording read as permission to fill in 2
                    # and move on — which is what happened, for a user whose saved
                    # profile said solo. Searching with 2 is harmless, but the model
                    # then carries that 2 into prepare_booking, where it lands on the
                    # summary card and in the hotel record as the party size.
                    "guests": {
                        "type": "integer",
                        "description": (
                            "Number of guests staying. Pass a number the user actually "
                            "gave you; if they haven't said, omit it rather than assuming "
                            "a party size — and ask them before booking."
                        ),
                    },
                    "rooms": {"type": "integer", "description": "Number of rooms (default 1)"},
                    "max_budget_pkr": {
                        "type": "number",
                        "description": (
                            "Only set this if the user gave a specific PKR ceiling for the "
                            "per-night rate. Results are filtered to that price and sorted "
                            "cheapest first. Omit entirely if no number was given."
                        ),
                    },
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
            "name": "book_car",
            "description": (
                "Book a standalone car with a driver for a ride WITHIN a city — the "
                "Car-tab equivalent. This is NOT the airport/station transfer that's "
                "offered while booking a flight or train (that one rides along on "
                "prepare_booking); use book_car only when the user wants a car on its "
                "own. Call it ONLY after the user has clearly asked to book a car AND "
                "you have all four details: pickup address, drop-off address, vehicle "
                "type, and pickup date/time. It does NOT charge a card and does NOT "
                "finalise anything by itself — the app opens a confirmation step where "
                "the user taps to confirm, and the driver is assigned only then. Never "
                "invent or promise a driver name, car, or verification code — those come "
                "back only after the real booking."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "pickup_location": {
                        "type": "string",
                        "description": "Full pickup address within the city.",
                    },
                    "dropoff_location": {
                        "type": "string",
                        "description": "Full drop-off address within the city.",
                    },
                    "vehicle_type": {
                        "type": "string",
                        "enum": ["Sedan", "SUV", "Van"],
                        "description": "Sedan PKR 800 (1-3 pax), SUV PKR 1,200 (1-5 pax), Van PKR 1,500 (6-9 pax).",
                    },
                    "pickup_datetime": {
                        "type": "string",
                        "description": (
                            "Pickup date and time as ISO 8601 (YYYY-MM-DDTHH:MM). Resolve "
                            "relative phrases like 'tomorrow at 3pm' yourself from today's "
                            "date before calling. Must be in the future."
                        ),
                    },
                },
                "required": ["pickup_location", "dropoff_location", "vehicle_type", "pickup_datetime"],
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
                    "cabin_class": {
                        "type": "string",
                        "enum": ["ECONOMY", "BUSINESS", "FIRST"],
                        "description": "Cabin class of the chosen flight (default ECONOMY)",
                    },
                    "train_name": {"type": "string", "description": "e.g. Tezgam Express"},
                    "train_class": {
                        "type": "string",
                        "description": (
                            "The exact fare class the user picked for this train, as shown in the "
                            "search results (e.g. 'AC Business', 'AC Standard', 'Economy'). Required "
                            "for trains — each class has a different price."
                        ),
                    },
                    "airline_or_train_name": {"type": "string"},
                    "hotel_name": {"type": "string"},
                    "check_in": {"type": "string", "description": "YYYY-MM-DD"},
                    "check_out": {"type": "string", "description": "YYYY-MM-DD"},
                    "rooms": {
                        "type": "integer",
                        "description": "Number of hotel rooms (1-5). Required for hotels — ask if unclear.",
                    },
                    "guests": {
                        "type": "integer",
                        "description": "Total hotel guests (1-10). Required for hotels — ask if unclear.",
                    },
                    "room_type": {
                        "type": "string",
                        "description": (
                            "Room type if the user stated a preference (e.g. 'Deluxe Room'). "
                            "Omit if not discussed — a Standard Room is used by default."
                        ),
                    },
                    "adults": {
                        "type": "integer",
                        "description": (
                            "Number of adult travelers (12+). Required for flights and trains. "
                            "If the user is clearly booking just for themselves, use 1 — otherwise ask."
                        ),
                    },
                    "children": {
                        "type": "integer",
                        "description": "Number of children (2-11). Default 0 if not mentioned.",
                    },
                    "infants": {
                        "type": "integer",
                        "description": "Number of infants (under 2). Default 0 if not mentioned.",
                    },
                    "travelers": {
                        "type": "integer",
                        "description": (
                            "Legacy total traveler count — the server recomputes this from "
                            "adults + children + infants; you do not need to set it."
                        ),
                    },
                    "transfer_vehicle_type": {
                        "type": "string",
                        "enum": ["Sedan", "SUV", "Van"],
                        "description": (
                            "Only if the user accepted an airport/station car transfer: "
                            "Sedan PKR 800 (1-3 pax), SUV PKR 1,200 (1-5 pax), Van PKR 1,500 (6-9 pax)."
                        ),
                    },
                    "transfer_pickup_location": {
                        "type": "string",
                        "description": "Pickup address for the car transfer, if one was accepted.",
                    },
                    "total_price_pkr": {
                        "type": "number",
                        "description": (
                            "Your best estimate of the price from the earlier search results, as a "
                            "PLAIN number (e.g. 46784) — never an arithmetic expression like 5848*8. "
                            "This is advisory only — the server always re-derives the authoritative "
                            "price from live search data before showing the payment screen."
                        ),
                    },
                    "selected_option": {"type": "string", "description": "Short human label of the chosen option"},
                    "next_step": {
                        "type": "string",
                        "description": (
                            "ONLY when this booking is one piece of a multi-part trip the user "
                            "asked for (e.g. they wanted flight + hotel + car): one short, plain "
                            "sentence naming what still remains, e.g. 'your hotel in Islamabad, "
                            "22-30 July, then the airport car'. It is shown to the user after "
                            "this booking so the trip can continue. Purely descriptive — never "
                            "put a price, PNR, booking reference or confirmation wording in it, "
                            "and omit it entirely for a single standalone booking."
                        ),
                    },
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
        return pk_today() + timedelta(days=default_days)
    s = str(value).strip()
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError:
        rel = _parse_relative_date(s)
        if rel:
            return datetime.strptime(rel, "%Y-%m-%d").date()
        return pk_today() + timedelta(days=default_days)


# ── Date-sanity gate: deterministic rejection of past dates ────────────────────
#
# Same principle as the booking-required-fields gate below: the model's own
# judgment about whether a date makes sense is never trusted. A travel_date,
# check_in, or check_out that resolves to before today is rejected in code,
# before any search or prepare_booking call executes — hard rejection, no
# silent roll-forward to a "corrected" date the user didn't ask for.

def _parse_date_strict(value: str | None) -> date | None:
    """
    Parse a YYYY-MM-DD string or a resolvable relative phrase ("today",
    "tomorrow") to a date. Unlike _to_date, this never defaults — an empty or
    unparseable value returns None, so the past-date gate can tell "not a real
    date" (a different, pre-existing concern handled elsewhere) apart from
    "a real date that has already passed" (what this gate checks for).
    """
    if not value:
        return None
    s = str(value).strip()
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError:
        rel = _parse_relative_date(s)
        if rel:
            try:
                return datetime.strptime(rel, "%Y-%m-%d").date()
            except ValueError:
                return None
        return None


_DATE_FIELD_LABELS: dict[str, str] = {
    "travel_date": "travel date",
    "check_in": "check-in date",
    "check_out": "check-out date",
}


def _past_date_result(field: str, parsed: date, today: date) -> dict:
    label = _DATE_FIELD_LABELS.get(field, field)
    return {
        "error": "past_date",
        "field": field,
        "provided_date": parsed.isoformat(),
        "today": today.isoformat(),
        "instruction": (
            f"The {label} ({parsed.isoformat()}) is before today ({today.isoformat()}) "
            "— it has already passed. Do NOT search or book with this date, and do NOT "
            "silently substitute a different date yourself. Tell the user plainly that "
            "date has passed and ask them for a corrected, current-or-future date."
        ),
    }


def find_past_date_error(args: dict, date_fields: list[str], *, today: date | None = None) -> dict | None:
    """
    Check each field name in date_fields on args; if any resolves to a date
    strictly before today, return a structured past_date error to feed back to
    the model instead of running the search/booking. Returns None if every
    resolvable date is today or later. Missing or unparseable values are NOT
    flagged here — that's a different, pre-existing concern (clarification /
    _to_date's default-N-days-out fallback), not what this gate is for.
    """
    ref_today = today or pk_today()
    for field in date_fields:
        parsed = _parse_date_strict((args or {}).get(field))
        if parsed is not None and parsed < ref_today:
            return _past_date_result(field, parsed, ref_today)
    return None


def find_missing_date_error(args: dict, date_fields: list[str]) -> dict | None:
    """
    Reject a search when a REQUIRED date is absent or unparseable — e.g. the model
    passed "unknown", "" or omitted it. Without this, _to_date silently substitutes
    a date N days out and the user is shown (and could book) a stay on dates they
    never chose. Returns a structured error telling the model to ASK, else None.

    A relative phrase the model should resolve ("next Friday", "this weekend") still
    counts as usable — the search executors resolve it the same way via _to_date.
    """
    for field in date_fields:
        raw = (args or {}).get(field)
        if _parse_date_strict(raw) is None and not _parse_relative_date(str(raw or "").strip()):
            label = _DATE_FIELD_LABELS.get(field, field)
            return {
                "error": "missing_date",
                "field": field,
                "instruction": (
                    f"No usable {label} was provided (got {raw!r}). Do NOT search with a "
                    f"guessed or default date and do NOT invent one — ask the user for their "
                    f"{label} (and any other dates still missing) before searching."
                ),
            }
    return None


_TOOL_DATE_FIELDS: dict[str, list[str]] = {
    "search_flights": ["travel_date"],
    "search_trains": ["travel_date"],
    "search_hotels": ["check_in", "check_out"],
}

_BOOKING_DATE_FIELDS: dict[str, list[str]] = {
    "flight": ["travel_date"],
    "train": ["travel_date"],
    "hotel": ["check_in", "check_out"],
}


def get_booking_date_error(booking_data: dict) -> dict | None:
    """
    Deterministic date-sanity gate for prepare_booking — same role as
    get_missing_booking_fields, but for date validity instead of field
    completeness. Returns a structured past_date error if travel_date /
    check_in / check_out resolves to before today, else None. The caller must
    treat a non-None result as a hard stop: do not proceed to reprice_booking
    or a payment screen.
    """
    booking_type = str((booking_data or {}).get("booking_type") or "")
    date_fields = _BOOKING_DATE_FIELDS.get(booking_type, [])
    return find_past_date_error(booking_data or {}, date_fields)


# ── Standalone car booking (book_car) — deterministic gate ────────────────────
#
# book_car mirrors the manual Car-tab flow (POST /cars/book → book_standalone_car):
# a within-city ride, instant on the user's confirm tap, no payment. Like
# prepare_booking, the model NEVER commits it directly — the tool call only
# prepares a car_booking_choice the app confirms. This gate is the code-level
# source of truth for "is this car request bookable", so a half-specified or
# past-dated ride can never reach the confirm screen.

_CAR_VEHICLES = ("Sedan", "SUV", "Van")

# Mirrors services.car_service._VEHICLE_PRICES. Display-only here — the real
# charge is re-derived server-side by book_standalone_car when the app confirms,
# so this can't desync the actual booked amount even if it drifted.
_CAR_VEHICLE_PRICES: dict[str, int] = {"Sedan": 800, "SUV": 1200, "Van": 1500}

_CAR_REQUIRED_FIELDS = ["pickup_location", "dropoff_location", "vehicle_type", "pickup_datetime"]

_CAR_FIELD_LABELS = {
    "pickup_location": "pickup address",
    "dropoff_location": "drop-off address",
    "vehicle_type": "vehicle type (Sedan, SUV or Van)",
    "pickup_datetime": "pickup date and time",
}


def _parse_datetime_strict(value: str | None) -> datetime | None:
    """
    Parse an ISO-8601 datetime (or a bare date / relative day) to a naive
    datetime. Never defaults on failure — returns None so the gate can tell
    "unparseable" apart from "valid but in the past". A bare date resolves to
    that day at 00:00; timezone offsets are dropped (wall-clock comparison).
    """
    if not value:
        return None
    s = str(value).strip()
    if not s:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).replace(tzinfo=None)
    except ValueError:
        pass
    d = _parse_date_strict(s)   # bare date or relative day ("tomorrow")
    if d is not None:
        return datetime(d.year, d.month, d.day)
    return None


def get_car_booking_error(args: dict, *, now: datetime | None = None) -> dict | None:
    """
    Deterministic gate for book_car — the car equivalent of
    get_missing_booking_fields + the date-sanity gate. Returns the FIRST
    structured problem (missing field, invalid vehicle type, unparseable or
    past pickup time) or None when all four fields are present and valid. A
    non-None result is a hard stop: the caller must feed it back to the model
    to ask/correct, never open a confirm screen.
    """
    a = args or {}

    missing = [f for f in _CAR_REQUIRED_FIELDS if not str(a.get(f) or "").strip()]
    if missing:
        labels = ", ".join(_CAR_FIELD_LABELS[f] for f in missing)
        return {
            "error": "missing_required_fields",
            "missing": missing,
            "instruction": (
                f"Before booking a car you still need: {labels}. Ask the user for exactly "
                "these in one short question — do not call book_car again until you have "
                "all four, and never guess them."
            ),
        }

    vehicle = str(a.get("vehicle_type") or "").strip()
    if vehicle not in _CAR_VEHICLES:
        return {
            "error": "invalid_vehicle_type",
            "instruction": (
                f"'{vehicle}' isn't a bookable vehicle. Offer only Sedan (PKR 800), SUV "
                "(PKR 1,200) or Van (PKR 1,500) and ask which one they'd like. Do not call "
                "book_car again until the user picks one of these three."
            ),
        }

    parsed = _parse_datetime_strict(a.get("pickup_datetime"))
    if parsed is None:
        return {
            "error": "invalid_pickup_datetime",
            "instruction": (
                "The pickup date/time couldn't be understood. Ask the user for a clear "
                "pickup date and time (e.g. 'tomorrow at 3 PM', or a specific date and "
                "time). Do not call book_car again until you have a valid one."
            ),
        }

    ref_now = now or pk_now()
    if parsed < ref_now:
        return {
            "error": "past_pickup_datetime",
            "provided": parsed.isoformat(),
            "now": ref_now.isoformat(),
            "instruction": (
                f"The pickup time ({parsed.isoformat()}) is in the past. Do NOT book it and "
                "do NOT silently pick a different time yourself. Tell the user that time has "
                "already passed and ask for a current or future pickup time."
            ),
        }

    return None


def build_car_booking_data(args: dict) -> dict:
    """
    Assemble the car_booking_choice payload the app renders and then confirms.
    Assumes get_car_booking_error already returned None. `price_pkr` is advisory
    (see _CAR_VEHICLE_PRICES); book_standalone_car sets the authoritative amount.
    """
    a = args or {}
    vehicle = str(a.get("vehicle_type") or "").strip()
    parsed = _parse_datetime_strict(a.get("pickup_datetime"))
    return {
        "booking_type": "car",
        "pickup_location": str(a.get("pickup_location") or "").strip(),
        "dropoff_location": str(a.get("dropoff_location") or "").strip(),
        "vehicle_type": vehicle,
        "pickup_datetime": parsed.isoformat() if parsed else str(a.get("pickup_datetime") or "").strip(),
        "price_pkr": _CAR_VEHICLE_PRICES.get(vehicle, 800),
    }


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


# ── Budget filter — deterministic, applied only when the model passes a number ─

def _filter_by_budget(items: list[dict], price_key: str, budget) -> tuple[list[dict], str | None]:
    """
    Filter a serialized result list to items at or under `budget`, sorted
    cheapest first. If nothing qualifies, returns the FULL list (still sorted
    cheapest first) rather than an empty one, so the user sees how far off the
    nearest option is instead of a dead end. Returns (items, note) — note is
    None if no budget was given (so the caller doesn't need special-casing).
    """
    try:
        budget_val = float(budget)
    except (TypeError, ValueError):
        return items, None
    if budget_val <= 0:
        return items, None
    within = sorted((i for i in items if (i.get(price_key) or 0) <= budget_val), key=lambda i: i.get(price_key) or 0)
    if within:
        return within, f"{len(within)} option(s) at or under your PKR {budget_val:,.0f} budget, cheapest first."
    cheapest_first = sorted(items, key=lambda i: i.get(price_key) or 0)
    return cheapest_first, f"Nothing found at or under PKR {budget_val:,.0f} — showing all options, cheapest first."


def _filter_train_classes_by_budget(trains: list[dict], budget) -> tuple[list[dict], str | None]:
    """
    Same principle as _filter_by_budget, but trains nest a `classes` list —
    trim each train's classes to those at or under budget (dropping trains left
    with none), sorted cheapest class first. Falls back to the full, unfiltered
    list (classes sorted cheapest first) if nothing anywhere qualifies.
    """
    try:
        budget_val = float(budget)
    except (TypeError, ValueError):
        return trains, None
    if budget_val <= 0:
        return trains, None

    filtered: list[dict] = []
    for t in trains:
        classes = sorted(
            (c for c in t.get("classes", []) if (c.get("price_pkr") or 0) <= budget_val),
            key=lambda c: c.get("price_pkr") or 0,
        )
        if classes:
            filtered.append({**t, "classes": classes})

    if filtered:
        return filtered, f"Showing classes at or under your PKR {budget_val:,.0f} budget, cheapest first."

    fallback = [
        {**t, "classes": sorted(t.get("classes", []), key=lambda c: c.get("price_pkr") or 0)}
        for t in trains
    ]
    return fallback, f"Nothing found at or under PKR {budget_val:,.0f} — showing all classes, cheapest first."


def check_budget_feasibility(
    budget_pkr,
    *,
    flight_pkr: float = 0,
    travelers: int = 1,
    hotel_per_night_pkr: float = 0,
    nights: int = 0,
    rooms: int = 1,
    transfer_pkr: float = 0,
) -> dict:
    """
    Deterministic whole-trip budget check. Given the real per-component prices the
    agent already gathered, compute the total trip cost (flights × travelers +
    hotel/night × nights × rooms + transfer) and compare it to the user's stated
    budget. Pure function — no LLM, no I/O — so the "can they afford it" verdict is
    grounded in real numbers, not model arithmetic. All money is PKR.

    Returns the numbers plus a ready-to-read `verdict` string.
    """
    try:
        budget_val = float(budget_pkr)
    except (TypeError, ValueError):
        budget_val = 0.0

    travelers = max(int(travelers or 1), 1)
    rooms = max(int(rooms or 1), 1)
    nights = max(int(nights or 0), 0)

    flights_total = max(float(flight_pkr or 0), 0.0) * travelers
    hotel_total = max(float(hotel_per_night_pkr or 0), 0.0) * nights * rooms
    transfer_total = max(float(transfer_pkr or 0), 0.0)
    total = flights_total + hotel_total + transfer_total

    gap = round(total - budget_val)          # positive => over budget
    fits = budget_val > 0 and total <= budget_val

    if budget_val <= 0:
        verdict = (
            f"Estimated trip cost is PKR {total:,.0f}. Tell me your budget and "
            f"I'll check whether it fits."
        )
    elif fits:
        verdict = (
            f"Your PKR {budget_val:,.0f} budget covers this trip — estimated total "
            f"PKR {total:,.0f}, about PKR {budget_val - total:,.0f} to spare."
        )
    else:
        verdict = (
            f"This trip comes to about PKR {total:,.0f}, which is PKR {gap:,.0f} over "
            f"your PKR {budget_val:,.0f} budget."
        )

    return {
        "budget_pkr": round(budget_val),
        "total_pkr": round(total),
        "fits": fits,
        "gap_pkr": gap,
        "breakdown": {
            "flights_pkr": round(flights_total),
            "hotel_pkr": round(hotel_total),
            "transfer_pkr": round(transfer_total),
        },
        "verdict": verdict,
    }


# ── Executors ─────────────────────────────────────────────────────────────────

def _is_pakistani_place(name: str) -> bool:
    """
    Deterministic backstop for Travello's domestic-only scope.

    A place is treated as Pakistani if any domestic dataset knows it — the hotel
    city aliases cover ~45 places including non-airport towns (Hunza, Murree,
    Naran), so this stays true for somewhere like Skardu while being false for
    Dubai or London.
    """
    n = (name or "").strip().lower()
    return bool(n) and (n in CITY_ALIASES or n in CITY_TO_IATA)


def _no_airport_error(city: str) -> dict:
    """
    Distinguish 'Pakistani town without an airport' from 'not in Pakistan at all'.
    The old message offered the road-travel hint for BOTH, so asking for Dubai got
    told it "may be reachable only by road (e.g. Hunza via Gilgit)" — nonsense, and
    it hid the real reason (Travello has no international inventory).
    """
    if _is_pakistani_place(city):
        return {"error": f"No domestic airport at '{city}'. It may be reachable only by "
                         f"road or via a nearby airport (e.g. Hunza via Gilgit)."}
    return {"error": f"'{city}' is outside Pakistan. Travello covers domestic Pakistan "
                     f"travel only — there is no international inventory to search. Tell "
                     f"the user this plainly and offer a domestic alternative instead."}


async def _exec_flights(args: dict) -> dict:
    origin = (args.get("origin_city") or "").strip()
    dest = (args.get("destination_city") or "").strip()
    o_iata = CITY_TO_IATA.get(origin.lower())
    d_iata = CITY_TO_IATA.get(dest.lower())
    if not o_iata:
        return _no_airport_error(origin)
    if not d_iata:
        return _no_airport_error(dest)
    d = _to_date(args.get("travel_date"))
    pax = int(args.get("passengers") or 1)
    cabin = (args.get("cabin_class") or "ECONOMY").upper()
    offers = await search_flights(o_iata, d_iata, d, pax, cabin_class=cabin)
    if not offers:
        return {"flights": [], "note": f"No flights found {origin}->{dest} on {d.isoformat()}."}
    flights = _serialize_flights(offers)
    result = {"search_date": d.isoformat(), "passengers": pax, "flights": flights}
    flights, note = _filter_by_budget(flights, "price_pkr", args.get("max_budget_pkr"))
    result["flights"] = flights
    if note:
        result["budget_note"] = note
    return result


async def _exec_trains(args: dict) -> dict:
    origin = (args.get("origin_city") or "").strip()
    dest = (args.get("destination_city") or "").strip()
    d = _to_date(args.get("travel_date"))
    pax = int(args.get("passengers") or 1)
    resp = await asyncio.to_thread(search_trains, origin, dest, d, pax)
    result = _serialize_trains(resp)
    result["search_date"] = d.isoformat()
    trains, note = _filter_train_classes_by_budget(result.get("trains", []), args.get("max_budget_pkr"))
    result["trains"] = trains
    if note:
        result["budget_note"] = note
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
    hotels = _serialize_hotels(resp)
    hotels, note = _filter_by_budget(hotels, "price_per_night_pkr", args.get("max_budget_pkr"))
    result = {
        "city": city,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "nights": max((co - ci).days, 1),
        "hotels": hotels,
    }
    if note:
        result["budget_note"] = note
    return result


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
    date_fields = _TOOL_DATE_FIELDS.get(name)
    if date_fields:
        missing_date_error = find_missing_date_error(args or {}, date_fields)
        if missing_date_error:
            return json.dumps(missing_date_error)
        past_date_error = find_past_date_error(args or {}, date_fields)
        if past_date_error:
            return json.dumps(past_date_error)
    try:
        result = await executor(args or {})
        return json.dumps(result, default=str)
    except Exception as exc:
        logger.warning("tool '%s' failed: %s", name, exc)
        return json.dumps({"error": f"{name} failed: {exc}"})


# ── Booking gate: deterministic required-field check ──────────────────────────
#
# The agentic loop must never rely on the model's own judgment to decide "I have
# enough info to book." This table is the code-level source of truth, mirroring
# clarification_agent._REQUIRED_FIELDS but for the prepare_booking step.

_BOOKING_REQUIRED_FIELDS: dict[str, list[str]] = {
    "flight": ["origin", "destination", "travel_date", "flight_number", "cabin_class", "adults"],
    "train":  ["origin", "destination", "travel_date", "train_name", "train_class", "adults"],
    "hotel":  ["destination", "check_in", "check_out", "hotel_name", "guests", "rooms"],
}

_BOOKING_FIELD_LABELS: dict[str, str] = {
    "origin": "departure city",
    "destination": "destination city",
    "travel_date": "travel date",
    "flight_number": "which specific flight (the flight number from the listed options)",
    "cabin_class": "cabin class (Economy, Business or First)",
    "train_name": "which specific train",
    "train_class": "which class (e.g. AC Business, AC Standard, Economy)",
    "check_in": "check-in date",
    "check_out": "check-out date",
    "hotel_name": "which specific hotel",
    "adults": "how many people are traveling (adults, plus any children or infants)",
    "guests": "how many guests are staying",
    "rooms": "how many rooms are needed",
}


def get_missing_booking_fields(booking_data: dict) -> list[str]:
    """
    Which required fields for this booking_type are still missing from the
    model's prepare_booking arguments. Returns ["booking_type"] if booking_type
    itself is missing or unrecognized — the caller can't even dispatch without it.
    """
    booking_type = str((booking_data or {}).get("booking_type") or "")
    required = _BOOKING_REQUIRED_FIELDS.get(booking_type)
    if required is None:
        return ["booking_type"]
    return [f for f in required if not booking_data.get(f)]


def missing_fields_result(missing: list[str]) -> dict:
    """Structured tool-result fed back to the model when required fields are missing."""
    labels = [_BOOKING_FIELD_LABELS.get(f, f) for f in missing]
    return {
        "error": "missing_required_fields",
        "missing_fields": missing,
        "ask_for": labels,
        "instruction": (
            "Do not call prepare_booking again until you have ALL of these. Ask the "
            "user for exactly these details in ONE short, warm, combined question — "
            "do not guess, default, or invent any of them."
        ),
    }


# ── Transfer gate: the pickup address must be a real one ──────────────────────
#
# The optional airport/station transfer is NOT cosmetic text on a summary card.
# After payment, services.car_service.book_car_transfers copies
# transfer_pickup_location straight into car_bookings.pickup_location and emails
# it to the assigned driver as the address to drive to. Its only guard is
# `if not pickup_location` — so a model-invented placeholder like
# "Your pickup address in Islamabad" is non-empty, clears every existing check,
# and dispatches a real driver to a sentence. The address has to have come from
# the user, and "did the model actually ask?" is not something the model can be
# trusted to self-report — so it is inferred deterministically from the value.

_TRANSFER_PLACEHOLDER_RE = re.compile(
    # A genuine street address never contains the words "pickup address" — only
    # a model narrating the field it was supposed to fill does. This is the exact
    # shape observed in the wild ("Your pickup address in Islamabad").
    r"pickup\s+(?:address|location|point)"
    r"|(?:your|users?'?s?|customers?'?s?|their)\s+(?:address|location)"
    r"|address\s+(?:here|goes\s+here|to\s+follow)"
    r"|to\s+be\s+(?:confirmed|provided|shared|advised|decided|determined)"
    r"|not\s+(?:provided|specified|given|yet\s+provided)"
    r"|same\s+as\s+above"
    r"|\b(?:tbd|tba|n/?a|unknown|placeholder|xxx+)\b"
    # <address>, [address], {address} — template leftovers.
    r"|[<\[\{]",
    re.IGNORECASE,
)


def _transfer_error(problem: str, ask_for: str) -> dict:
    return {
        "error": "invalid_transfer_pickup",
        "problem": problem,
        "instruction": (
            f"{problem} Do NOT call prepare_booking again until the user has "
            f"given you this. Ask them for {ask_for} in one short, warm question. "
            "Never fill it in yourself, never describe the field back as if it "
            "were an answer, and never default it — a driver is dispatched to "
            "this exact text after payment."
        ),
    }


def get_transfer_error(booking_data: dict) -> dict | None:
    """
    Validate the optional car-transfer fields on a prepare_booking call.
    Returns a structured error dict (hard stop, like the date and count gates)
    or None when there is no transfer, or the transfer is properly specified.
    """
    bd = booking_data or {}
    vehicle = str(bd.get("transfer_vehicle_type") or "").strip()
    pickup = str(bd.get("transfer_pickup_location") or "").strip()

    # No transfer on this booking — nothing to validate.
    if not vehicle and not pickup:
        return None

    if vehicle and vehicle not in _CAR_VEHICLES:
        return _transfer_error(
            f"'{vehicle}' is not a vehicle we run.",
            "which vehicle they want — Sedan (1-3 pax), SUV (1-5) or Van (6-9)",
        )

    if not vehicle:
        return _transfer_error(
            "A pickup address was given but no vehicle type.",
            "which vehicle they want — Sedan (1-3 pax), SUV (1-5) or Van (6-9)",
        )

    if not pickup:
        return _transfer_error(
            "The car transfer has no pickup address.",
            "the street address the driver should collect them from",
        )

    if _TRANSFER_PLACEHOLDER_RE.search(pickup):
        return _transfer_error(
            f"'{pickup}' is a placeholder, not an address the user gave you.",
            "their actual pickup address — house/street/area, not just the city",
        )

    # A bare city name is a real place but useless to a driver, and it's the
    # other way this field gets filled without asking (echoing the route).
    if _is_pakistani_place(pickup):
        return _transfer_error(
            f"'{pickup}' is just a city, not an address a driver can reach.",
            "their full pickup address within the city — house/street/area",
        )

    return None


# ── Count gate: deterministic traveler/guest/room range validation ─────────────
#
# Same principle as the date-sanity gate: the model's own judgment about whether
# a party size makes sense is never trusted. Limits mirror the manual flow
# exactly — flights max 9 travelers with infants <= adults (search UI rule),
# trains 1-6 passengers (TrainBookRequest), hotels 1-10 guests / 1-5 rooms
# (HotelBookRequest). A violation is rejected in code before repricing.

_COUNT_LIMITS_NOTE = {
    "flight": "Flights allow up to 9 travelers total, and infants cannot outnumber adults.",
    "train": "Trains allow 1 to 6 passengers per booking.",
    "hotel": "Hotels allow 1 to 10 guests and 1 to 5 rooms per booking.",
}


def _as_count(value, *, default: int | None = None) -> int | None:
    """Coerce a model-supplied count to a non-negative int; None if unusable."""
    if value is None or value == "":
        return default
    try:
        n = int(value)
    except (TypeError, ValueError):
        return None
    return n if n >= 0 else None


def _count_error(booking_type: str, problem: str) -> dict:
    return {
        "error": "invalid_party_size",
        "problem": problem,
        "instruction": (
            f"{problem} {_COUNT_LIMITS_NOTE.get(booking_type, '')} Do not call "
            "prepare_booking again with these numbers. Tell the user the limit "
            "plainly and ask how they'd like to adjust (e.g. fewer people, or "
            "splitting into more than one booking)."
        ),
    }


def get_booking_count_error(booking_data: dict) -> dict | None:
    """
    Deterministic range check for party-size fields, run after
    get_missing_booking_fields and before repricing. Returns a structured
    error dict (hard stop, like the date gate) or None if counts are valid.
    """
    bd = booking_data or {}
    booking_type = str(bd.get("booking_type") or "")

    if booking_type in ("flight", "train"):
        adults = _as_count(bd.get("adults"))
        children = _as_count(bd.get("children"), default=0)
        infants = _as_count(bd.get("infants"), default=0)
        if adults is None or children is None or infants is None:
            return _count_error(booking_type, "The traveler counts must be whole numbers.")
        if adults < 1:
            return _count_error(booking_type, "At least 1 adult traveler is required.")
        total = adults + children + infants
        if booking_type == "flight":
            if total > 9:
                return _count_error(booking_type, f"{total} travelers exceeds the 9-traveler limit.")
            if infants > adults:
                return _count_error(booking_type, f"{infants} infant(s) with only {adults} adult(s) — each infant needs an adult.")
        else:
            if total > 6:
                return _count_error(booking_type, f"{total} passengers exceeds the 6-passenger limit for trains.")
        return None

    if booking_type == "hotel":
        guests = _as_count(bd.get("guests"))
        rooms = _as_count(bd.get("rooms"))
        if guests is None or rooms is None:
            return _count_error(booking_type, "The guest and room counts must be whole numbers.")
        if not (1 <= guests <= 10):
            return _count_error(booking_type, f"{guests} guest(s) is outside the allowed 1-10 range.")
        if not (1 <= rooms <= 5):
            return _count_error(booking_type, f"{rooms} room(s) is outside the allowed 1-5 range.")
        return None

    return None


def apply_traveler_totals(booking_data: dict) -> dict:
    """
    Return a copy of booking_data with the legacy `travelers` total recomputed
    in code from the validated party-size fields — flights/trains from
    adults + children + infants, hotels from guests. The model's own
    `travelers` value is always overwritten; downstream pricing and booking
    (reprice_booking, /agent/book, the passenger form) key off this total.
    Call only after get_booking_count_error returned None.
    """
    bd = dict(booking_data or {})
    booking_type = str(bd.get("booking_type") or "")
    if booking_type in ("flight", "train"):
        adults = _as_count(bd.get("adults")) or 1
        children = _as_count(bd.get("children"), default=0) or 0
        infants = _as_count(bd.get("infants"), default=0) or 0
        bd["adults"], bd["children"], bd["infants"] = adults, children, infants
        bd["travelers"] = adults + children + infants
    elif booking_type == "hotel":
        guests = _as_count(bd.get("guests")) or 1
        bd["guests"] = guests
        bd["rooms"] = _as_count(bd.get("rooms")) or 1
        bd["travelers"] = guests
        if not bd.get("room_type"):
            bd["room_type"] = "Standard Room"
    return bd


def offer_not_found_result() -> dict:
    """Structured tool-result fed back when the chosen option can't be re-confirmed."""
    return {
        "error": "offer_not_found",
        "instruction": (
            "The exact option you tried to book could not be confirmed against current "
            "live listings — it may be stale, mistyped, or no longer available. Tell the "
            "user this plainly and either re-run the search tool or ask them to confirm "
            "exactly which listed option they mean. Do not claim it is booked."
        ),
    }


# ── Booking gate: server-side price re-derivation ──────────────────────────────
#
# total_price_pkr in the model's prepare_booking call is NEVER trusted directly.
# Each of these re-runs the SAME search executor that produced the original
# offer and pulls the price from the matching result — so a manipulated or
# hallucinated price (e.g. via prompt injection) can never reach a payment screen.

def _norm(s: str | None) -> str:
    return (s or "").strip().lower()


def _norm_code(s: str | None) -> str:
    return re.sub(r"\s+", "", (s or "")).strip().lower()


def _names_match(a: str, b: str) -> bool:
    """Exact (case-insensitive) match, or either name containing the other."""
    return bool(a) and bool(b) and (a == b or a in b or b in a)


async def _reprice_flight(bd: dict) -> dict | None:
    passengers = int(bd.get("travelers") or 1)
    cabin = (bd.get("cabin_class") or "ECONOMY").upper()
    result = await _exec_flights({
        "origin_city": bd.get("origin"),
        "destination_city": bd.get("destination"),
        "travel_date": bd.get("travel_date"),
        "passengers": passengers,
        "cabin_class": cabin,
    })
    target = _norm_code(bd.get("flight_number"))
    if not target:
        return None
    for f in result.get("flights", []):
        if _norm_code(f.get("flight_number")) == target:
            verified = dict(bd)
            verified["total_price_pkr"] = f["price_pkr"]
            verified["travelers"] = passengers
            verified["cabin_class"] = cabin
            depart = f.get("depart", "")
            if " " in depart:
                verified["departure_time"] = depart.split(" ", 1)[1]
            if f.get("arrive"):
                verified["arrival_time"] = f["arrive"]
            return verified
    return None


async def _reprice_train(bd: dict) -> dict | None:
    passengers = int(bd.get("travelers") or 1)
    result = await _exec_trains({
        "origin_city": bd.get("origin"),
        "destination_city": bd.get("destination"),
        "travel_date": bd.get("travel_date"),
        "passengers": passengers,
    })
    target_name = _norm(bd.get("train_name"))
    target_class = _norm(bd.get("train_class"))
    if not target_name or not target_class:
        return None
    for t in result.get("trains", []):
        if not _names_match(_norm(t.get("train_name")), target_name):
            continue
        for c in t.get("classes", []):
            if _norm(c.get("class")) == target_class:
                verified = dict(bd)
                verified["total_price_pkr"] = c["price_pkr"]
                verified["travelers"] = passengers
                verified["airline_or_train_name"] = t.get("train_name")
                # Carried from the matched live listing, never from the model —
                # the ticket shows this as the train Number, and a guessed one
                # would be a fabricated travel document detail.
                verified["train_number"] = t.get("train_number")
                return verified
    return None


async def _reprice_hotel(bd: dict) -> dict | None:
    guests = int(bd.get("travelers") or 2)
    rooms = int(bd.get("rooms") or 1)
    result = await _exec_hotels({
        "city": bd.get("destination"),
        "check_in": bd.get("check_in"),
        "check_out": bd.get("check_out"),
        "guests": guests,
        "rooms": rooms,
    })
    target = _norm(bd.get("hotel_name"))
    if not target:
        return None
    nights = result.get("nights") or 1
    for h in result.get("hotels", []):
        if not _names_match(_norm(h.get("name")), target):
            continue
        verified = dict(bd)
        verified["total_price_pkr"] = round(h["price_per_night_pkr"] * nights * rooms)
        verified["travelers"] = guests
        verified["rooms"] = rooms
        verified["check_in"] = result["check_in"]
        verified["check_out"] = result["check_out"]
        # Carried from the matched live listing, never from the model — these
        # render as the hotel's star rating and address on the ticket, and a
        # guessed star count would be a fabricated booking detail.
        verified["hotel_stars"] = h.get("stars")
        verified["hotel_address"] = h.get("area")
        return verified
    return None


async def reprice_booking(booking_data: dict) -> dict | None:
    """
    Re-derive the authoritative price for a prepare_booking call by re-running
    the same search executor that produced the original offer, then matching
    the model's chosen option against the FRESH results. Returns a corrected
    copy of booking_data with total_price_pkr (and other server-known fields)
    overwritten — or None if the option can't be confirmed against current
    listings, in which case the caller must not proceed to a payment screen.
    Never raises.
    """
    booking_type = booking_data.get("booking_type")
    try:
        if booking_type == "flight":
            verified = await _reprice_flight(booking_data)
        elif booking_type == "train":
            verified = await _reprice_train(booking_data)
        elif booking_type == "hotel":
            verified = await _reprice_hotel(booking_data)
        else:
            return None
        return _add_transfer_fare(verified) if verified else None
    except Exception as exc:
        logger.warning("reprice_booking failed for type=%s: %s", booking_type, exc)
    return None


def _add_transfer_fare(verified: dict) -> dict:
    """
    Add an accepted airport/station transfer fare to the authoritative total.

    The manual checkout charges it — booking_checkout.dart's `_subtotal` is
    ticket + baggage + seats + `_transferFee` — so the agent path has to as
    well, or the same Sedan costs PKR 800 through the form and nothing through
    chat. Deliberately applied AFTER the per-type reprice so it stacks on the
    server-derived price and never on the model's advisory figure.

    The condition mirrors _agentTransferFacilities in ai_assistant.dart exactly:
    both vehicle and pickup must be present, because that is precisely when the
    app sends the transfer on to be booked. Charging on any looser condition
    would bill for a driver who is never dispatched.
    """
    vehicle = str(verified.get("transfer_vehicle_type") or "").strip()
    pickup = str(verified.get("transfer_pickup_location") or "").strip()
    fare = _CAR_VEHICLE_PRICES.get(vehicle)
    if not fare or not pickup:
        return verified

    # This is a payment amount, so it gets a guard rather than an assumption:
    # today reprice_booking has exactly one call site and runs once per booking,
    # but a second pass would silently bill the transfer twice.
    if verified.get("transfer_pkr"):
        return verified

    try:
        base = float(verified.get("total_price_pkr") or 0)
    except (TypeError, ValueError):
        return verified
    if base <= 0:
        return verified

    verified["transfer_pkr"] = fare
    verified["total_price_pkr"] = round(base + fare)
    return verified
