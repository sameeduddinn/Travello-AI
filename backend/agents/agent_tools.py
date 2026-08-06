from __future__ import annotations
# PURPOSE: Tool layer for the agentic orchestrator.
#
#   - TOOL_SCHEMAS : OpenAI/Groq function-calling schemas the LLM can call
#   - execute_tool : dispatches a tool call to the REAL service and returns a
#                    COMPACT JSON string the LLM reasons over directly.


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
from services.car_service import estimate_fare as _estimate_car_fare
from services.northern_routes import hub_options_for
from agents.clarification_agent import CITY_TO_IATA, _parse_relative_date

logger = logging.getLogger(__name__)


TOOL_SCHEMAS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "search_flights",
            "description": (
                "Search live domestic Pakistan flights. Skardu and Gilgit have airports; "
                "Hunza does not."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "origin_city": {"type": "string", "description": "Departure city, e.g. Karachi"},
                    "destination_city": {"type": "string", "description": "Arrival city, e.g. Lahore"},
                    "travel_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "passengers": {
                        "type": "integer",
                        "description": (
                            "How many people are flying. REQUIRED — fare is per-seat x passengers. "
                            "Use the number the user gave; ask if they haven't. Never guess."
                        ),
                    },
                    "cabin_class": {
                        "type": "string",
                        "enum": ["ECONOMY", "BUSINESS", "FIRST"],
                        "description": "Default ECONOMY",
                    },
                    "max_budget_pkr": {
                        "type": "number",
                        "description": "Only if the user gave a PKR ceiling. Omit otherwise.",
                    },
                },
                "required": ["origin_city", "destination_city", "travel_date", "passengers"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_trains",
            "description": (
                "Search Pakistan Railways trains between major cities. The far north has no rail."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "origin_city": {"type": "string", "description": "Departure city"},
                    "destination_city": {"type": "string", "description": "Arrival city"},
                    "travel_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "passengers": {
                        "type": "integer",
                        "description": (
                            "How many people are travelling. REQUIRED — fare is per-seat x "
                            "passengers. Use the number the user gave; ask if they haven't."
                        ),
                    },
                    "max_budget_pkr": {
                        "type": "number",
                        "description": "Only if the user gave a PKR ceiling. Omit otherwise.",
                    },
                },
                "required": ["origin_city", "destination_city", "travel_date", "passengers"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_hotels",
            "description": "Search hotels in a city for check-in/check-out dates.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string"},
                    "check_in": {"type": "string", "description": "YYYY-MM-DD"},
                    "check_out": {"type": "string", "description": "YYYY-MM-DD"},
                    "guests": {
                        "type": "integer",
                        "description": (
                            "Only a number the user actually gave. If they haven't said, OMIT it "
                            "rather than assuming a party size — and ask before booking."
                        ),
                    },
                    "rooms": {"type": "integer", "description": "Number of rooms (default 1)"},
                    "max_budget_pkr": {
                        "type": "number",
                        "description": "Only if the user gave a per-night PKR ceiling. Omit otherwise.",
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
            "description": "Current weather and travel warnings for a city.",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "find_healthcare",
            "description": "Nearby hospitals and pharmacies plus a short safety briefing for a city.",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "book_car",
            "description": (
                "Book a standalone within-city car with driver. NOT the airport transfer that "
                "rides along on prepare_booking. Call only once you have all four fields. It does "
                "not charge a card; the app shows a Confirm step and the driver, car and "
                "verification code are assigned only after that tap — never promise them first."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "pickup_location": {"type": "string", "description": "Full pickup address"},
                    "dropoff_location": {"type": "string", "description": "Full drop-off address"},
                    "vehicle_type": {
                        "type": "string",
                        "enum": ["Sedan", "SUV", "Van"],
                        "description": "Sedan PKR 3,000 (1-3), SUV PKR 6,000 (1-5), Van PKR 9,000 (6-9)",
                    },
                    "pickup_datetime": {
                        "type": "string",
                        "description": "ISO 8601 YYYY-MM-DDTHH:MM, resolved by you, must be future",
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
                "Call ONLY when the user picked a SPECIFIC option you already showed. Copy that "
                "option's real details — never invent a price, flight number, train or hotel. "
                "Opens the app's booking screen; does not charge. Unsure which option? Ask instead. "
                "For a round trip or package, call once per piece in the SAME reply."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "booking_type": {"type": "string", "enum": ["flight", "train", "hotel"]},
                    "origin": {"type": "string"},
                    "destination": {"type": "string"},
                    "travel_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "departure_time": {"type": "string", "description": "HH:MM 24h"},
                    "arrival_time": {"type": "string", "description": "HH:MM 24h"},
                    "flight_number": {"type": "string", "description": "e.g. PK304"},
                    "cabin_class": {"type": "string", "enum": ["ECONOMY", "BUSINESS", "FIRST"]},
                    "train_name": {"type": "string", "description": "e.g. Tezgam Express"},
                    "train_class": {
                        "type": "string",
                        "description": (
                            "Exact fare class shown in the results (e.g. 'AC Business'). "
                            "Required for trains — each class has its own price."
                        ),
                    },
                    "airline_or_train_name": {"type": "string"},
                    "hotel_name": {"type": "string"},
                    "check_in": {"type": "string", "description": "YYYY-MM-DD"},
                    "check_out": {"type": "string", "description": "YYYY-MM-DD"},
                    "rooms": {"type": "integer", "description": "Hotel rooms 1-5, required for hotels"},
                    "guests": {"type": "integer", "description": "Hotel guests 1-10, required for hotels"},
                    "room_type": {"type": "string", "description": "Only if the user stated one"},
                    "adults": {
                        "type": "integer",
                        "description": "Adults 12+. Required for flights/trains. 1 if solo, else ask.",
                    },
                    "children": {"type": "integer", "description": "Ages 2-11, default 0"},
                    "infants": {"type": "integer", "description": "Under 2, default 0"},
                    "transfer_vehicle_type": {
                        "type": "string",
                        "enum": ["Sedan", "SUV", "Van"],
                        "description": "Only if an airport/station transfer was accepted",
                    },
                    "transfer_pickup_location": {
                        "type": "string",
                        "description": "Real street address for that transfer, never a placeholder",
                    },
                    "transfer_dropoff_location": {
                        "type": "string",
                        "description": "Only for a northern hub->destination car leg — the real destination, never invented. Omit otherwise.",
                    },
                    "total_price_pkr": {
                        "type": "number",
                        "description": (
                            "Price from the shown option as a PLAIN number (46784, never 5848*8). "
                            "Advisory — the server re-derives the authoritative price."
                        ),
                    },
                    "selected_option": {"type": "string", "description": "Short label of the chosen option"},
                    "next_step": {
                        "type": "string",
                        "description": (
                            "Only if something remains AFTER this checkout: one plain sentence, "
                            "no price, no reference number. Omit for a single booking or when "
                            "every piece is prepared in this same turn."
                        ),
                    },
                },
                "required": ["booking_type"],
            },
        },
    },
]

