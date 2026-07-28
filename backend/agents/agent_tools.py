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
import difflib
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


# ── Date provenance ───────────────────────────────────────────────────────────
#
# find_missing_date_error catches an OMITTED date; find_past_date_error catches a
# PAST one. Neither can catch the real-world failure: the model, faced with a
# REQUIRED travel_date, invents one — almost always today — rather than stopping
# to ask. Today is present and not-past, so it sails through both gates and the
# user is shown "flights on <today>" for a trip whose date they never gave.
#
# The only signal that separates an invented date from a real one is provenance:
# did the USER actually mention a date anywhere in the conversation? A value like
# "2026-07-22" carries no such fingerprint; the user's own words do. This matcher
# is deliberately GENEROUS — any temporal token counts as "date given", so a user
# who did say when never gets re-asked. It fires only when there is NO temporal
# signal at all, which is exactly the "book me a flight to Skardu" case.
_TEMPORAL_RE = re.compile(
    r"\b\d{4}-\d{1,2}-\d{1,2}\b"                    # 2026-07-22
    r"|\b\d{1,2}[/.\-]\d{1,2}(?:[/.\-]\d{2,4})?\b"  # 22/7 , 22-07-2026 , 22.07
    r"|\b\d{1,2}(?:st|nd|rd|th)\b"                  # 22nd, 3rd
    r"|\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?"
    r"|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b"
    r"|\b(?:mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?"
    r"|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b"    # weekday (exact-bounded: not "money"/"sunny")
    r"|\b(?:today|tonight|tomorrow|tmrw|tmr|yesterday)\b"
    r"|\b(?:this|next|coming|upcoming|following)\s+(?:week|month|weekend|day)\b"
    r"|\b(?:week|weeks|month|months|weekend)\b"     # vague-but-present ("next month") → passes
    r"|\bin\s+\d{1,2}\s+days?\b",
    re.IGNORECASE,
)


def user_supplied_date_signal(texts: list[str]) -> bool:
    """True if ANY of the user's messages carries a date the model could have
    used — an explicit date, a month/weekday/ordinal, or a relative phrase.
    Scans the whole conversation, not just this turn, because the date may have
    been given a turn before the search is finally run."""
    for t in texts:
        if not isinstance(t, str) or not t.strip():
            continue
        if _parse_relative_date(t) or _TEMPORAL_RE.search(t):
            return True
    return False


