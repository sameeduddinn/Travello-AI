from __future__ import annotations
# =============================================================================
# PURPOSE: Turn free-text travel requests into structured data.
#
#   - detect_query_type        : classifies the user's intent
#   - extract_entities         : pulls dates / cities / counts / budget into a dict
#   - get_missing_fields       : returns required slots still missing per intent
#   - get_clarification_question : asks for ONE missing field at a time
#   - is_complete              : True when nothing required is missing
#
# Gemini is used for NLU; IATA mapping is a local lookup (no LLM cost).
# =============================================================================

import logging
import re
from datetime import date, timedelta
from typing import Any

from services.llm_service import generate_text, generate_json, GeminiError
from prompts.clarification import (
    CLARIFICATION_SYSTEM,
    CLARIFICATION_QUESTION_SYSTEM,
    ENTITY_EXTRACTION_PROMPT,
    CLARIFICATION_QUESTION_PROMPT,
    QUERY_CLASSIFICATION_PROMPT,
)

logger = logging.getLogger(__name__)


# IATA lookup — Pakistan domestic airports

CITY_TO_IATA: dict[str, str] = {
    "karachi": "KHI",
    "lahore": "LHE",
    "islamabad": "ISB",
    "rawalpindi": "RWP",
    "skardu": "SKD",
    "gilgit": "GIL",
    "peshawar": "PEW",
    "multan": "MUX",
    "quetta": "UET",
    "faisalabad": "LYP",
    "sialkot": "SKT",
    "bahawalpur": "BHV",
    "sukkur": "SWN",
}


# Constants

_VALID_QUERY_TYPES: set[str] = {
    "trip_planning",
    "flight_booking",
    "train_booking",
    "hotel_search",
    "weather",
    "recommendation",
    "healthcare",
    "car_booking",
    "general",
}

# Required slots per intent (in clarification-ask order).
# Deliberately minimal: travelers defaults to 1, budget to a sensible value,
# duration to 3 — asking for those up front feels like an interrogation. We only
# require what we genuinely cannot guess. Everything else is defaulted downstream.
_REQUIRED_FIELDS: dict[str, list[str]] = {
    "trip_planning":  ["destination", "duration_days"],
    "flight_booking": ["origin", "destination", "travel_date"],
    "train_booking":  ["origin", "destination", "travel_date"],
    "hotel_search":   ["destination", "check_in"],
    "weather":        ["destination"],
    "healthcare":     ["destination"],
}

# Human labels used when asking clarification questions
_FIELD_LABELS: dict[str, str] = {
    "destination":   "destination city",
    "origin":        "departure city",
    "duration_days": "trip duration in days",
    "travelers":     "number of travelers",
    "budget_pkr":    "total budget in PKR",
    "travel_date":   "travel date",
    "check_in":      "check-in date",
    "check_out":     "check-out date",
}


# Public API

async def detect_query_type(
    user_message: str,
    context_messages: list[dict] | None = None,
) -> str:
    """
    Classify the user's message into one of `_VALID_QUERY_TYPES`.
    Pass context_messages so follow-up queries (e.g. "tell me the temperature"
    after a weather discussion) are classified correctly.
    Falls back to 'general' on any error or unknown label.
    """
    today = date.today().isoformat()
    prompt = QUERY_CLASSIFICATION_PROMPT.format(
        today=today,
        query=user_message,
        context=_format_context(context_messages),
    )

    messages = [
        {"role": "system", "content": CLARIFICATION_SYSTEM},
        {"role": "user", "content": prompt},
    ]

    try:
        data = await generate_json(messages, temperature=0.1, max_output_tokens=256)
        intent = (data.get("primary_intent") or "").strip().lower()
        return _map_intent_to_query_type(intent)
    except (GeminiError, AttributeError, TypeError) as exc:
        logger.warning("detect_query_type failed: %s", exc)
        return "general"


def _format_context(messages: list[dict] | None) -> str:
    if not messages:
        return "(no previous context)"
    lines = []
    # Use last 8 messages so multi-turn slot values are visible to Gemini
    for m in (messages[-8:] if len(messages) > 8 else messages):
        role = (m.get("role") or "").capitalize()
        content = (m.get("content") or "")[:300]
        if role and content:
            lines.append(f"{role}: {content}")
    return "\n".join(lines) if lines else "(no previous context)"