# Tool name -> schema, so a turn can send only the tools it could plausibly need.
TOOL_SCHEMAS_BY_NAME: dict[str, dict] = {
    t["function"]["name"]: t for t in TOOL_SCHEMAS
}


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
    completeness. Returns a structured error if any of travel_date / check_in /
    check_out is unusable, already past, or (for a hotel) an inverted stay; else
    None. The caller must treat a non-None result as a hard stop: do not proceed
    to reprice_booking or a payment screen.
    """
    booking_data = booking_data if isinstance(booking_data, dict) else {}
    booking_type = str(booking_data.get("booking_type") or "")
    date_fields = _BOOKING_DATE_FIELDS.get(booking_type, [])

    # UNPARSEABLE dates are the dangerous case, and until now only the SEARCH
    # path checked for them. prepare_booking accepted anything non-empty, so a
    # model emitting a plausible-but-non-ISO date ("15-08-2026", "August 15,
    # 2026") slipped through every gate and _to_date silently substituted a
    # default N days out — repricing and booking a DIFFERENT day than the user
    # asked for, with the payment screen showing it as confirmed. Reusing the
    # same helper the search path already trusts keeps both paths in step.
    unusable = find_missing_date_error(booking_data, date_fields)
    if unusable:
        return unusable

    past = find_past_date_error(booking_data, date_fields)
    if past:
        return past

    # A stay that ends before it starts. _to_date/_exec_hotels quietly "repairs"
    # this to check_in + 2 nights, which would bill nights the user never chose.
    if booking_type == "hotel":
        ci = _parse_date_strict(booking_data.get("check_in"))
        co = _parse_date_strict(booking_data.get("check_out"))
        if ci and co and co <= ci:
            return {
                "error": "invalid_stay_dates",
                "check_in": ci.isoformat(),
                "check_out": co.isoformat(),
                "instruction": (
                    f"The check-out date ({co.isoformat()}) is not after the check-in "
                    f"date ({ci.isoformat()}), so the stay has no nights. Do NOT guess "
                    "or adjust the dates yourself — ask the user to confirm the correct "
                    "check-in and check-out dates."
                ),
            }
    return None




_CAR_VEHICLES = ("Sedan", "SUV", "Van")


_CAR_VEHICLE_PRICES: dict[str, int] = {"Sedan": 3000, "SUV": 6000, "Van": 9000}

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
                f"'{vehicle}' isn't a bookable vehicle. Offer only Sedan (PKR 3,000), SUV "
                "(PKR 6,000) or Van (PKR 9,000) and ask which one they'd like. Do not call "
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
    (route-aware via car_service.estimate_fare); book_standalone_car re-derives
    and sets the authoritative amount.
    """
    a = args or {}
    vehicle = str(a.get("vehicle_type") or "").strip()
    pickup = str(a.get("pickup_location") or "").strip()
    dropoff = str(a.get("dropoff_location") or "").strip()
    parsed = _parse_datetime_strict(a.get("pickup_datetime"))
    return {
        "booking_type": "car",
        "pickup_location": pickup,
        "dropoff_location": dropoff,
        "vehicle_type": vehicle,
        "pickup_datetime": parsed.isoformat() if parsed else str(a.get("pickup_datetime") or "").strip(),
        "price_pkr": _estimate_car_fare(vehicle, pickup, dropoff),
    }