def date_provenance_error(name: str, *, has_user_date: bool) -> dict | None:
    """
    Block a date-bearing search when the user never gave a date. Returns a
    structured clarify result the model gets back in place of search results,
    so its next turn asks instead of presenting an invented date as fact.
    Non-search tools (no date field) always pass.
    """
    if has_user_date:
        return None
    date_fields = _TOOL_DATE_FIELDS.get(name)
    if not date_fields:
        return None
    label = _DATE_FIELD_LABELS.get(date_fields[0], date_fields[0])
    return {
        "error": "date_not_provided",
        "field": date_fields[0],
        "instruction": (
            f"The user has not given a travel date anywhere in this conversation — "
            f"not this message, not an earlier one. Do NOT search with today's date "
            f"or any assumed date, and do NOT state a date as if they chose it. Ask "
            f"for their {label} (with anything else still missing) in ONE short, warm "
            f"question, then search once they answer."
        ),
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


# ── Car booking provenance: the sensitive details must come from the USER ──────
#
# get_car_booking_error validates SHAPE (present, valid vehicle, future time) but
# not PROVENANCE — it cannot tell a detail the user actually gave from one the
# model invented. Observed live: "book car for me too" (the entire request, no
# other detail) produced a fully-specified, confirmable ride — Sedan,
# hotel -> "Islamabad Airport", checkout-day 10:00 — none of which the user said,
# and confirming it dispatched a real driver to an invented destination at an
# invented time. Same failure class as the date-provenance gate: an
# invented-but-valid value clears every shape check.
#
# So the three sensitive fields must additionally be traceable to the user's own
# words: the drop-off (where a real driver is sent), the vehicle (the prompt says
# offer Sedan/SUV/Van and let the user choose — a silent default is a guess), and
# the pickup time. PICKUP is deliberately exempt — inferring it from the hotel /
# booking the user just made is a reasonable convenience, and it's the least
# consequential of the four. Fires only when a field is genuinely ungrounded, so
# a real "Sedan from my hotel to the airport at 3pm tomorrow" passes untouched.

_CAR_VEHICLE_RE = re.compile(r"\b(?:sedan|suv|van)\b", re.IGNORECASE)

# Clock-time signals user_supplied_date_signal doesn't cover (it handles the
# date/day half — "tomorrow", weekdays, "tonight"). Together they answer "did the
# user say WHEN".
_CLOCK_TIME_RE = re.compile(
    r"\b\d{1,2}:\d{2}\b"                                   # 10:00, 3:30
    r"|\b\d{1,2}\s*(?:a\.?m\.?|p\.?m\.?)\b"                # 3pm, 10 a.m.
    r"|\b(?:morning|afternoon|evening|noon|midnight|midday|dawn|dusk)\b",
    re.IGNORECASE,
)

# Pure connectors — never distinctive enough to ground a drop-off on their own.
# A place-type word ("airport", "mall", "station") is NOT here: it's exactly the
# token that must have come from the user.
_LOC_STOPWORDS: frozenset[str] = frozenset({
    "the", "near", "from", "drop", "pick", "pickup", "dropoff", "please",
    "road", "street", "avenue", "block", "sector", "phase", "town", "city",
})


# Words that start (or continue) a car request. Used to scope provenance to the
# car sub-conversation: a hotel's check-in dates or a flight's date, given turns
# earlier, must NOT count as the car's pickup time — the "when" has to come from
# the car discussion itself.
_CAR_INTENT_RE = re.compile(r"\b(?:car|ride|driver|cab|taxi|sedan|suv|van)\b", re.IGNORECASE)

# A "fresh" car request pairs a car word with an actual request verb ("book a
# car", "need a van", "reserve another SUV"). This is what STARTS a new ride,
# versus a bare follow-up answer ("sedan", "3pm") that only continues the one in
# progress. Scoping to the LAST fresh request is what stops a SECOND car booking
# in the same session from inheriting the FIRST ride's drop-off / vehicle / time
# as though the user had re-stated them — an evaluator booking two cars back to
# back was otherwise handed car #1's "Sedan"/"9am" to ground car #2's invented ride.
_CAR_REQUEST_VERB_RE = re.compile(
    r"\b(?:book|reserve|need|want|arrange|hire|order|get|rent)\b", re.IGNORECASE
)


def _is_fresh_car_request(t: str) -> bool:
    """A message that both names a car word AND asks for one — a new ride's start."""
    return bool(isinstance(t, str) and _CAR_INTENT_RE.search(t) and _CAR_REQUEST_VERB_RE.search(t))


def _scope_to_car(texts_chrono: list[str]) -> list[str]:
    """
    Slice the user's messages (oldest->newest) down to just the CURRENT car request.

    Prefer the LAST "fresh" car request onward: in a session with two car bookings
    this drops the first ride's details, so its Sedan/9am/drop-off can't ground the
    second ride's invented values. Fall back to the first bare car-intent mention
    when nothing reads as a fresh request, which preserves a single multi-turn spec
    whose details dribble across follow-up messages ("book a car" → "sedan" → "3pm").
    """
    texts = [t for t in (texts_chrono or []) if isinstance(t, str) and t.strip()]
    last_fresh = next((i for i in range(len(texts) - 1, -1, -1) if _is_fresh_car_request(texts[i])), None)
    if last_fresh is not None:
        return texts[last_fresh:]
    for i, t in enumerate(texts):
        if _CAR_INTENT_RE.search(t):
            return texts[i:]
    return texts


def _joined_user_text(texts: list[str]) -> str:
    return " ".join(t.lower() for t in (texts or []) if isinstance(t, str) and t.strip())


def _user_said_vehicle(texts: list[str]) -> bool:
    return bool(_CAR_VEHICLE_RE.search(_joined_user_text(texts)))


def _user_said_time(texts: list[str]) -> bool:
    """True if the user gave a date/day (date-provenance) OR a clock time."""
    if user_supplied_date_signal(texts):
        return True
    return bool(_CLOCK_TIME_RE.search(_joined_user_text(texts)))


def _location_grounded(location: str, texts: list[str]) -> bool:
    """
    True if the drop-off traces back to the user's own words — either the whole
    phrase appears, or a distinctive token does. A bare city name is NOT
    distinctive (the user said "Islamabad" when booking a hotel, but never said
    "airport"), so the city is stripped before matching — which is precisely what
    catches the invented "Islamabad Airport" while still grounding a real
    "Centaurus Mall" or "the airport" the user actually typed.
    """
    loc = _norm(location)
    joined = _joined_user_text(texts)
    if not loc or not joined:
        return False
    if loc in joined:                                # user typed the whole thing
        return True
    for tok in re.findall(r"[a-z0-9]+", loc):
        if len(tok) < 4 or tok in _LOC_STOPWORDS or tok in _KNOWN_CITIES:
            continue
        if re.search(r"\b" + re.escape(tok) + r"\b", joined):
            return True
    return False


_CAR_PROVENANCE_LABELS: dict[str, str] = {
    "dropoff": "where they want to be dropped off (a real destination address)",
    "vehicle": "which vehicle they'd like — Sedan (PKR 800), SUV (PKR 1,200) or Van (PKR 1,500)",
    "time": "what date and time they want to be picked up",
}


def get_car_provenance_error(args: dict, user_texts: list[str]) -> dict | None:
    """
    Provenance gate for book_car — the companion to get_car_booking_error. Run it
    AFTER the shape gate (so genuinely-missing fields are caught first) and before
    build_car_booking_data. Returns a structured clarify error naming the details
    the user never actually gave (so the model asks instead of inventing), or None
    when the drop-off, vehicle and pickup time all trace back to the user's words.

    `user_texts` MUST be the user's messages in CHRONOLOGICAL order (oldest first,
    current message last) — the scan is scoped to the car sub-conversation, so an
    earlier hotel/flight date can't masquerade as the car's pickup time.
    """
    a = args or {}
    texts = _scope_to_car([t for t in (user_texts or []) if isinstance(t, str) and t.strip()])

    missing: list[str] = []
    if not _location_grounded(str(a.get("dropoff_location") or ""), texts):
        missing.append("dropoff")
    if not _user_said_vehicle(texts):
        missing.append("vehicle")
    if not _user_said_time(texts):
        missing.append("time")

    if not missing:
        return None

    labels = "; ".join(_CAR_PROVENANCE_LABELS[m] for m in missing)
    return {
        "error": "car_details_not_provided",
        "missing": missing,
        "instruction": (
            f"The user asked to book a car but has NOT actually told you: {labels}. "
            "Do NOT invent, assume, or default any of these — a real driver is "
            "dispatched to exactly what you enter, so a guessed drop-off or time "
            "books a wrong real ride. Ask the user for the missing details in ONE "
            "short, friendly question, then book only once they answer. You may keep "
            "a pickup point you can reasonably infer (e.g. the hotel they just booked)."
        ),
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
            # Whole-party fare (the service already multiplied per-seat × passengers).
            # Named total_price_pkr so the model never mistakes it for a per-seat price
            # and re-multiplies by the head-count. _exec_flights adds price_per_seat_pkr.
            "total_price_pkr": round(o.total_price_pkr),
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
            # total_price_pkr = whole-party fare (service already ×passengers).
            # _exec_trains adds price_per_seat_pkr alongside it.
            {"class": c.class_name, "total_price_pkr": round(c.price_pkr), "seats_left": c.seats_available}
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
            (c for c in t.get("classes", []) if (c.get("total_price_pkr") or 0) <= budget_val),
            key=lambda c: c.get("total_price_pkr") or 0,
        )
        if classes:
            filtered.append({**t, "classes": classes})

    if filtered:
        return filtered, f"Showing classes at or under your PKR {budget_val:,.0f} budget, cheapest first."

    fallback = [
        {**t, "classes": sorted(t.get("classes", []), key=lambda c: c.get("total_price_pkr") or 0)}
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
    # Every argument here can arrive non-numeric — the counts come from model
    # tool-call args and the prices from serialized results — so each coercion is
    # guarded. An unparseable value degrades to a sane default rather than raising:
    # this function only produces an advisory verdict string, and a crash would
    # abort the whole tool loop for a number that was never going to be shown.
    def _money(v) -> float:
        try:
            return max(float(v or 0), 0.0)
        except (TypeError, ValueError):
            return 0.0

    try:
        budget_val = float(budget_pkr)
    except (TypeError, ValueError):
        budget_val = 0.0

    travelers = max(_as_count(travelers, default=1) or 1, 1)
    rooms = max(_as_count(rooms, default=1) or 1, 1)
    nights = max(_as_count(nights, default=0) or 0, 0)

    flights_total = _money(flight_pkr) * travelers
    hotel_total = _money(hotel_per_night_pkr) * nights * rooms
    transfer_total = _money(transfer_pkr)
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


# ── Fuzzy city-name correction ─────────────────────────────────────────────────
#
# Used by the self-improvement retry layer (agents/self_improvement.py), not by
# execute_tool itself — a failed search_flights call whose city is a near-miss
# spelling of a real known place gets ONE retry with the correction, rather than
# reporting "outside Pakistan" for what was actually a typo.
#
# CITY_TO_IATA is a flat, un-aliased dict, so a typo has zero built-in tolerance.
# difflib recovers it deterministically WITHOUT an LLM round-trip and without
# ever inventing a new fact — it only maps a typo back to a place already in our
# own vocabulary. cutoff=0.8 is intentionally strict: at 0.72, "narnia" matched
# "naran" — a real place near enough in spelling to a nonsense word that a
# lower cutoff would silently redirect a joke input into a real search. 0.8
# rejects every nonexistent/international name tested (dubai, london, narnia,
# atlantis) while still catching realistic typos (karrachi, lahoer, mutlan,
# faislabad, islamabaad, skarduu).
_KNOWN_CITIES: list[str] = sorted(set(CITY_TO_IATA.keys()) | set(CITY_ALIASES.keys()))


def suggest_city_correction(name: str) -> str | None:
    """
    Best-guess correction for an unrecognized city name, or None if nothing is
    close enough. A wrong "correction" that silently searches a different city
    is worse than reporting the failure, hence the strict cutoff.
    """
    candidate = (name or "").strip().lower()
    if not candidate:
        return None
    matches = difflib.get_close_matches(candidate, _KNOWN_CITIES, n=1, cutoff=0.8)
    if not matches or matches[0] == candidate:
        return None
    return matches[0].title()


# ── Deterministic booking-location recovery ────────────────────────────────────
#
# The prepare_booking schema names the city field `destination`, but the search
# tools name it `city` (hotels) / `destination_city` (flights). A free-tier model
# that carried the hotel name, dates and price across several turns routinely
# still DROPS `destination` on the booking call — because that exact field name
# never appeared in the search it's copying from. The required-fields gate then
# asks "which city?", the user answers, the model re-issues the booking STILL
# without destination, and it loops (observed live: ~6 rounds of "confirm Multan?"
# before it happened to fill the field).
#
# The city is not actually unknown — it's in the chosen hotel's name and all over
# the conversation. So recover it deterministically instead of asking again. This
# only ever fills a BLANK destination, and it can't cause a wrong booking:
# reprice_booking re-searches that city and must still match the hotel by name, so
# a bad recovery fails the match and falls back to asking — exactly today's
# behaviour — rather than booking the wrong place.
# Cities sorted longest-first so a multi-word name ("gilgit baltistan") wins over
# a substring ("gilgit") and a full name wins over a short IATA-style alias.
_KNOWN_CITIES_BY_LEN: list[str] = sorted(_KNOWN_CITIES, key=len, reverse=True)


def _canonical_city(token: str) -> str:
    t = (token or "").strip().lower()
    if t in CITY_ALIASES:
        return CITY_ALIASES[t]
    if t in CITY_TO_IATA:
        return t.title()
    return (token or "").strip()


def _first_known_city(text: str) -> str | None:
    """Return the first known Pakistani city named in `text` (word-bounded), canonicalized."""
    if not text:
        return None
    low = text.lower()
    for city in _KNOWN_CITIES_BY_LEN:
        if re.search(r"\b" + re.escape(city) + r"\b", low):
            return _canonical_city(city)
    return None


def recover_booking_location(booking_data: dict, context_texts: list[str]) -> dict:
    """
    Backfill a hotel booking's missing `destination` from the hotel name, then
    from the conversation (context_texts newest-first), so the model dropping
    that one field doesn't force a repeated "which city?" loop. Returns a copy.
    Only fills a genuinely blank destination — an explicit value always wins —
    and only recovers a city already named by the user/listing, never invents one.
    Scoped to hotels: a single unambiguous city. Flights/trains carry two cities
    (origin + destination) that a plain scan can't safely tell apart.
    """
    bd = dict(booking_data or {})
    if str(bd.get("booking_type") or "") != "hotel":
        return bd
    if str(bd.get("destination") or "").strip():
        return bd
    city = _first_known_city(str(bd.get("hotel_name") or ""))
    if not city:
        for t in context_texts or []:
            city = _first_known_city(t if isinstance(t, str) else "")
            if city:
                break
    if city:
        bd["destination"] = city
    return bd


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
    pax = _as_count(args.get("passengers"), default=1) or 1
    cabin = (args.get("cabin_class") or "ECONOMY").upper()
    offers = await search_flights(o_iata, d_iata, d, pax, cabin_class=cabin)
    if not offers:
        return {"flights": [], "note": f"No flights found {origin}->{dest} on {d.isoformat()}."}
    flights = _serialize_flights(offers)
    # total_price_pkr is the whole-party fare. Surface the per-seat figure too so
    # the model can quote either without ever multiplying the party total again.
    for f in flights:
        total = f.get("total_price_pkr") or 0
        f["price_per_seat_pkr"] = round(total / pax) if pax else total
    result = {"search_date": d.isoformat(), "passengers": pax, "flights": flights}
    flights, note = _filter_by_budget(flights, "total_price_pkr", args.get("max_budget_pkr"))
    result["flights"] = flights
    if note:
        result["budget_note"] = note
    return result


async def _exec_trains(args: dict) -> dict:
    origin = (args.get("origin_city") or "").strip()
    dest = (args.get("destination_city") or "").strip()
    d = _to_date(args.get("travel_date"))
    pax = _as_count(args.get("passengers"), default=1) or 1
    resp = await asyncio.to_thread(search_trains, origin, dest, d, pax)
    result = _serialize_trains(resp)
    result["search_date"] = d.isoformat()
    result["passengers"] = pax
    # Each class total_price_pkr is the whole-party fare; add the per-seat figure
    # so the model quotes either without re-multiplying by the head-count.
    for t in result.get("trains", []):
        for c in t.get("classes", []):
            total = c.get("total_price_pkr") or 0
            c["price_per_seat_pkr"] = round(total / pax) if pax else total
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
    guests = _as_count(args.get("guests"), default=2) or 2
    rooms = _as_count(args.get("rooms"), default=1) or 1
    resp = await search_hotels(city, ci, co, guests, rooms)
    hotels = _serialize_hotels(resp)
    nights = max((co - ci).days, 1)
    # Precompute the whole-stay total the SAME way reprice_booking will
    # (price_per_night × nights × rooms) so the figure the model quotes equals
    # what gets charged — the model computing it in prose drifted by a few PKR
    # and, worse, could pair the wrong per-night with the wrong hotel.
    for h in hotels:
        h["total_stay_pkr"] = round((h.get("price_per_night_pkr") or 0) * nights * rooms)
    hotels, note = _filter_by_budget(hotels, "price_per_night_pkr", args.get("max_budget_pkr"))
    result = {
        "city": city,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "nights": nights,
        "rooms": rooms,
        "hotels": hotels,
    }
    if note:
        result["budget_note"] = note
    return result


async def _exec_weather(args: dict) -> dict:
    city = (args.get("city") or "").strip()
    # Live device GPS (injected by the orchestrator, never by the model). Used for a
    # "weather here" / "near me" query, or when no city was named, so the reading is
    # for the user's ACTUAL position. Otherwise weather is fetched by city as before.
    dev_lat, dev_lng = args.get("_dev_lat"), args.get("_dev_lng")
    prefer_device = bool(args.get("_prefer_device"))
    # is-not-None checks in the condition so dev_lat/dev_lng narrow to floats here.
    if dev_lat is not None and dev_lng is not None and (prefer_device or not city):
        label = "your current location"
        w = await get_weather(label, lat=float(dev_lat), lon=float(dev_lng))
    else:
        label = city
        w = await get_weather(city)

    # get_weather returns a synthetic 27C "Pleasant" record tagged source="fallback"
    # when it has no coordinates for the city or every live source failed. That
    # placeholder exists for the app's weather SCREEN — it is NOT a real reading, so
    # the agent must never quote it as live weather. Signal the gap explicitly (with
    # the instruction inline) so the model says it plainly instead of inventing 27C.
    if (w or {}).get("source") == "fallback":
        return {
            "city": label,
            "weather_available": False,
            "note": (
                f"No live weather data is available for {label or 'this city'} right now "
                "(it may be a town not covered, or the weather service is temporarily "
                "unreachable). Do NOT state a temperature or condition — tell the user "
                "you don't have live weather for this place."
            ),
        }
    return {"city": label, "weather": w}


async def _exec_healthcare(args: dict) -> dict:
    """
    Return STRUCTURED facility data (hospitals, pharmacies, national emergency
    numbers) — never a prose briefing gated behind a second LLM call.

    The old version handed the fetched facilities to generate_text to write a
    summary, and when THAT call hit the free-tier quota wall it returned "" — so
    the tool reported "No healthcare data available" and discarded real hospitals
    it had already fetched. That made the assistant tell a user there are no
    clinics in a city it had just listed (see the Islamabad follow-up). Facility
    data is safety-critical, so it must reach the model deterministically; the
    model only does the wording. _nearby already layers Google -> Overpass ->
    curated mock, so a supported city always yields real, phone-numbered results.
    """
    # Lazy import to avoid a heavy import chain at module load.
    from fastapi import HTTPException
    from routers.healthcare import (
        _resolve_coordinates, _nearby, _MOCK_HOSPITALS, _MOCK_PHARMACIES,
    )
    from prompts.knowledge import EMERGENCY_NUMBERS

    city = (args.get("city") or "").strip()
    # Live device GPS (injected by the orchestrator, never by the model). Used for a
    # "near me" query, or whenever no city was named, so "hospitals near me" resolves
    # to the user's ACTUAL position rather than a city they had to type.
    dev_lat, dev_lng = args.get("_dev_lat"), args.get("_dev_lng")
    prefer_device = bool(args.get("_prefer_device"))
    # is-not-None checks in the condition so dev_lat/dev_lng narrow to floats here.
    if dev_lat is not None and dev_lng is not None and (prefer_device or not city):
        lat, lng = float(dev_lat), float(dev_lng)
        location_label = "your current location"
        used_device = True
    else:
        used_device = False
        try:
            lat, lng = _resolve_coordinates(None, None, None, city)
        except HTTPException:
            # City we can't place and no device fix — still hand back the national
            # numbers so a medical question never dead-ends on an unknown town.
            return {
                "city": city, "hospitals": [], "pharmacies": [],
                "emergency_numbers": EMERGENCY_NUMBERS,
                "note": "City not recognised — no facility coordinates; use the emergency numbers.",
            }
        except Exception:
            return {
                "city": city, "hospitals": [], "pharmacies": [],
                "emergency_numbers": EMERGENCY_NUMBERS,
            }
        location_label = city

    try:
        hospitals, pharmacies = await asyncio.gather(
            _nearby(lat, lng, 15.0, "hospital", _MOCK_HOSPITALS),
            _nearby(lat, lng, 5.0, "pharmacy", _MOCK_PHARMACIES),
        )
    except Exception:
        hospitals, pharmacies = [], []

    return {
        "city": city,
        "location": location_label,
        "used_device_location": used_device,
        "hospitals": (hospitals or [])[:5],
        "pharmacies": (pharmacies or [])[:3],
        "emergency_numbers": EMERGENCY_NUMBERS,
    }


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
        # Distinctly tagged (not a domain slug like 'missing_date') so the
        # self-improvement retry layer can tell "a real exception, worth one
        # blind retry" apart from a gate rejection by matching this literal
        # tag, never by sniffing the free-text message. See agents/self_improvement.py.
        return json.dumps({
            "error": "tool_execution_error",
            "tool": name,
            "detail": str(exc),
            "instruction": (
                "A live data source failed unexpectedly. Apologise briefly, tell "
                "the user the search is temporarily unavailable, and suggest "
                "trying again shortly — do not invent a flight, train, hotel, "
                "or price in its place."
            ),
        })


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
            verified["total_price_pkr"] = f["total_price_pkr"]
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
                verified["total_price_pkr"] = c["total_price_pkr"]
                verified["travelers"] = passengers
                verified["airline_or_train_name"] = t.get("train_name")
                # Carried from the matched live listing, never from the model —
                # the ticket shows this as the train Number, and a guessed one
                # would be a fabricated travel document detail.
                verified["train_number"] = t.get("train_number")
                # Same as _reprice_flight: carry the matched offer's real times so
                # the ticket shows a real arrival instead of "—" and a real
                # departure instead of the midnight fallback in routers/agent.py.
                # The serializer formats these as "YYYY-MM-DD HH:MM"; agent.py
                # wants the HH:MM half.
                depart = t.get("depart", "")
                arrive = t.get("arrive", "")
                if " " in depart:
                    verified["departure_time"] = depart.split(" ", 1)[1]
                if " " in arrive:
                    verified["arrival_time"] = arrive.split(" ", 1)[1]
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