async def extract_entities(
    user_message: str,
    context_messages: list[dict] | None = None,
) -> dict[str, Any]:
    """
    Extract travel entities into the canonical dict shape used downstream.
    Always returns the full key set — values default to None / sensible defaults.
    Pass context_messages (recent history) so follow-up queries resolve correctly.
    """
    extracted: dict[str, Any] = {
        "destination": None,
        "origin": None,
        "destination_iata": None,
        "origin_iata": None,
        "duration_days": None,
        "travelers": None,
        "budget_pkr": None,
        "travel_date": None,
        "check_in": None,
        "check_out": None,
        "travel_style": "standard",
        "vehicle_type": None,
        "cabin_class": "ECONOMY",
    }

    today = date.today().isoformat()
    prompt = ENTITY_EXTRACTION_PROMPT.format(
        today=today,
        message=user_message,
        context=_format_context(context_messages),
    )
    messages = [
        {"role": "system", "content": CLARIFICATION_SYSTEM},
        {"role": "user", "content": prompt},
    ]

    try:
        raw = await generate_json(messages, temperature=0.1, max_output_tokens=512)
        if not isinstance(raw, dict):
            raw = {}
    except GeminiError as exc:
        logger.warning("extract_entities Gemini call failed: %s", exc)
        raw = {}

    # Map Gemini's keys -> our canonical keys
    extracted["destination"]   = _norm_str(raw.get("destination_city"))
    extracted["origin"]        = _norm_str(raw.get("origin_city"))
    extracted["duration_days"] = _norm_int(raw.get("duration_days"))
    extracted["travelers"]     = _norm_int(raw.get("travelers"))
    extracted["budget_pkr"]    = _norm_num(raw.get("budget_pkr"))
    extracted["travel_date"]   = _norm_date(raw.get("travel_date"))
    extracted["check_in"]      = _norm_date(raw.get("check_in_date"))
    extracted["check_out"]     = _norm_date(raw.get("check_out_date"))

    # Safety net: if the LLM missed a relative date ("tomorrow", "next friday"),
    # resolve it deterministically from the raw message so it's never lost.
    if extracted["travel_date"] is None:
        rel = _parse_relative_date(user_message)
        if rel:
            extracted["travel_date"] = rel
    if extracted["check_in"] is None and extracted["travel_date"]:
        # For hotel queries the travel date is the check-in date.
        extracted["check_in"] = extracted["travel_date"]

    if (style := _norm_str(raw.get("hotel_type"))):
        # budget/mid-range/luxury -> budget/standard/luxury
        extracted["travel_style"] = {"mid-range": "standard"}.get(style, style)

    if (cabin := _norm_str(raw.get("travel_class"))):
        extracted["cabin_class"] = cabin.upper()

    # Local IATA lookup — cheaper and more reliable than asking the LLM.
    if extracted["destination"]:
        extracted["destination_iata"] = CITY_TO_IATA.get(extracted["destination"].lower())
    if extracted["origin"]:
        extracted["origin_iata"] = CITY_TO_IATA.get(extracted["origin"].lower())

    # If Gemini gave us its own IATA guesses and we didn't find one, accept them.
    if not extracted["destination_iata"] and (iata := _norm_str(raw.get("destination_iata"))):
        extracted["destination_iata"] = iata.upper()
    if not extracted["origin_iata"] and (iata := _norm_str(raw.get("origin_iata"))):
        extracted["origin_iata"] = iata.upper()

    return extracted


async def get_missing_fields(query_type: str, extracted: dict[str, Any]) -> list[str]:
    """
    Return required slots that are still None for this intent.
    Returns [] for intents with no required fields (general, recommendation, car_booking).
    """
    required = _REQUIRED_FIELDS.get(query_type, [])
    return [f for f in required if extracted.get(f) in (None, "", [])]