_CAR_VEHICLE_RE = re.compile(r"\b(?:sedan|suv|van)\b", re.IGNORECASE)


_CLOCK_TIME_RE = re.compile(
    r"\b\d{1,2}:\d{2}\b"                                   # 10:00, 3:30
    r"|\b\d{1,2}\s*(?:a\.?m\.?|p\.?m\.?)\b"                # 3pm, 10 a.m.
    r"|\b(?:morning|afternoon|evening|noon|midnight|midday|dawn|dusk)\b",
    re.IGNORECASE,
)


_LOC_STOPWORDS: frozenset[str] = frozenset({
    "the", "near", "from", "drop", "pick", "pickup", "dropoff", "please",
    "road", "street", "avenue", "block", "sector", "phase", "town", "city",
})

_CAR_INTENT_RE = re.compile(r"\b(?:car|ride|driver|cab|taxi|sedan|suv|van)\b", re.IGNORECASE)

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
    "vehicle": "which vehicle they'd like — Sedan (PKR 3,000), SUV (PKR 6,000) or Van (PKR 9,000)",
    "time": "what date and time they want to be picked up",
}


def get_car_provenance_error(args: dict, user_texts: list[str]) -> dict | None:

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

            "airline": getattr(seg, "carrier_name", None) or seg.carrier_code,
            "from": seg.departure_airport,
            "to": seg.arrival_airport,
            "depart": seg.departure_time.strftime("%Y-%m-%d %H:%M"),
            "arrive": seg.arrival_time.strftime("%H:%M"),
            "cabin": seg.cabin_class,
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

def _no_availability_note(kind: str, where: str, when: str) -> str:
    return (
        f"NO AVAILABILITY: the live search returned ZERO {kind} for {where} on {when}. "
        f"Tell the user plainly and specifically that there are no {kind} for that route "
        f"on that date — name the date. Do NOT invent, recall from memory, or estimate "
        f"any {kind[:-1]}, price or timing, and do NOT silently search a different date, "
        f"route or city. Offer concrete next steps instead: check a nearby date, or a "
        f"different departure city / mode of travel, and ask which they'd like."
    )

def _filter_by_budget(items: list[dict], price_key: str, budget) -> tuple[list[dict], str | None]:
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

def _as_text(value) -> str:
    """Coerce a model-supplied value to a string. Tool-call arguments are
    model-authored JSON, so a field typed as a city/name can arrive as a number,
    list or dict; coercing here keeps every caller safe instead of relying on
    each one to guard its own arguments."""
    return value if isinstance(value, str) else ("" if value is None else str(value))


def _is_pakistani_place(name: str) -> bool:
    """
    Deterministic backstop for Travello's domestic-only scope.

    A place is treated as Pakistani if any domestic dataset knows it — the hotel
    city aliases cover ~45 places including non-airport towns (Hunza, Murree,
    Naran), so this stays true for somewhere like Skardu while being false for
    Dubai or London.
    """
    n = _as_text(name).strip().lower()
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
    candidate = _as_text(name).strip().lower()
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
        hubs = hub_options_for(city)
        if hubs:
            names = " or ".join(h.hub_city for h in hubs)
            return {"error": f"No domestic airport at '{city}'. Nearest real hub(s): {names} — "
                             f"search flights/trains there, then use book_car for the road leg "
                             f"to {city}."}
        return {"error": f"No domestic airport at '{city}'. It may be reachable only by "
                         f"road or via a nearby airport (e.g. Hunza via Gilgit)."}
    return {"error": f"'{city}' is outside Pakistan. Travello covers domestic Pakistan "
                     f"travel only — there is no international inventory to search. Tell "
                     f"the user this plainly and offer a domestic alternative instead."}


async def _exec_flights(args: dict) -> dict:
    # str() guard: tool-call arguments are model-authored JSON, so a city can
    # arrive as a non-string (e.g. {"origin_city": ["Lahore"]}). Without this the
    # .strip() raises, execute_tool converts it into "the search is temporarily
    # unavailable", and a perfectly valid request looks like an outage.
    origin = str(args.get("origin_city") or "").strip()
    dest = str(args.get("destination_city") or "").strip()
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
    flights = _serialize_flights(offers) if offers else []
    if not flights:
        return {
            "flights": [],
            "available_count": 0,
            "search_date": d.isoformat(),
            "note": _no_availability_note(
                "flights", f"{origin.title()} -> {dest.title()}", d.isoformat()
            ),
        }
    # total_price_pkr is the whole-party fare. Surface the per-seat figure too so
    # the model can quote either without ever multiplying the party total again.
    for f in flights:
        total = f.get("total_price_pkr") or 0
        f["price_per_seat_pkr"] = round(total / pax) if pax else total
    # Spell out, in words, what these numbers cover. The model previously quoted a
    # ONE-seat fare as "the cheapest option ... for the whole party" for a 2-adult
    # trip, and the price then doubled at booking (where the real party size is
    # priced). Stating the basis deterministically removes the room to mislabel it.
    result = {
        "search_date": d.isoformat(),
        "passengers": pax,
        "fare_basis": (
            f"This search priced {pax} seat(s). total_price_pkr is the fare for "
            f"{pax} passenger(s); price_per_seat_pkr is per person. Quote these as "
            f"'for {pax} passenger(s)' — do NOT call it the whole-party total unless "
            f"the party really is {pax}. If the group size differs, re-run "
            f"search_flights with the correct `passengers` first: booking prices the "
            f"real party size, so quoting the wrong basis makes the total jump later."
        ),
        # See _exec_hotels: the serializer sends the top few, so "show me more"
        # would otherwise re-render the identical list.
        "total_found": len(offers),
        "flights": flights,
    }
    flights, note = _filter_by_budget(flights, "total_price_pkr", args.get("max_budget_pkr"))
    result["flights"] = flights
    if note:
        result["budget_note"] = note
    return result