async def get_clarification_question(
    missing_fields: list[str],
    conversation_history: list[dict[str, str]],
) -> str:
    """
    Ask for ALL missing fields in ONE natural message — like a real travel agent
    ("Sure! Where are you flying from, and what date?") rather than a one-by-one
    interrogation. Falls back to a plain templated question if the LLM fails.
    """
    if not missing_fields:
        return ""

    labels = [_FIELD_LABELS.get(f, f) for f in missing_fields]
    missing_str = ", ".join(labels)

    prompt = CLARIFICATION_QUESTION_PROMPT.format(
        intent="continue your travel request",
        provided="(see conversation history)",
        missing=missing_str,
    )

    messages: list[dict[str, str]] = [{"role": "system", "content": CLARIFICATION_QUESTION_SYSTEM}]
    messages.extend(conversation_history or [])
    messages.append({"role": "user", "content": prompt})

    try:
        text = await generate_text(messages, temperature=0.6, max_output_tokens=128)
        return text.strip() or _fallback_question(missing_str)
    except GeminiError as exc:
        logger.warning("get_clarification_question failed: %s", exc)
        return _fallback_question(missing_str)


async def is_complete(query_type: str, extracted: dict[str, Any]) -> bool:
    """True iff no required fields are missing for this intent."""
    return not await get_missing_fields(query_type, extracted)


# Helpers

def _map_intent_to_query_type(intent: str) -> str:
    """Map QUERY_CLASSIFICATION_PROMPT intent vocab -> our 9 query types."""
    if intent in _VALID_QUERY_TYPES:
        return intent
    mapping = {
        "search_flights":    "flight_booking",
        "search_trains":     "train_booking",
        "search_hotels":     "hotel_search",
        "plan_trip":         "trip_planning",
        "check_weather":     "weather",
        "find_healthcare":   "healthcare",
        "get_recommendations": "recommendation",
        "make_booking":      "flight_booking",  # ambiguous — caller may refine
        "general_chat":      "general",
    }
    return mapping.get(intent, "general")


def _norm_str(v: Any) -> str | None:
    if v is None:
        return None
    s = str(v).strip()
    return s or None


def _norm_int(v: Any) -> int | None:
    try:
        if v is None or v == "":
            return None
        return int(v)
    except (ValueError, TypeError):
        return None


def _norm_num(v: Any) -> float | int | None:
    try:
        if v is None or v == "":
            return None
        f = float(v)
        return int(f) if f.is_integer() else f
    except (ValueError, TypeError):
        return None


def _norm_date(v: Any) -> str | None:
    """Accept a YYYY-MM-DD string and pass it through; reject anything else."""
    if not v:
        return None
    s = str(v).strip()
    try:
        date.fromisoformat(s)
        return s
    except ValueError:
        return None


_WEEKDAYS: dict[str, int] = {
    "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
    "friday": 4, "saturday": 5, "sunday": 6,
}


def _parse_relative_date(text: str, today: date | None = None) -> str | None:
    """
    Deterministically resolve common relative date phrases to YYYY-MM-DD.
    Returns None if nothing recognizable is present.

    The LLM is the primary date resolver; this is a safety net so that very
    common phrases ("tomorrow", "next friday", "in 3 days") are never silently
    lost when the model's date arithmetic slips.
    """
    if not text:
        return None
    t = text.lower()
    today = today or date.today()

    # Order matters: check the more specific phrase first.
    if "day after tomorrow" in t:
        return (today + timedelta(days=2)).isoformat()
    if "tomorrow" in t:
        return (today + timedelta(days=1)).isoformat()
    if "today" in t or "tonight" in t:
        return today.isoformat()

    m = re.search(r"\bin (\d{1,2}) days?\b", t)
    if m:
        return (today + timedelta(days=int(m.group(1)))).isoformat()

    if "weekend" in t:
        # Upcoming Saturday (or today if today is Saturday).
        days_ahead = (5 - today.weekday()) % 7
        return (today + timedelta(days=days_ahead)).isoformat()

    # Any weekday mention ("friday", "this friday", "next friday") → the nearest
    # UPCOMING occurrence. This is the least-surprising reading for a booking flow;
    # someone who truly means a week further out will give an explicit date.
    # If today IS that weekday, jump a full week ahead.
    for name, idx in _WEEKDAYS.items():
        if name in t:
            days_ahead = (idx - today.weekday()) % 7
            if days_ahead == 0:
                days_ahead = 7
            return (today + timedelta(days=days_ahead)).isoformat()

    if "next week" in t:
        return (today + timedelta(days=7)).isoformat()

    return None


def _fallback_question(label: str) -> str:
    """Used when Gemini is unavailable — keeps the agent responsive."""
    return f"Could you share the {label} so I can help you better?"