async def _exec_trains(args: dict) -> dict:
    # See _exec_flights — the model can emit a non-string city.
    origin = str(args.get("origin_city") or "").strip()
    dest = str(args.get("destination_city") or "").strip()
    d = _to_date(args.get("travel_date"))
    pax = _as_count(args.get("passengers"), default=1) or 1
    resp = await asyncio.to_thread(search_trains, origin, dest, d, pax)
    result = _serialize_trains(resp)
    result["search_date"] = d.isoformat()
    result["passengers"] = pax
    # Same posture as _exec_flights: an empty result must SAY it's empty. Pakistan
    # Railways doesn't serve the far north at all, so this is a routine outcome,
    # not a failure — and the model must relay it instead of recalling a train.
    if not result.get("trains"):
        result["available_count"] = 0
        result["note"] = _no_availability_note(
            "trains", f"{origin.title() or '—'} -> {dest.title() or '—'}", d.isoformat()
        )
        return result
    # Same anti-mislabel guard as _exec_flights — state what the fare covers.
    result["fare_basis"] = (
        f"This search priced {pax} seat(s). Each class's total_price_pkr is the fare "
        f"for {pax} passenger(s); price_per_seat_pkr is per person. Quote these as "
        f"'for {pax} passenger(s)'. If the group size differs, re-run search_trains "
        f"with the correct `passengers` before quoting or booking."
    )
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
    # See _exec_flights — the model can emit a non-string city.
    city = str(args.get("city") or "").strip()
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
        # How many the search actually found, versus how many are listed here.
        # Without this the model cannot answer "show me more options": the
        # serializer sends the top few, so re-searching returns the identical
        # set and the same list gets rendered twice, which reads as a stuck bot.
        # Knowing 20 exist lets it offer a real narrowing (cheaper, an area, a
        # star rating) instead — and max_budget_pkr makes that actionable.
        "total_found": len(resp.hotels or []),
        "hotels": hotels,
    }
    # Same posture as _exec_flights/_exec_trains — an empty result must say so
    # rather than leaving the model to fill the gap with a remembered hotel.
    if not hotels:
        result["available_count"] = 0
        result["note"] = _no_availability_note(
            "hotels", city.title() or "that city",
            f"{ci.isoformat()} to {co.isoformat()}",
        )
        return result
    if note:
        result["budget_note"] = note
    return result


async def _exec_weather(args: dict) -> dict:
    # str() guard: a model can emit a non-string city (e.g. {"city": 123}) in its
    # tool-call JSON; coerce so .strip() never raises on the safety-adjacent path.
    city = str(args.get("city") or "").strip()
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

    # str() guard: the model can emit a non-string city (e.g. {"city": 123}) in its
    # tool-call JSON; coerce so .strip() never raises on this safety-critical path.
    city = str(args.get("city") or "").strip()
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
    booking_data = booking_data if isinstance(booking_data, dict) else {}
    booking_type = str(booking_data.get("booking_type") or "")
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


# ── Already-paid guard ───────────────────────────────────────────────────────
#
# A booking that has been PAID for is finished: it has a PNR, a charge on a
# card, and a confirmation email. Putting it into a second prepare_booking
# bills the user again for something they already own.
#
# This is not hypothetical. Right after paying for a Karachi→Lahore flight,
# "now i want driver at lahore airport" produced a fresh summary containing
# that same flight PLUS the car, totalling the fare a second time — because
# prepare_booking carries transfer_* fields and the model reached for them
# instead of book_car.
#
# The signal is the app's own confirmation milestone, which the Flutter client
# writes back into the conversation (ApiClient.saveAgentNote), matched to the
# summary immediately before it — the summary is where the route and date live.
# Both are produced by our own formatters, so the shapes are ours, not a
# model's prose.

_CONFIRMED_RE = re.compile(r"(?:booking|package)\s+confirmed|\*\*PNR:\*\*", re.I)
_SUMMARY_RE = re.compile(r"\*\*Booking Summary\*\*|\*\*Your Package\*\*", re.I)
_ISO_DATE_RE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
# "**Flight:** Karachi → Lahore" and the package form
# "1. ✈️ **Flight:** Lahore → Karachi, 2026-08-20 — **PKR 21,210**".
# The comma stops the destination capture so the package form yields a city.
_ROUTE_LINE_RE = re.compile(
    r"\*\*(Flight|Train):\*\*\s*([^\n*,]+?)\s*(?:→|->)\s*([^\n*,]+)", re.I)
_HOTEL_LINE_RE = re.compile(r"\*\*Hotel:\*\*\s*([^\n*,]+)", re.I)
_DATE_LINE_RE = re.compile(r"\*\*(?:Date|Check-in):\*\*\s*(\d{4}-\d{2}-\d{2})", re.I)


def _components_in_summary(text: str) -> list[dict]:
    """Pull (type, route/name, date) out of one of our own rendered summaries."""
    out: list[dict] = []
    lines = (text or "").splitlines()
    for i, line in enumerate(lines):
        route = _ROUTE_LINE_RE.search(line)
        hotel = None if route else _HOTEL_LINE_RE.search(line)
        if not route and not hotel:
            continue
        # A package puts the date on the same line; a single booking puts it on
        # the next one or two. Stop at the following component so one leg can
        # never borrow another leg's date.
        same_line = _ISO_DATE_RE.search(line)
        date = same_line.group(1) if same_line else ""
        if not date:
            for nxt in lines[i + 1:i + 4]:
                if _ROUTE_LINE_RE.search(nxt) or _HOTEL_LINE_RE.search(nxt):
                    break
                found = _DATE_LINE_RE.search(nxt)
                if found:
                    date = found.group(1)
                    break
        # Both branches are tested explicitly rather than leaving the second as a
        # bare `else`. It would be provably reachable only with a hotel match —
        # the `continue` above sees to that — but "provably" there means reading
        # two branches and a guard, and the reader is being asked to trust that a
        # regex result is non-None before calling .group on it.
        if route:
            out.append({
                "booking_type": route.group(1).lower(),
                "origin": route.group(2).strip(),
                "destination": route.group(3).strip(),
                "travel_date": date,
            })
        elif hotel:
            out.append({
                "booking_type": "hotel",
                "hotel_name": hotel.group(1).strip(),
                "check_in": date,
            })
    return out


def confirmed_components(history: list[dict] | None) -> list[dict]:
    """
    Every component this conversation has already PAID for.

    Walks forward remembering the most recent summary; when a confirmation
    milestone appears, that summary is what was just paid for.
    """
    out: list[dict] = []
    pending = ""
    for m in history or []:
        if (m.get("role") or "").lower() != "assistant":
            continue
        text = m.get("content")
        if not isinstance(text, str):
            continue
        if _SUMMARY_RE.search(text):
            pending = text
            continue
        if _CONFIRMED_RE.search(text) and pending:
            out.extend(_components_in_summary(pending))
            pending = ""
    return out


def _same_component(booked: dict, proposed: dict) -> bool:
    """
    Conservative equality: every part must be present on BOTH sides and match.

    Deliberately strict. A false positive refuses a booking the user is
    entitled to make, so a missing date or a blank city means "not the same"
    and the booking proceeds through the normal gates.

    Uses the module's existing `_norm` (defined further down with the repricing
    helpers) rather than a second copy — two spellings of "casefold and strip"
    is exactly how the two drift apart later.
    """
    kind = booked.get("booking_type")
    if kind != proposed.get("booking_type"):
        return False
    if kind == "hotel":
        name = _norm(booked.get("hotel_name"))
        other = _norm(proposed.get("hotel_name")) or _norm(proposed.get("destination"))
        if not (name and other and name == other):
            return False
        return bool(booked.get("check_in")) and booked.get("check_in") == proposed.get("check_in")
    for field_name in ("origin", "destination"):
        mine = _norm(booked.get(field_name))
        if not mine or mine != _norm(proposed.get(field_name)):
            return False
    return bool(booked.get("travel_date")) and booked.get("travel_date") == proposed.get("travel_date")


def get_already_booked_error(booking_data: dict, history: list[dict] | None) -> dict | None:
    """
    Refuse a prepare_booking for something this conversation already paid for.

    Returns a structured error naming what is already owned, or None. This is a
    REFUSAL gate: it can only ever stop a commit, never create one.
    """
    bd = booking_data if isinstance(booking_data, dict) else {}
    for booked in confirmed_components(history):
        if _same_component(booked, bd):
            return {
                "error": "already_booked",
                "component": {k: v for k, v in booked.items() if v},
                "instruction": (
                    "This exact booking is ALREADY BOOKED AND PAID FOR earlier in "
                    "this same conversation — it has a PNR and the card was already "
                    "charged. Putting it into another booking or a package would "
                    "charge the traveller a second time for something they already "
                    "own. Do NOT include it again. If they asked for a car or a "
                    "ride, use book_car for a standalone ride instead. If they "
                    "asked for something genuinely new, prepare ONLY that new "
                    "piece. Tell them warmly that their existing booking is "
                    "unaffected and still confirmed."
                ),
            }
    return None


# ── Trip Planner completeness gate: a northern-destination package must
# finalize ALL required components together, never one at a time ────────────
#
# The bug this closes: a user planning a Hunza trip got shown flight options
# only — a hotel was never even searched — picked one, and the model turned
# that single flight into its own "Booking Summary" and Pay button, promising
# to book the hotel and car transfer "next". That is three separate charges
# for one trip, exactly what this feature exists to prevent. The ATOMIC
# PACKAGE GATE above cannot catch this on its own: it only defends a package
# that IS being assembled against coming up short against what the user
# picked THIS turn — it has no notion that a hotel (and, for a hub-less
# destination, a car transfer) belong in the trip at all when the model never
# searched for one. This gate supplies that notion directly, deterministically.

def get_trip_planner_incomplete_error(
    step_components: list[dict],
    history: list[dict] | None,
    trip_destination: str,
) -> dict | None:
    """
    None outside Trip Planner mode (trip_destination isn't a recognised
    northern destination — hub_options_for returns None), or once every
    required component type is covered by this turn's verified components
    plus whatever this same conversation has already paid for. Required:
    transport (flight/train) + hotel always; the car transfer too, for a
    destination with no airport/station of its own (Naran/Hunza/Swat — the
    only way to physically complete that leg). Otherwise a structured error:
    nothing may go to payment for only part of the trip.
    """
    if not step_components:
        return None
    hubs = hub_options_for(trip_destination) if trip_destination else None
    if hubs is None:
        return None  # not a recognised northern destination — ordinary booking

    have = list(step_components) + confirmed_components(history)
    transport = [c for c in have if c.get("booking_type") in ("flight", "train")]
    has_hotel = any(c.get("booking_type") == "hotel" for c in have)
    has_transfer = any(c.get("transfer_vehicle_type") for c in transport)

    missing = []
    if not transport:
        missing.append("transport to the hub")
    if not has_hotel:
        missing.append("a hotel")
    if hubs and not has_transfer:
        missing.append("the car transfer to the destination")
    if not missing:
        return None

    return {
        "error": "trip_planner_incomplete",
        "missing": missing,
        "instruction": (
            f"This is a {trip_destination} Trip Planner package, not an "
            f"individual booking — it still needs {', '.join(missing)}. Do "
            "NOT send what you have to payment. Search/gather the missing "
            "piece(s) now, let the user pick, then call prepare_booking for "
            "transport, hotel AND the transfer together in the SAME reply "
            "so the whole trip becomes one package with one payment."
        ),
    }


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


def get_transfer_error(
    booking_data: dict,
    *,
    user_texts: list[str] | None = None,
    trip_destination: str = "",
) -> dict | None:
    """
    Validate the optional car-transfer fields on a prepare_booking call.
    Returns a structured error dict (hard stop, like the date and count gates)
    or None when there is no transfer, or the transfer is properly specified.

    `user_texts`/`trip_destination` are optional and default to "no check" —
    every pre-existing call site that doesn't pass them behaves exactly as
    before this field was added.
    """
    bd = booking_data if isinstance(booking_data, dict) else {}
    vehicle = str(bd.get("transfer_vehicle_type") or "").strip()
    pickup = str(bd.get("transfer_pickup_location") or "").strip()
    dropoff = str(bd.get("transfer_dropoff_location") or "").strip()

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

    if dropoff:
        if _TRANSFER_PLACEHOLDER_RE.search(dropoff):
            return _transfer_error(
                f"'{dropoff}' is a placeholder, not a destination the user gave you.",
                "their actual destination",
            )
        texts = user_texts or []
        if not _location_grounded(dropoff, texts):
            return _transfer_error(
                f"'{dropoff}' as the transfer destination doesn't trace back to "
                "anything the user actually said.",
                "which destination the car is actually taking them to",
            )

    # Money-correctness: a hub->northern-destination leg priced without its
    # real dropoff would silently fall back to the flat in-city rate and
    # undercharge by tens of thousands of rupees, with no visible error.
    hubs = hub_options_for(trip_destination) if trip_destination else None
    if hubs:
        pickup_names_hub = any(_norm(h.hub_city) in _norm(pickup) for h in hubs)
        if pickup_names_hub and _norm(trip_destination) not in _norm(dropoff):
            return _transfer_error(
                f"This is a hub->{trip_destination} car leg, but the transfer's "
                "destination isn't set to (or doesn't match) "
                f"'{trip_destination}' — without it the fare defaults to the "
                "flat in-city rate instead of the real route fare.",
                f"confirmation that the car is going to {trip_destination}",
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
    """Coerce a model-supplied count to a non-negative int; None if unusable.

    A count of people must be a WHOLE number. int() would silently accept both
    2.5 (-> 2 travelers) and True (-> 1 traveler), quietly booking and pricing a
    party size the user never gave; both are rejected so the count gate asks
    instead of guessing.
    """
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return None
    if isinstance(value, float) and not value.is_integer():
        return None
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
    bd = booking_data if isinstance(booking_data, dict) else {}
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
            # Overwrite the airline with the matched live listing's own name,
            # exactly as _reprice_train already does for train_name. Until now
            # the model's guess survived onto the booking, the ticket and the
            # confirmation email — a fabricated travel-document detail.
            if f.get("airline"):
                verified["airline_or_train_name"] = f["airline"]
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
    well, or the same Sedan costs PKR 3,000 through the form and nothing through
    chat. Deliberately applied AFTER the per-type reprice so it stacks on the
    server-derived price and never on the model's advisory figure.

    The condition mirrors _agentTransferFacilities in ai_assistant.dart exactly:
    both vehicle and pickup must be present, because that is precisely when the
    app sends the transfer on to be booked. Charging on any looser condition
    would bill for a driver who is never dispatched.

    Priced via the same route-aware `estimate_fare` book_car already uses: a
    known hub<->northern-destination pickup/dropoff pair (e.g. Islamabad
    Airport -> Naran) gets the real route fare; everything else — an
    ordinary airport/station transfer — falls back to the flat rate exactly
    as before this function became dropoff-aware.
    """
    vehicle = str(verified.get("transfer_vehicle_type") or "").strip()
    pickup = str(verified.get("transfer_pickup_location") or "").strip()
    dropoff = str(verified.get("transfer_dropoff_location") or "").strip()
    if vehicle not in _CAR_VEHICLE_PRICES or not pickup:
        return verified
    fare = _estimate_car_fare(vehicle, pickup, dropoff)

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
