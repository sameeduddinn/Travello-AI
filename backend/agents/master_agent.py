from __future__ import annotations
# =============================================================================
# PURPOSE: Top-level orchestrator for the multi-agent system.
#
#   process_message(user_id, conversation_id, user_message) is the ONLY
#   public entry point. It:
#       1. Loads memory + history
#       2. Classifies intent + extracts entities (in parallel)
#       3. Asks a clarification question if any required slot is missing
#       4. Computes fallback dates so specialist agents never get None
#       5. Routes to one or many specialist agents (parallel where possible)
#       6. Hands all agent output to Gemini to synthesize the final reply
#       7. Persists user + assistant messages
#       8. Fire-and-forget logs the work to agent_tasks
# =============================================================================

import asyncio
import json
import logging
import re
import time
import uuid
from datetime import datetime, timedelta, timezone

from agents.memory_agent import (
    get_user_memory,
    get_user_profile,
    get_conversation_history,
    save_message,
    save_turn,
    save_user_memory,
    start_new_conversation,  # re-exported for callers (router uses this)
)
from agents.clarification_agent import (
    detect_query_type,
    extract_entities,
    get_missing_fields,
    get_clarification_question,
    is_complete,  # re-exported
    _REQUIRED_FIELDS,  # for slot-filling from history
)
from agents.itinerary_agent import generate_itinerary
from agents.budget_agent import calculate_budget
from agents.hotel_agent import find_hotels
from agents.transport_agent import compare_transport
from agents.weather_agent import get_weather_intelligence
from agents.booking_agent import (
    present_booking_summary,
    extract_booking_from_history,
    format_booking_summary,
    format_car_booking_summary,
    build_package_data,
    format_package_summary,
    sanitize_next_step,
)
from agents.recommendation_agent import get_recommendations
from agents.healthcare_agent import get_safety_briefing
from agents import self_improvement

from core.pk_time import pk_today
from services.llm_service import generate_text, generate_with_tools, GeminiError, LLMError
from agents.agent_tools import (
    TOOL_SCHEMAS,
    get_missing_booking_fields,
    get_booking_count_error,
    get_booking_date_error,
    get_transfer_error,
    apply_traveler_totals,
    reprice_booking,
    missing_fields_result,
    offer_not_found_result,
    get_car_booking_error,
    get_car_provenance_error,
    build_car_booking_data,
    check_budget_feasibility,
    user_supplied_date_signal,
    recover_booking_location,
)
from prompts.master_agent import MASTER_SYSTEM, MASTER_AGENTIC_SYSTEM
from prompts.knowledge import get_relevant_facts, EMERGENCY_NUMBERS
from agents.emergency_healthcare import (
    is_medical_emergency,
    has_emergency_signal,
    looks_like_healthcare,
    build_emergency_reply,
)
from core.supabase_client import supabase_admin
from core.config import settings

logger = logging.getLogger(__name__)


# Map our query_type vocabulary -> the SQL CHECK constraint vocabulary
_QUERY_TYPE_TO_TASK_TYPE: dict[str, str] = {
    "trip_planning":  "plan_trip",
    "flight_booking": "search_flights",
    "train_booking":  "search_trains",
    "hotel_search":   "search_hotels",
    "weather":        "weather_check",
}


# Booking intent keywords — any of these in the message triggers extraction
_BOOKING_KEYWORDS: frozenset[str] = frozenset({
    # Direct booking commands
    "book", "reserve", "confirm booking", "i'll take", "ill take",
    "yes book", "go ahead", "proceed", "book it", "book this", "book that",
    "book option", "buy ticket", "purchase", "finalize", "i want to book",
    "make the booking", "book now", "book flight", "book train", "book hotel",
    "book the flight", "book the train", "book the hotel", "yes please book",
    "book first", "book second", "book option 1", "book option 2",
    # Option selection — user picking from a numbered list
    "flight 1", "flight 2", "flight 3", "flight 4", "flight 5",
    "flights 1", "flights 2", "flights 3",
    "flights number 1", "flights number 2", "flights number 3",
    "flight number 1", "flight number 2", "flight number 3",
    "option 1", "option 2", "option 3", "option 4",
    "train 1", "train 2", "train 3",
    "number 1", "number 2", "number 3",
    "first flight", "second flight", "third flight",
    "first train", "second train", "third train",
    "first option", "second option", "third option",
    "first one", "second one", "third one",
    "take the first", "take the second", "take option",
    "select flight", "select option", "choose flight", "choose this",
    "this flight", "that flight", "this train", "that train",
    "i want flight", "i want train", "i want option",
    # Payment choice words typed in chat (instead of tapping the button)
    "pay with card", "pay manually", "pay by card", "card payment",
    "pay now", "proceed to pay", "make payment", "complete payment",
})

# Phrases in assistant messages that indicate a booking confirmation was asked
_BOOKING_CONFIRM_PHRASES: frozenset[str] = frozenset({
    "are you sure you want to book",
    "shall i proceed",
    "confirm the booking",
    "want to book this",
    "proceed with the booking",
    "confirm your booking",
    "do you want to book",
    "should i book",
    "want me to book",
})

# Simple affirmatives the user might say after a confirmation question
_AFFIRMATIVES: frozenset[str] = frozenset({
    "yes", "yeah", "yep", "yup", "sure", "ok", "okay", "confirm",
    "correct", "right", "do it", "please", "please do it", "yes do it",
    "ha", "haan", "bilkul", "zaroor",
})


# Phrases that mean the booking is ALREADY done — cancel booking intent detection
_NOT_BOOKING_PHRASES: frozenset[str] = frozenset({
    "already booked", "already paid", "already confirmed", "already done",
    "you already booked", "you booked", "you have booked", "have already booked",
    "booking is confirmed", "booking confirmed", "was booked", "i booked",
    "already have a booking", "not booking", "don't book", "dont book",
    "cancel booking", "my bookings", "check booking", "view booking",
    "see booking", "show booking", "my booking",
})


def _is_booking_intent(message: str) -> bool:
    msg = message.lower()
    # Negative check first — "already booked", "you booked" etc. are NOT new bookings
    if any(phrase in msg for phrase in _NOT_BOOKING_PHRASES):
        return False
    # Positive check — single-word keywords use word-boundary so "booked" ≠ "book"
    for kw in _BOOKING_KEYWORDS:
        if ' ' in kw:
            if kw in msg:
                return True
        else:
            if re.search(r'\b' + re.escape(kw) + r'\b', msg):
                return True
    return False


def _last_assistant_asked_booking_confirm(history: list[dict]) -> bool:
    """True if the last assistant message asked a booking confirmation question."""
    for msg in reversed(history):
        if (msg.get("role") or "").lower() == "assistant":
            content = (msg.get("content") or "").lower()
            # Skip obviously corrupted messages
            if content.startswith("{"):
                continue
            return any(phrase in content for phrase in _BOOKING_CONFIRM_PHRASES)
    return False


def _is_affirmative(message: str) -> bool:
    msg = message.lower().strip().rstrip("!").rstrip(".")
    return msg in _AFFIRMATIVES


# ── Deterministic "pick from the list" resolution (agentic path) ──────────────
#
# When the user answers a numbered list with just "6", "option 6", or "the sixth
# one", the model otherwise has to re-derive which item that was by re-reading the
# whole history — and on the free tier that extra reasoning is exactly what makes a
# selection turn thrash (re-search, re-ask) and run out of the turn's time budget,
# surfacing to the user as the "trouble responding" / "taking longer" messages. We
# resolve the pick in code and hand the model ONE unambiguous line so it converges
# in a single prepare_booking call. This is only a NUDGE: every booking gate
# (missing fields, date, party size) and the server-side reprice still run — a bad
# guess can't misbook, it just falls through to the model asking.
_SELECTION_ORDINALS = {
    "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
    "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
}


def _as_text(value) -> str:
    """Coerce any value to a string for the pure text helpers below.

    These read model output and stored conversation content; a non-string there
    would raise inside a regex and lose an otherwise fine turn. Coercing at the
    function boundary keeps every call site safe.
    """
    return value if isinstance(value, str) else ("" if value is None else str(value))


def _selected_index(message: str) -> int | None:
    """The 1-based list position the user is picking, or None if it isn't a pick."""
    msg = _as_text(message).lower().strip()
    # Bare number, optionally prefixed/suffixed: "6", "6.", "#6", "option 6"
    m = re.fullmatch(r"(?:option|number|no\.?|#|item)?\s*(\d{1,2})[.!)]?", msg)
    if m:
        return int(m.group(1))
    # 'option 6', 'i select option 6', 'flight 2', 'hotel 3', 'choice 4'
    m = re.search(
        r"\b(?:option|number|no|#|item|flight|train|hotel|bus|car|choice)\s*#?\s*(\d{1,2})\b",
        msg,
    )
    if m:
        return int(m.group(1))
    # verb + trailing number ("i'll take 2", "go with 3", "book 6"), anchored to
    # end so "take 2 rooms" / "book 3 nights" are NOT misread as a list pick.
    m = re.search(
        r"\b(?:take|pick|choose|select|book|go with|want|get|reserve)\s+"
        r"(?:option\s+|number\s+|the\s+)?(\d{1,2})\s*[.!]?\s*$",
        msg,
    )
    if m:
        return int(m.group(1))
    for word, idx in _SELECTION_ORDINALS.items():
        if re.search(r"\b" + word + r"\b", msg):
            return idx
    return None


def _numbered_list_items(text: str) -> dict[int, str]:
    """Best-effort parse of '1. Foo' / '1) Foo' / '| 1 | Foo |' rows -> {index: label}."""
    items: dict[int, str] = {}
    for line in _as_text(text).splitlines():
        s = line.strip()
        # Markdown table row: | 6 | Hermes Urban Stay | ... |  (skip separator rows)
        m = re.match(r"\|?\s*(\d{1,2})\s*\|\s*([^|]+?)\s*(?:\||$)", s)
        if m and not set(m.group(2).strip()) <= {"-", " ", ":"}:
            items.setdefault(int(m.group(1)), m.group(2).strip())
            continue
        # Numbered/prefixed list: '6. Hermes' / '6) Hermes' / '6 - Hermes' / '6: Hermes'
        m = re.match(r"(\d{1,2})\s*[.)\-:]\s+(.+)", s)
        if m:
            items.setdefault(int(m.group(1)), m.group(2).strip())
    return items


# A round trip shows TWO numbered lists in one reply (outbound, then return), and
# the user picks from both at once — "option 1, option 1" / "1 for outbound, 1 for
# return". _selected_index returns only the FIRST number, so the hint below used to
# name the outbound flight and say "Book THAT exact option", pushing the model to
# book one leg when two were asked for. These find every pick in the message.
_PICK_KEYWORD_RE = re.compile(
    r"\b(?:option|number|no|#|item|flight|train|hotel|choice)\s*#?\s*(\d{1,2})\b", re.I
)
_PICK_LEG_RE = re.compile(
    r"\b(\d{1,2})\s+for\s+(?:the\s+)?"
    r"(?:outbound|return|inbound|onward|departing|returning|first|second)\b",
    re.I,
)


def _selected_indices(message: str) -> list[int]:
    """Every list position the user picked, in order. [] when it isn't a multi-pick."""
    message = _as_text(message)
    for pattern in (_PICK_KEYWORD_RE, _PICK_LEG_RE):
        picks = [int(m.group(1)) for m in pattern.finditer(message)]
        if len(picks) >= 2:
            return picks
    return []


# An offer list's labels are short identifiers ("PA-180", "Serena Hotel"); a
# trailing "Next steps: 1. Choose your outbound flight…" list is full sentences.
# Only offer lists may be paired with a pick, so a second pick can never be
# resolved against instructional prose.
_OFFER_LABEL_MAX = 60


def _numbered_lists(text: str) -> list[dict[int, str]]:
    """The numbered lists in `text`, in order — a restart in numbering starts a new one."""
    lists: list[dict[int, str]] = []
    current: dict[int, str] = {}
    last_idx = 0
    for line in _as_text(text).splitlines():
        s = line.strip()
        idx: int | None = None
        label = ""
        m = re.match(r"\|?\s*(\d{1,2})\s*\|\s*([^|]+?)\s*(?:\||$)", s)
        if m and not set(m.group(2).strip()) <= {"-", " ", ":"}:
            idx, label = int(m.group(1)), m.group(2).strip()
        else:
            m = re.match(r"(\d{1,2})\s*[.)\-:]\s+(.+)", s)
            if m:
                idx, label = int(m.group(1)), m.group(2).strip()
        if idx is None:
            continue
        if idx <= last_idx:          # numbering restarted → a new list began
            if current:
                lists.append(current)
            current = {}
        current.setdefault(idx, label)
        last_idx = idx
    if current:
        lists.append(current)
    return lists


def _offer_lists(text: str) -> list[dict[int, str]]:
    """Only the numbered lists that look like pickable offers."""
    return [
        lst for lst in _numbered_lists(text)
        if len(lst) >= 2 and all(len(v) <= _OFFER_LABEL_MAX for v in lst.values())
    ]


def _selection_hint(user_message: str, history: list[dict]) -> str | None:
    """
    A one-line nudge naming the exact list item(s) the user just picked, or None.
    Scans the most recent assistant message that actually CONTAINS a numbered
    list, so a bare "6" answering "how many passengers?" (no list) is ignored.
    """
    picks = _selected_indices(user_message)
    idx = _selected_index(user_message)
    if not picks and idx is None:
        return None
    for m in reversed(history):
        if (m.get("role") or "").lower() != "assistant":
            continue
        content = m.get("content") or ""

        # Multi-pick (round trip): pair pick #1 with the first offer list, pick #2
        # with the second, and tell the model to prepare BOTH. Two prepared
        # components become one package_choice — one passenger form, one payment.
        if len(picks) >= 2:
            lists = _offer_lists(content)
            if not lists and not _numbered_list_items(content):
                continue     # no list in this message at all — keep scanning back
            if len(lists) < len(picks):
                return None  # can't pair confidently — no hint beats a wrong one
            chosen: list[str] = []
            for pick, lst in zip(picks, lists):
                label = lst.get(pick)
                if not label:
                    return None
                chosen.append(label.strip(" *`").strip())
            named = "; ".join(
                f'#{p} from list {i + 1} ("{lbl}")'
                for i, (p, lbl) in enumerate(zip(picks, chosen))
            )
            return (
                f"The user is picking one item from EACH numbered list you just showed: "
                f"{named}. They want ALL of them. Call prepare_booking once for EVERY one "
                f"of those options, in this SAME reply — one call per list — reusing the "
                f"route, dates, class and traveller count already established earlier in "
                f"this conversation. Do NOT search again, do NOT book only the first one, "
                f"and do NOT ask them to re-enter details they already gave."
            )

        items = _numbered_list_items(content)
        if not items:
            continue
        if idx is None:
            return None
        label = items.get(idx)
        if not label:
            return None  # picked a number the list doesn't have — let the model ask
        label = label.strip(" *`").strip()
        return (
            f'The user is choosing item #{idx} from the numbered list you just showed: '
            f'"{label}". Book THAT exact option — call prepare_booking for it now, reusing '
            f'the route/city, dates, class and traveller count already established earlier '
            f'in this conversation. Do NOT search again and do NOT ask them to re-enter '
            f'details they already gave. Only if a required detail (like the travel date) '
            f'was genuinely never provided, ask for that one thing.'
        )
    return None


def _booking_data_is_valid(bd: dict | None) -> bool:
    """
    Guard against showing a 'Pay with Card' summary built from hallucinated or
    half-empty extraction. We only proceed to payment if the booking has BOTH a
    concrete subject (a destination/hotel) AND a concrete option signal (a price,
    a named flight/train/hotel, or an explicitly selected option).

    If this returns False the turn falls through to normal handling — i.e. we
    search and show real options instead of inventing a booking.
    """
    if not bd or not bd.get("booking_type"):
        return False

    has_subject = bool(bd.get("destination") or bd.get("hotel_name"))
    has_option_signal = bool(
        bd.get("total_price_pkr")
        or bd.get("selected_option")
        or bd.get("flight_number")
        or bd.get("train_name")
        or bd.get("hotel_name")
        or bd.get("airline_or_train_name")
    )
    return has_subject and has_option_signal


def _format_memory(memory: dict, profile: dict) -> str:
    """Format user profile + preferences into a single prompt-injection string."""
    parts: list[str] = []

    # Always inject the user's real name so the agent uses it naturally
    name = profile.get("display_name") or ""
    if name:
        parts.append(f"User's name: {name}")

    if memory:
        # NOTE: past_destinations is deliberately NOT injected. It is user-level
        # (spans every conversation), and surfacing an earlier chat's destination
        # here made the model invent demo searches to a place the user never named
        # in the current chat — a cross-conversation bleed. Home city + stable
        # preferences are safe to personalise with; a prior destination is not.
        parts.append(
            f"Travel preferences: home city={memory.get('origin_city')}, "
            f"preferred class={memory.get('preferred_class')}, "
            f"travel style={memory.get('travel_style')}, "
            f"companion type={memory.get('companion_type')}, "
            f"budget style={memory.get('budget_style')}"
        )

    return " | ".join(parts) if parts else ""


# Slot accumulation — fill missing entity fields from conversation history

async def _fill_slots_from_history(
    extracted: dict,
    history: list[dict],
    query_type: str,
) -> dict:
    """
    If required slots are still None after extracting from the current message,
    re-run entity extraction on the full recent history as input so Gemini can
    find values mentioned in previous turns.

    One extra LLM call — only triggered when slots are missing, which is exactly
    the scenario where it pays off (preventing an unnecessary clarification round).
    """
    missing = [
        f for f in _REQUIRED_FIELDS.get(query_type, [])
        if extracted.get(f) is None
    ]
    if not missing or not history:
        return extracted

    # Feed the full recent history to extract_entities as a plain text block
    history_text = "\n".join(
        f"{m['role'].upper()}: {(m.get('content') or '')[:300]}"
        for m in history[-10:]
    )
    try:
        history_extracted = await extract_entities(history_text, context_messages=None)
        for field in missing:
            val = history_extracted.get(field)
            if val is not None:
                extracted[field] = val
    except Exception as exc:
        logger.debug("_fill_slots_from_history failed (non-fatal): %s", exc)

    return extracted


def _fill_slots_from_memory(extracted: dict, memory: dict) -> dict:
    """
    Fill blank entity slots from the user's saved preferences. This is what makes
    the assistant feel like it *remembers* you: a returning user who always flies
    from Karachi never gets asked "where are you departing from?" again.

    Rules:
      - Only ever fills a slot that is currently blank (None / "" / default).
      - An explicit value in the current message ALWAYS wins — never overwritten.
    """
    if not memory:
        return extracted

    # Home city → origin (the field that otherwise triggers an annoying question)
    if not extracted.get("origin") and memory.get("origin_city"):
        extracted["origin"] = memory["origin_city"]

    # Preferred cabin class — only override the ECONOMY default, never an explicit pick
    if memory.get("preferred_class") and (extracted.get("cabin_class") in (None, "", "ECONOMY")):
        extracted["cabin_class"] = str(memory["preferred_class"]).upper()

    # Travel style — only override the "standard" default
    if memory.get("travel_style") and (extracted.get("travel_style") in (None, "", "standard")):
        extracted["travel_style"] = memory["travel_style"]

    return extracted


# Preference learning — fire-and-forget after each successful turn

async def _auto_save_preferences(user_id: str, extracted: dict, travelers: int) -> None:
    """
    Learn and persist user preferences from each successful interaction.
    Only updates fields we can infer with confidence. Never raises.
    """
    updates: dict = {}

    if extracted.get("origin"):
        updates["origin_city"] = extracted["origin"]

    cabin = (extracted.get("cabin_class") or "").upper()
    if cabin in ("ECONOMY", "BUSINESS", "FIRST"):
        updates["preferred_class"] = cabin.title()

    style = extracted.get("travel_style")
    if style in ("budget", "standard", "luxury"):
        updates["travel_style"] = style

    budget = extracted.get("budget_pkr")
    duration = extracted.get("duration_days") or 3
    if budget:
        daily = budget / max(duration, 1)
        if daily < 5000:
            updates["budget_style"] = "budget"
        elif daily < 15000:
            updates["budget_style"] = "standard"
        else:
            updates["budget_style"] = "luxury"

    if travelers == 1:
        updates["companion_type"] = "solo"
    elif travelers == 2:
        updates["companion_type"] = "couple"
    elif travelers >= 3:
        updates["companion_type"] = "family"

    if not updates:
        return

    try:
        existing = await get_user_memory(user_id)
        # Don't overwrite values already set unless we have a conflicting signal —
        # only write fields the user hasn't saved yet or that changed.
        final = {k: v for k, v in updates.items() if not existing.get(k)}

        # past_destinations: always append new destination without overwriting list
        dest = extracted.get("destination")
        if dest:
            past = list(existing.get("past_destinations") or [])
            if dest not in past:
                past.append(dest)
                final["past_destinations"] = past

        if final:
            await save_user_memory(user_id, final)
    except Exception as exc:
        logger.debug("_auto_save_preferences failed (non-fatal): %s", exc)


# Conversation title — auto-set after intent is resolved

async def _update_conversation_title(
    conversation_id: str,
    query_type: str,
    destination: str,
    origin: str,
) -> None:
    """
    Replace the generic "New Conversation" title with something meaningful once
    we know what the user actually wants. Fire-and-forget — never raises.
    """
    try:
        _TYPE_LABELS = {
            "trip_planning":  "Trip Plan",
            "flight_booking": "Flight",
            "train_booking":  "Train",
            "hotel_search":   "Hotels",
            "weather":        "Weather",
            "healthcare":     "Healthcare",
            "recommendation": "Recommendations",
            "car_booking":    "Car Booking",
        }
        label = _TYPE_LABELS.get(query_type)
        if not label or query_type == "general":
            return

        if destination and origin and query_type in ("flight_booking", "train_booking"):
            title = f"{origin} → {destination} {label}"
        elif destination:
            title = f"{destination} — {label}"
        else:
            title = label

        def _update():
            supabase_admin.table("ai_conversations").update(
                {"title": title[:100]}
            ).eq("id", conversation_id).execute()

        await asyncio.to_thread(_update)
    except Exception as exc:
        logger.debug("_update_conversation_title failed (non-fatal): %s", exc)


# Public entry point

async def process_message(
    user_id: str,
    conversation_id: str,
    user_message: str,
) -> dict:
    """
    Run a single turn of the multi-agent conversation.
    Returns: {"response": str, "conversation_id": str}
    """
    # Step 1 — load user profile + memory + conversation history IN PARALLEL
    (memory, profile), history = await asyncio.gather(
        asyncio.gather(get_user_memory(user_id), get_user_profile(user_id)),
        get_conversation_history(conversation_id, limit=20),
    )
    memory_context = _format_memory(memory, profile)

    # Step 3 — classify intent + extract entities IN PARALLEL
    # Pass last 8 messages so follow-up queries and multi-turn context resolve correctly.
    recent = history[-8:] if history else None
    query_type, extracted = await asyncio.gather(
        detect_query_type(user_message, recent),
        extract_entities(user_message, recent),
        return_exceptions=True,
    )
    if isinstance(query_type, BaseException):
        query_type = "general"
    if isinstance(extracted, BaseException) or not isinstance(extracted, dict):
        extracted = {}

    # Step 4 — booking intent interception — MUST run before clarification check.
    # "book the flight" with missing travel_date must NOT ask for date — it should
    # extract all details from history and go straight to payment.
    is_booking = _is_booking_intent(user_message)
    # Also treat affirmative responses ("yes", "sure", etc.) as booking confirmation
    # when the last assistant message explicitly asked to confirm a booking.
    if not is_booking and history and _is_affirmative(user_message):
        is_booking = _last_assistant_asked_booking_confirm(history)

    if is_booking and history:
        booking_data = await extract_booking_from_history(user_message, history)
        # Only commit to a payment summary when the extracted booking is concrete.
        # Otherwise fall through so we search real options instead of faking one.
        if booking_data and _booking_data_is_valid(booking_data):
            summary = format_booking_summary(booking_data)
            await save_turn(
                conversation_id, user_id, user_message, summary,
                model_used=settings.GROQ_MODEL,
            )
            asyncio.ensure_future(
                _log_task(user_id, conversation_id, "booking", user_message, booking_data)
            )
            return {
                "response": summary,
                "conversation_id": conversation_id,
                "action": "payment_choice",
                "booking_data": booking_data,
            }

    # Step 3b — slot accumulation: fill missing required fields from history.
    # Runs BEFORE clarification so multi-turn conversations don't repeat questions.
    extracted = await _fill_slots_from_history(extracted, history, query_type)

    # Step 3c — personalization: fill blanks from the user's saved preferences so
    # we NEVER ask a returning user for things we already know (e.g. home city).
    # Only fills genuine blanks — an explicit value in the message always wins.
    extracted = _fill_slots_from_memory(extracted, memory)

    # Step 4b — clarification (ask for all still-missing fields in ONE message)
    # Only runs if NOT a booking intent (booking intent handled above).
    missing = await get_missing_fields(query_type, extracted)
    if missing:
        question = await get_clarification_question(missing, history)
        await save_message(conversation_id, user_id, "user", user_message)
        await save_message(conversation_id, user_id, "assistant", question)
        return {"response": question, "conversation_id": conversation_id}

    # Step 5 — compute fallback dates BEFORE routing
    today          = pk_today()
    travel_date    = extracted.get("travel_date")
    check_in       = extracted.get("check_in")
    check_out      = extracted.get("check_out")
    duration_days  = extracted.get("duration_days") or 3
    origin         = extracted.get("origin") or memory.get("origin_city") or "Karachi"
    destination    = extracted.get("destination") or ""
    travelers      = extracted.get("travelers") or 1
    budget_pkr     = extracted.get("budget_pkr") or 50000
    travel_style   = extracted.get("travel_style") or "standard"

    if check_in is None and travel_date is not None:
        check_in = travel_date
    if check_in is None:
        check_in = (today + timedelta(days=7)).isoformat()
    if check_out is None:
        ci = (
            datetime.strptime(check_in, "%Y-%m-%d").date()
            if isinstance(check_in, str) else check_in
        )
        check_out = (ci + timedelta(days=duration_days)).isoformat()

    # Step 6 — route to specialist agents
    combined_context = await _route_to_agents(
        query_type=query_type,
        origin=origin,
        destination=destination,
        travel_date=travel_date,
        check_in=check_in,
        check_out=check_out,
        travelers=travelers,
        duration_days=duration_days,
        budget_pkr=budget_pkr,
        travel_style=travel_style,
        memory=memory,
    )

    # Step 7 — final synthesis via Gemini
    facts = get_relevant_facts(user_message)
    user_turn_content = (
        f"{user_message}\n\n"
        f"Context from agents:\n{combined_context or '(no agent results)'}\n\n"
        f"User memory: {memory_context or '(no saved preferences)'}"
        + (f"\n\nGrounded facts — use these, don't contradict them:\n{facts}" if facts else "")
    )
    full_messages: list[dict[str, str]] = [{"role": "system", "content": MASTER_SYSTEM}]
    full_messages.extend(history)
    full_messages.append({"role": "user", "content": user_turn_content})

    try:
        final_response = await generate_text(full_messages, temperature=0.6, max_output_tokens=2048)
    except GeminiError as exc:
        err = str(exc)
        logger.warning("master_agent final synthesis failed: %s", err)
        if "quota_exhausted" in err:
            final_response = (
                "⚠️ I'm temporarily unavailable — the AI service has reached its daily quota. "
                "Please try again in a few hours or contact the admin to refresh the API key."
            )
        elif "invalid_key" in err:
            final_response = "⚠️ AI service configuration error. Please contact support."
        else:
            # Safe fallback — never expose raw agent context to the user
            final_response = "I'm having trouble connecting right now. Please try again in a moment."

    # Backstop: strip any internal tool name the model leaked into user-facing prose.
    final_response = _redact_tool_names(final_response)

    # Step 8 — persist both messages (ordered so replay stays user-then-assistant)
    await save_turn(
        conversation_id, user_id, user_message, final_response,
        model_used=settings.GROQ_MODEL,
    )

    # Step 9 — fire-and-forget background tasks (must never block or crash)
    asyncio.ensure_future(
        _log_task(user_id, conversation_id, query_type, user_message, extracted)
    )
    asyncio.ensure_future(
        _auto_save_preferences(user_id, extracted, travelers)
    )
    asyncio.ensure_future(
        _update_conversation_title(conversation_id, query_type, destination, origin)
    )

    # Step 10 — return
    return {"response": final_response, "conversation_id": conversation_id}


# Agentic orchestrator (Tier 2) — native tool-calling loop

# Balance: every step re-sends the full tool schema (~2k tokens) and Groq's free
# tier is 12k tokens/minute. 3 steps lets trip planning gather across rounds
# (e.g. transport, then weather+hotels, then synthesis) while staying under the
# TPM ceiling. The model can also batch multiple tool calls in a single step,
# so 3 steps covers far more than 3 tools.
_MAX_TOOL_STEPS = 3

# routers/agent.py wraps a chat turn in asyncio.wait_for(timeout=60). That cancel
# is total: the flights and hotels already fetched, the salvage paths below, even
# save_turn — all discarded, and the user is re-asked questions they just answered.
# Every recovery path in this function is worthless if the turn never reaches it.
# So the loop keeps its own tighter clock: stop STARTING new tool steps at the soft
# deadline and spend what's left writing an answer from what we already gathered.
# 52s leaves the router ~8s of headroom to serialise and respond.
_TURN_BUDGET = 52.0
_TURN_SOFT_DEADLINE = 32.0


def _time_left(started: float, floor: float = 6.0) -> float:
    """
    Seconds still safe to spend before the router cancels the turn. Floored rather
    than clamped to zero — a doomed-but-quick attempt still beats returning nothing,
    and the floor is small enough that overshooting stays inside the router's margin.
    """
    return max(_TURN_BUDGET - (time.monotonic() - started), floor)

# Shown when the LLM provider is momentarily rate-limited (free-tier TPM 429).
# Deliberately transient and reassuring — this is a per-minute wall, not a failure.
_RATE_LIMIT_MESSAGE = (
    "I'm getting a burst of requests right now and hit a brief rate limit. "
    "Please try again in a minute — nothing was lost, your trip details are safe."
)


def _is_rate_limit_error(exc: Exception) -> bool:
    """True for the Groq/Gemini quota (429) signal raised by llm_service."""
    return isinstance(exc, LLMError) and "quota_exhausted" in str(exc)


# Shown when our OWN turn-clock (not a provider) cut a call short. Distinct wording
# from _RATE_LIMIT_MESSAGE because the cause here is genuinely unknown — a slow or
# unresponsive fallback provider, not necessarily Groq's per-minute wall — and this
# fires only when generate_with_tools itself hung, so nothing was gathered to answer
# from either.
_TIMEOUT_MESSAGE = (
    "That's taking longer than it should on my end. Nothing was lost — please try "
    "again in a moment."
)


def _is_turn_timeout(exc: Exception) -> bool:
    """
    True when it was OUR _time_left() wait_for that ended the call, not a provider
    error. By construction the timeout passed to that wait_for was whatever was left
    of the turn budget — so if it fires, the budget is gone. Falling back to the
    legacy process_message() pipeline at that point hands the router's absolute 60s
    wall a second call with no realistic chance to finish, which is exactly the
    504-with-nothing-recovered failure this function exists to avoid.
    """
    return isinstance(exc, asyncio.TimeoutError)


def _budget_verdict_note(other_calls: list, results: list) -> str | None:
    """
    Deterministic whole-trip budget verdict, computed from the prices the search
    tools ACTUALLY returned this turn.

    The model is not trusted to do this arithmetic. Left to itself it reframed a
    whole-package budget as a per-night hotel ceiling, reported only that hotels
    were over, and never noticed the flight alone was ~50x the stated budget.
    The numbers here come from the tool results, so the verdict can't be wrong or
    quietly skipped. Returns None when there's no budget or nothing priced.
    """
    budget = None
    flight_pkr = hotel_per_night = 0.0
    travelers = rooms = 1
    nights = 0

    for (tc, args), res in zip(other_calls, results):
        if not isinstance(res, str):
            continue
        if args.get("max_budget_pkr") is not None and budget is None:
            try:
                budget = float(args["max_budget_pkr"])
            except (TypeError, ValueError):
                pass
        try:
            data = json.loads(res)
        except (json.JSONDecodeError, TypeError):
            continue
        name = tc.function.name
        if name == "search_flights" and data.get("flights"):
            # PER-SEAT here on purpose: check_budget_feasibility multiplies
            # flight_pkr by travelers, and the serialized total_price_pkr is
            # already the whole-party fare — feeding the total would square the
            # head-count (per-seat × passengers²) and wildly overstate the trip.
            prices = [f.get("price_per_seat_pkr") or 0 for f in data["flights"]]
            prices = [p for p in prices if p > 0]
            if prices:
                flight_pkr = min(prices)
                travelers = max(int(data.get("passengers") or 1), 1)
        elif name == "search_hotels" and data.get("hotels"):
            prices = [h.get("price_per_night_pkr") or 0 for h in data["hotels"]]
            prices = [p for p in prices if p > 0]
            if prices:
                hotel_per_night = min(prices)
                nights = max(int(data.get("nights") or 1), 1)
                rooms = max(int(args.get("rooms") or 1), 1)

    if budget is None or budget <= 0 or (flight_pkr <= 0 and hotel_per_night <= 0):
        return None

    verdict = check_budget_feasibility(
        budget,
        flight_pkr=flight_pkr,
        travelers=travelers,
        hotel_per_night_pkr=hotel_per_night,
        nights=nights,
        rooms=rooms,
    )
    return (
        "BUDGET CHECK (computed from the real prices above — state this verdict "
        "plainly to the user before offering options, and never contradict it): "
        f"{verdict['verdict']} Cheapest flight PKR {round(flight_pkr):,} x {travelers} "
        f"traveler(s); cheapest hotel PKR {round(hotel_per_night):,}/night x {nights} "
        f"night(s) x {rooms} room(s). If it does not fit, say so directly and offer to "
        "trim the trip — do NOT proceed as though the budget works."
    )


async def _synthesize_from_tools(
    system_prompt: str,
    history: list[dict],
    user_message: str,
    gathered: list[tuple[str, str]],
) -> str:
    """
    Produce a final answer from tool results we ALREADY have, using generate_text
    (which itself fails over Groq -> Gemini). This is the safe fallback when the
    tool-calling loop can't continue: it never re-runs the pipeline and never
    invents data — it answers strictly from the real tool output we collected.

    `gathered` is a list of (tool_name, json_result_string).
    """
    if not gathered:
        return ""
    tool_block = "\n\n".join(
        f"Result from {name}:\n{result}" for name, result in gathered
    )
    synth_messages = [
        {"role": "system", "content": system_prompt},
        *history,
        {
            "role": "user",
            "content": (
                f"{user_message}\n\n"
                f"You already gathered this live data from your tools. Write the final "
                f"answer for the user using ONLY these real numbers — do not invent any "
                f"flight, train, hotel, price, or time that is not below:\n\n{tool_block}"
            ),
        },
    ]
    try:
        return (await generate_text(synth_messages, temperature=0.4, max_output_tokens=1200)).strip()
    except Exception as exc:
        logger.warning("_synthesize_from_tools failed: %s", exc)
        return ""


async def _synthesize_bounded(
    started: float,
    system_prompt: str,
    history: list[dict],
    user_message: str,
    gathered: list[tuple[str, str]],
) -> str:
    """
    _synthesize_from_tools under the turn clock. This is the LAST thing that runs
    before we hand an answer back, so it is exactly where an over-running provider
    turns a recoverable turn into a 504 that throws the gathered data away.
    Returns "" on timeout, which the caller already handles.
    """
    try:
        return await asyncio.wait_for(
            _synthesize_from_tools(system_prompt, history, user_message, gathered),
            timeout=_time_left(started),
        )
    except Exception as exc:
        logger.warning("bounded synthesis gave up (%s)", exc)
        return ""


def _safe_args(raw: str | None) -> dict:
    """Parse a tool_call arguments JSON string into a dict; {} on bad input."""
    try:
        data = json.loads(raw or "{}")
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, TypeError):
        return {}


def _append_emergency_numbers(tool_result_json: str) -> str:
    """
    Backstop for find_healthcare calls the keyword matcher didn't anticipate
    (e.g. "I feel dizzy" with no explicit hospital/emergency wording). Adds the
    curated emergency-numbers fact directly onto the tool result so the model
    has it exactly when reasoning about a healthcare answer. Never raises —
    falls back to the original content if it isn't valid JSON.
    """
    try:
        data = json.loads(tool_result_json)
        if isinstance(data, dict):
            data["emergency_numbers"] = EMERGENCY_NUMBERS
            return json.dumps(data)
    except (json.JSONDecodeError, TypeError):
        pass
    return tool_result_json


def _absorb_learned(learned: dict, args: dict) -> None:
    """Accumulate preference signals from tool-call args (for memory learning + title)."""
    if not args:
        return
    if args.get("origin_city") and not learned.get("origin"):
        learned["origin"] = args["origin_city"]
    dest = args.get("destination_city") or args.get("city") or args.get("destination")
    if dest and not learned.get("destination"):
        learned["destination"] = dest
    if args.get("cabin_class") and not learned.get("cabin_class"):
        learned["cabin_class"] = args["cabin_class"]
    pax = args.get("passengers") or args.get("guests") or args.get("travelers")
    if pax and not learned.get("travelers"):
        try:
            learned["travelers"] = int(pax)
        except (ValueError, TypeError):
            pass
    budget = args.get("max_budget_pkr")
    if budget and not learned.get("budget_pkr"):
        try:
            learned["budget_pkr"] = float(budget)
        except (ValueError, TypeError):
            pass


def _derive_query_type(tools_used: list[str]) -> str:
    """Map the tools the model actually called to a query_type label for logging/title."""
    if "search_flights" in tools_used:
        return "flight_booking"
    if "search_trains" in tools_used:
        return "train_booking"
    if "search_hotels" in tools_used:
        return "hotel_search"
    if "get_weather" in tools_used:
        return "weather"
    if "find_healthcare" in tools_used:
        return "healthcare"
    return "general"


# User-facing text must never leak internal tool/field names. The free-tier model
# occasionally narrates "I'll call prepare_booking" despite the system-prompt rule,
# so this is a deterministic backstop: any leaked tool name is rewritten into plain
# words before the reply is ever shown or saved.
_TOOL_PHRASES: dict[str, str] = {
    "search_flights": "search for flights",
    "search_trains": "search for trains",
    "search_hotels": "search for hotels",
    "get_weather": "check the weather",
    "find_healthcare": "find healthcare nearby",
    "prepare_booking": "prepare your booking",
    "book_car": "arrange your car",
}

# "I'll call prepare_booking" / "run the search_flights tool" → drop the leading
# verb (+ optional article/quotes/trailing 'tool|function|…') so the sentence reads
# naturally once the tool name is swapped for its human phrase.
_TOOL_VERB_RE = re.compile(
    r"\b(?:call|calls|calling|use|uses|using|invoke|invoking|run|running|"
    r"trigger|triggering|execute|executing)\s+(?:the\s+)?[`'\"]?"
    r"(" + "|".join(re.escape(t) for t in _TOOL_PHRASES) + r")"
    r"[`'\"]?(?:\s+(?:tool|function|api|endpoint))?",
    re.IGNORECASE,
)
_TOOL_NAME_RE = re.compile(
    r"[`'\"]?\b(" + "|".join(re.escape(t) for t in _TOOL_PHRASES) + r")\b[`'\"]?",
    re.IGNORECASE,
)


# Raw tool-call markup the model sometimes emits as plain TEXT, e.g.
# "<function=search for flights>{...}</function>". llm_service salvages the
# well-formed ones into real calls before we ever get here; these strip any
# un-salvageable remnant (broken JSON, dangling opener) so the raw markup can
# never surface in a chat reply — which is exactly what a user reported seeing.
_LEAKED_FUNC_RE = re.compile(r"<function=.*?</function>", re.IGNORECASE | re.DOTALL)
_LEAKED_FUNC_DANGLING_RE = re.compile(r"<\s*/?\s*function\b.*$", re.IGNORECASE | re.DOTALL)


def _redact_tool_names(text: str) -> str:
    """Rewrite any internal tool name the model leaked into a human phrase, and
    strip any raw <function=...> tool-call markup that slipped through as text."""
    text = _as_text(text)
    if not text:
        return text
    text = _LEAKED_FUNC_RE.sub("", text)
    text = _LEAKED_FUNC_DANGLING_RE.sub("", text)
    text = _TOOL_VERB_RE.sub(lambda m: _TOOL_PHRASES[m.group(1).lower()], text)
    text = _TOOL_NAME_RE.sub(lambda m: _TOOL_PHRASES[m.group(1).lower()], text)
    return text.strip()


# ── Fabricated-booking backstop ───────────────────────────────────────────────
# The REAL booking summary + payment buttons only ever reach the app through the
# booking_data path below (a booking that passed the deterministic gate AND the
# server-side reprice). When that gate REJECTS a prepare_booking — e.g. the picked
# option can't be re-confirmed against live listings — the model is told to say so
# plainly. A free-tier model sometimes ignores that and instead writes the summary
# card itself as PLAIN PROSE, or on a later turn just claims "your flight is now
# booked!". The user then sees a card with a price nothing will honour and NO
# buttons (there was no real booking behind it), and a "booked" that never
# happened. No legitimate chat reply reproduces the card's own UI labels or
# asserts a booking is already done — those are the app's job after payment — so
# their presence in free prose is a reliable fabrication signal we scrub here.
_FAKE_CARD_RE = re.compile(
    r"add passenger details"
    r"|pay with card"
    r"|\bpay later\b"
    r"|booking summary",
    re.IGNORECASE,
)
# A booking noun asserted as already-done ("flight is now booked", "booking is
# confirmed", "ticket has been reserved"), in either order. Requires a completion
# word (booked/confirmed/reserved/secured/paid) tied to a booking noun by a
# state/now/perfect connector, so plain future/imperative prose ("would you like
# to book?", "to get it booked") does not trip it.
_FAKE_CONFIRM_RE = re.compile(
    r"\b(?:flight|train|hotel|booking|ticket|seat|reservation|room|trip|package|car|ride|sedan|suv|van)s?\b"
    r"[^.\n!?]{0,60}?\b(?:is|are|was|were|has been|have been|'s|now|been|successfully)\b"
    r"[^.\n!?]{0,25}?\b(?:booked|confirmed|reserved|secured|paid)\b"
    r"|\b(?:booked|confirmed|reserved|secured)\b[^.\n!?]{0,30}?\byour\b"
    r"[^.\n!?]{0,25}?\b(?:flight|train|hotel|booking|ticket|seat|reservation|room|trip|car|ride|sedan|suv|van)s?\b",
    re.IGNORECASE,
)

_BOOKING_NOT_DONE_MSG = (
    "Just to be clear — nothing has been booked or charged yet. To actually book, "
    "tell me the exact option you'd like (for example, \"book the 3 PM ER322\") and "
    "I'll bring up the secure booking screen. You'll add passenger details there and "
    "pay by card, with the correct total shown before anything is confirmed."
)


def _is_fabricated_booking(text: str) -> bool:
    """True when free prose imitates the app's booking card or claims a booking is
    already done — neither can be genuine here, since a real booking returns via
    the booking_data path (the app renders the card), never as chat prose."""
    text = _as_text(text)
    if not text:
        return False
    return bool(_FAKE_CARD_RE.search(text) or _FAKE_CONFIRM_RE.search(text))


# ── Package continuity safeguard ──────────────────────────────────────────────
# A package is booked piece-by-piece, and the model is supposed to set `next_step`
# on each non-final piece so the app can carry the trip forward after payment (no
# chat turn happens during passenger-details/payment). If a free-tier model
# FORGETS next_step, the package silently dead-ends after the first piece. This
# deterministic fallback fills it in — but only from the components the user
# actually asked for, minus the ones already booked in this conversation, and
# never overriding a next_step the model did set.
_PKG_TRANSPORT_RE = re.compile(r"\b(flight|flights|fly|flying|plane|air\s?ticket|train|trains|rail)\b", re.I)
_PKG_STAY_RE = re.compile(r"\b(hotel|hotels|room|rooms|stay|accommodation|lodging|lodge|guest\s?house)\b", re.I)
_PKG_CAR_RE = re.compile(r"\b(car|cab|taxi|transfer|ride|driver|pick\s?up|pickup)\b", re.I)
_PKG_EXPLICIT_RE = re.compile(r"\b(package|bundle|whole trip|entire trip|full trip|everything)\b", re.I)


def _components_in(text: str) -> set[str]:
    found: set[str] = set()
    if _PKG_TRANSPORT_RE.search(text):
        found.add("transport")
    if _PKG_STAY_RE.search(text):
        found.add("stay")
    if _PKG_CAR_RE.search(text):
        found.add("car")
    return found


def _infer_package_next_step(
    booking_data: dict,
    conversation_user_texts: list[str],
    history: list[dict],
    learned: dict,
) -> str:
    """
    A safe, deterministic `next_step` for a multi-piece package when the model
    left it blank. Returns '' when there's no clear package intent or nothing is
    outstanding, so it never nags a plain single booking.
    """
    all_text = " ".join(conversation_user_texts)
    requested = _components_in(all_text)
    # Require a STRONG package signal: an explicit "package/everything", or two+
    # components named together in a SINGLE message ("book a flight and hotel").
    # Scattered mentions across turns ("I flew in yesterday" … "book a hotel")
    # must not trigger a spurious "next, your flight".
    explicit = bool(_PKG_EXPLICIT_RE.search(all_text))
    multi_in_one = any(len(_components_in(t)) >= 2 for t in conversation_user_texts)
    if not (explicit or multi_in_one):
        return ""

    # Components already presented/booked in THIS conversation (summary markers).
    hist_text = " ".join(
        m.get("content", "") for m in history if (m.get("role") or "").lower() == "assistant"
    )
    booked: set[str] = set()
    if any(mark in hist_text for mark in ("✈️", "🚂", "**Flight:**", "**Train:**")):
        booked.add("transport")
    if any(mark in hist_text for mark in ("🏨", "**Hotel:**")):
        booked.add("stay")
    if any(mark in hist_text for mark in ("🚗", "**Car transfer:**", "Car Booking")):
        booked.add("car")

    # The piece being booked on THIS turn.
    bt = booking_data.get("booking_type")
    if bt in ("flight", "train"):
        booked.add("transport")
    elif bt == "hotel":
        booked.add("stay")
    if booking_data.get("transfer_vehicle_type"):  # a transfer riding along counts
        booked.add("car")

    remaining = [c for c in ("transport", "stay", "car") if c in requested and c not in booked]
    if not remaining:
        return ""

    dest = (learned.get("destination") or "").strip()
    where = f" in {dest}" if dest else ""
    transport_label = "your flight"
    if not re.search(r"\b(flight|flights|fly|flying|plane|air)\b", all_text, re.I):
        transport_label = "your train"
    labels = {"transport": transport_label, "stay": f"your hotel{where}", "car": "a car/transfer"}
    parts = [labels[c] for c in remaining]
    return "next, " + ", then ".join(parts)


# "near me / here / my location" cues. When one of these appears AND the app sent
# live GPS, the location-sensitive tools (find_healthcare, get_weather) use the
# device's real position instead of a city the model might guess from memory.
_HERE_CUE_RE = re.compile(
    r"\b(near\s*me|nearby\s+me|around\s+me|close(?:st)?\s+to\s+me|near\s+my\s+location|"
    r"my\s+(?:current\s+)?location|my\s+area|current\s+location|where\s+i\s+am|"
    r"right\s+here|over\s+here|mere\s+paas|meri\s+location|yahan|idhar)\b",
    re.IGNORECASE,
)


def _has_here_cue(message: str) -> bool:
    return bool(_HERE_CUE_RE.search(message or ""))


# How many of the most recent turns stay verbatim, and how hard older assistant
# turns are trimmed. Tuned for the package flow, which is by far the heaviest.
_HISTORY_RECENT_FULL = 4
_HISTORY_MAX_CHARS = 700


def _compact_history(history: list[dict]) -> list[dict]:
    """
    Shrink the history that goes to the MODEL, without touching `history` itself.

    A package turn emits very large assistant messages — six-row flight, hotel
    and train tables plus a budget breakdown. All twenty of those then ride along
    in EVERY later call, and on the free tier that bulk alone pushed a turn past
    the 52s budget: a plain "yes" to "shall I book the hotel?" timed out with
    nothing wrong except payload size.

    Only ASSISTANT messages are trimmed, and only older ones:
      - user turns stay verbatim — they are what the party size, dates, addresses
        and car details are read from, and every provenance gate scans them;
      - the last few turns stay whole, so the immediate context is never lossy.
    The caller keeps using the untrimmed `history` for those gates.
    """
    if not history:
        return []
    cutoff = len(history) - _HISTORY_RECENT_FULL
    out: list[dict] = []
    for i, m in enumerate(history):
        content = m.get("content") or ""
        if (
            m.get("role") == "assistant"
            and i < cutoff
            and len(content) > _HISTORY_MAX_CHARS
        ):
            out.append({
                **m,
                "content": content[:_HISTORY_MAX_CHARS].rstrip()
                + "\n…[earlier options trimmed — re-run the search if you need them]",
            })
        else:
            out.append(m)
    return out


async def process_message_agentic(
    user_id: str,
    conversation_id: str,
    user_message: str,
    device_lat: float | None = None,
    device_lng: float | None = None,
) -> dict:
    """
    Agentic entry point: the LLM holds real tools, decides which to call, sees
    structured results in-context, and writes ONE final answer. This replaces the
    rigid classify -> route -> double-LLM pipeline with a genuine reasoning loop.

    Falls back to the legacy process_message() on any failure so the endpoint
    never hard-fails.
    """
    # Step 1 — load context in parallel
    (memory, profile), history = await asyncio.gather(
        asyncio.gather(get_user_memory(user_id), get_user_profile(user_id)),
        get_conversation_history(conversation_id, limit=20),
    )

    # ── Emergency / healthcare fast-path ──────────────────────────────────────
    # A medical emergency must NEVER hinge on the LLM chain being up. When the
    # message clearly signals a medical emergency or asks for the nearest
    # hospital/clinic, answer deterministically from curated facility data + the
    # national emergency numbers. Instant and immune to the Groq/OpenRouter
    # rate-limit wall that otherwise degrades these turns to "try again in a
    # minute" — the worst possible reply when someone is hurt. Booking turns
    # ("urgent flight", "nearest hotel") don't match, so this can't hijack them.
    if is_medical_emergency(user_message):
        prior_user_texts = [m.get("content", "") for m in history if m.get("role") == "user"]
        emergency_reply = build_emergency_reply(
            user_message, prior_user_texts, urgent=has_emergency_signal(user_message),
            device_lat=device_lat, device_lng=device_lng,
            prefer_device=_has_here_cue(user_message),
        )
        await save_turn(
            conversation_id, user_id, user_message, emergency_reply,
            model_used="deterministic-emergency",
        )
        asyncio.ensure_future(_log_task(
            user_id, conversation_id, "healthcare", user_message,
            {"tools": ["emergency_healthcare"]},
        ))
        return {"response": emergency_reply, "conversation_id": conversation_id}

    memory_context = _format_memory(memory, profile)
    # PK date, not the host's. On a UTC server this line is what tells a
    # 2am Karachi user it is still yesterday, so their "tomorrow" books a
    # day early. Pakistan is UTC+5 — see core/pk_time.
    today = pk_today()

    system_prompt = MASTER_AGENTIC_SYSTEM.format(
        today=today.isoformat(),
        weekday=today.strftime("%A"),
        memory=memory_context or "(no saved preferences yet)",
    )

    # Grounded static facts (visa/baggage/rail-class/emergency) — only added
    # for turns where they're actually relevant, to stay within Groq's TPM budget.
    facts = get_relevant_facts(user_message)
    if facts:
        system_prompt += (
            "\n\n## Grounded facts for this turn — use these, don't contradict them\n"
            f"{facts}"
        )

    messages: list[dict] = [{"role": "system", "content": system_prompt}]
    # Trimmed for the model only — the gates below still read the full `history`.
    messages.extend(_compact_history(history))
    messages.append({"role": "user", "content": user_message})

    # Deterministic pick-from-a-list nudge (see _selection_hint): when the user
    # answers a numbered list with "6" / "option 6" / "the second one", name the
    # exact item so the model converges in ONE prepare_booking call instead of
    # re-deriving it from the whole history under a tight turn budget — the thrash
    # that produced the "trouble responding" / "taking longer" replies. The booking
    # gates and server-side reprice still run, so this can never misbook.
    pick_hint = _selection_hint(user_message, history)
    if pick_hint:
        messages.append({"role": "system", "content": pick_hint})

    booking_data: dict | None = None
    car_booking_data: dict | None = None
    # Every server-repriced component prepared this turn. 2+ => a package.
    package_components: list[dict] = []
    final_text: str = ""
    tools_used: list[str] = []
    learned: dict = {}
    gathered: list[tuple[str, str]] = []  # (tool_name, result_json) — real data we collected

    # The user's own messages in CHRONOLOGICAL order (oldest first, this turn
    # last). Shared by both provenance gates below; the car gate relies on the
    # order to scope its scan to the car sub-conversation.
    conversation_user_texts = [
        *(m.get("content", "") for m in history if m.get("role") == "user"),
        user_message,
    ]

    # Did the user ever actually give a date? The model tends to invent a
    # travel_date rather than ask; an invented "today" passes the missing/past
    # gates, so provenance is the only thing that catches it — see date_provenance_error.
    user_dates_known = user_supplied_date_signal(conversation_user_texts)

    # Self-improvement logging (see agents/self_improvement.py) — a heuristic,
    # conservative detector for "the user is correcting a prior agent turn".
    # Logged only, never auto-acted on: only the user knows what the actual
    # correction is, so this is pure signal for a human reviewing the log later.
    if self_improvement.detect_user_correction(user_message):
        last_assistant = next(
            (m.get("content") for m in reversed(history) if m.get("role") == "assistant"),
            None,
        )
        asyncio.ensure_future(self_improvement.log_agent_failure(
            user_id=user_id, conversation_id=conversation_id,
            failure_type="user_correction", user_message=user_message,
            assistant_message=last_assistant,
        ))

    def _log_gate_failure(tool_name: str, args: dict, error: dict) -> None:
        """
        Fire-and-forget log for a prepare_booking/book_car gate rejection.
        These are never auto-retried — fixing them means guessing a date, a
        party size, or an address the user didn't give, which is exactly what
        every one of these gates exists to prevent. Logged for a human to
        review whether the prompt needs to ask more clearly up front.
        """
        asyncio.ensure_future(self_improvement.log_agent_failure(
            user_id=user_id, conversation_id=conversation_id,
            failure_type="slot_fill_failure", user_message=user_message,
            tool_name=tool_name, tool_args=args, error_detail=str(error.get("error")),
        ))

    started = time.monotonic()
    try:
        for step in range(_MAX_TOOL_STEPS):
            # Never skip the FIRST call — a slow warm-up must still produce a turn.
            if step and time.monotonic() - started > _TURN_SOFT_DEADLINE:
                logger.warning(
                    "agentic loop out of time after %d step(s) — answering from gathered data",
                    step,
                )
                break
            # Bounded like the post-loop synthesis call below: Groq failing fast into
            # OpenRouter is exactly the case that produced a 60.7s 504 with nothing
            # logged in between — this is the call that was in flight when it happened,
            # and it was the one call in this function still missing a timeout.
            msg = await asyncio.wait_for(
                generate_with_tools(
                    messages, tools=TOOL_SCHEMAS, temperature=0.4, max_output_tokens=1200,
                ),
                timeout=_time_left(started),
            )
            tool_calls = getattr(msg, "tool_calls", None)

            if not tool_calls:
                # Redact BEFORE accepting this as the answer. A reply that is
                # nothing but leaked <function=...> markup (a tool call the
                # salvage pass couldn't recover) redacts to an EMPTY string, and
                # treating that as "the model replied" is what produced the bare
                # "I'm having trouble responding right now." the user kept hitting
                # on booking-confirm turns. Empty here means we have no answer
                # yet, not that the turn failed — so fall through to the
                # synthesis step below, which answers from the data we gathered.
                raw_reply = (msg.content or "").strip()
                final_text = _redact_tool_names(raw_reply)
                if raw_reply and not final_text:
                    logger.warning(
                        "model reply was unsalvageable tool-call markup — "
                        "synthesizing from gathered data instead: %r",
                        raw_reply[:300],
                    )
                break

            # prepare_booking — deterministic gate + server-side repricing.
            # The model's own judgment on "do I have enough info", whether the
            # date makes sense, and its own total_price_pkr are never trusted:
            # required fields are checked in code (get_missing_booking_fields),
            # travel_date/check_in/check_out are rejected outright if they've
            # already passed (get_booking_date_error — same hard-rejection gate
            # applied to search_flights/search_trains/search_hotels down in
            # execute_tool), and the price is always re-derived from the same
            # search executor that produced the original offer (reprice_booking)
            # — a prompt-injected or hallucinated price can never reach a
            # payment screen. A call that fails any check gets a structured
            # error back so the model asks or re-searches instead of the turn
            # silently proceeding on partial, stale, or invented data.
            booking_calls = [tc for tc in tool_calls if tc.function.name == "prepare_booking"]
            booking_gate_results: dict[str, dict] = {}
            for tc in booking_calls:
                bd = _safe_args(tc.function.arguments)
                # Deterministically recover a hotel's `destination` if the model
                # dropped it (search names the field `city`, booking names it
                # `destination` — the mismatch makes free-tier models omit it and
                # loop on "which city?"). Only fills a blank; reprice still
                # validates the hotel, so a bad recovery can't misbook.
                bd = recover_booking_location(
                    bd, [user_message, *(m.get("content", "") for m in reversed(history))]
                )
                missing = get_missing_booking_fields(bd)
                if missing:
                    booking_gate_results[tc.id] = missing_fields_result(missing)
                    _log_gate_failure("prepare_booking", bd, booking_gate_results[tc.id])
                    continue
                count_error = get_booking_count_error(bd)
                if count_error:
                    booking_gate_results[tc.id] = count_error
                    _log_gate_failure("prepare_booking", bd, count_error)
                    continue
                date_error = get_booking_date_error(bd)
                if date_error:
                    booking_gate_results[tc.id] = date_error
                    _log_gate_failure("prepare_booking", bd, date_error)
                    continue
                # The transfer pickup address is dispatched to a real driver
                # after payment, so it gets the same hard gate as the date and
                # party size — a placeholder must never reach car_bookings.
                transfer_error = get_transfer_error(bd)
                if transfer_error:
                    booking_gate_results[tc.id] = transfer_error
                    _log_gate_failure("prepare_booking", bd, transfer_error)
                    continue
                bd = apply_traveler_totals(bd)
                verified = await reprice_booking(bd)
                if verified:
                    # Collect EVERY component the model prepared this turn, not just
                    # the first. A package ("flight + hotel + car") is exactly this:
                    # several prepare_booking calls in one turn, each independently
                    # gated and server-repriced by the code above. Two or more
                    # verified components become a single package_choice with one
                    # combined total, so the user fills passenger details once and
                    # pays once, instead of being walked through a separate booking
                    # and a separate payment per piece. A single component still
                    # takes the original payment_choice path, unchanged.
                    package_components.append(verified)
                    if booking_data is None:
                        booking_data = verified
                    continue
                booking_gate_results[tc.id] = offer_not_found_result()
                _log_gate_failure("prepare_booking", bd, booking_gate_results[tc.id])

            # book_car — standalone within-city ride. Same posture as
            # prepare_booking: the model NEVER commits it. The gate validates the
            # four fields deterministically (vehicle enum, non-empty locations,
            # a future pickup time); on success we prepare a car_booking_choice
            # the app confirms with a single tap, and the driver is assigned only
            # then. A failed gate is fed back so the model asks instead of guessing.
            car_calls = [tc for tc in tool_calls if tc.function.name == "book_car"]
            car_gate_results: dict[str, dict] = {}
            for tc in car_calls:
                ca = _safe_args(tc.function.arguments)
                car_error = get_car_booking_error(ca)
                if car_error:
                    car_gate_results[tc.id] = car_error
                    _log_gate_failure("book_car", ca, car_error)
                    continue
                # Provenance: the drop-off, vehicle and pickup time must trace
                # back to the user's own words — the shape gate above passes an
                # invented-but-valid ride ("book car for me too" -> a fabricated
                # Sedan/airport/10:00), and confirming it dispatches a real driver.
                prov_error = get_car_provenance_error(ca, conversation_user_texts)
                if prov_error:
                    car_gate_results[tc.id] = prov_error
                    _log_gate_failure("book_car", ca, prov_error)
                    continue
                car_booking_data = build_car_booking_data(ca)
                break

            if booking_data or car_booking_data:
                break

            # Append the assistant tool-call turn, then run the non-booking tools in parallel
            messages.append({
                "role": "assistant",
                "content": msg.content or None,
                "tool_calls": [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments or "{}",
                        },
                    }
                    for tc in tool_calls
                ],
            })

            call_args = [_safe_args(tc.function.arguments) for tc in tool_calls]
            # Device-location injection: hand the user's live GPS (if the app sent it)
            # to the location-sensitive tools so "hospitals near me" / "weather here"
            # resolve to the user's ACTUAL position, not a city the model guessed.
            # Deterministic ambient context — the model never supplies these; the
            # executor prefers them only for a "near me" cue or when no city was named.
            if device_lat is not None and device_lng is not None:
                _prefer_device = _has_here_cue(user_message)
                for _tc, _args in zip(tool_calls, call_args):
                    if _tc.function.name in ("find_healthcare", "get_weather"):
                        _args["_dev_lat"] = device_lat
                        _args["_dev_lng"] = device_lng
                        _args["_prefer_device"] = _prefer_device
            other_calls = [
                (tc, args) for tc, args in zip(tool_calls, call_args)
                if tc.function.name not in ("prepare_booking", "book_car")
            ]
            results = await asyncio.gather(
                *[self_improvement.dispatch_tool_with_retry(
                      user_id=user_id, conversation_id=conversation_id, user_message=user_message,
                      name=tc.function.name, args=args, has_user_date=user_dates_known)
                  for tc, args in other_calls],
                return_exceptions=True,
            )
            for (tc, args), res in zip(other_calls, results):
                tools_used.append(tc.function.name)
                _absorb_learned(learned, args)
                content = res if isinstance(res, str) else json.dumps({"error": str(res)})
                # Backstop: if find_healthcare was called from phrasing the keyword
                # matcher above didn't catch (e.g. "I feel dizzy"), still ground the
                # answer in the real emergency numbers rather than the model's memory.
                if tc.function.name == "find_healthcare" and EMERGENCY_NUMBERS not in system_prompt:
                    content = _append_emergency_numbers(content)
                gathered.append((tc.function.name, content))
                messages.append({"role": "tool", "tool_call_id": tc.id, "content": content})

            # Ground the affordability claim in code, not model arithmetic — same
            # posture as reprice_booking. Appended after the tool results so the
            # model sees the verdict before it writes the answer.
            budget_note = _budget_verdict_note(other_calls, results)
            if budget_note:
                gathered.append(("budget_check", budget_note))
                messages.append({"role": "system", "content": budget_note})

            for tc in booking_calls:
                result = booking_gate_results.get(tc.id, offer_not_found_result())
                messages.append({
                    "role": "tool", "tool_call_id": tc.id,
                    "content": json.dumps(result),
                })

            # Reached only when no car booking was prepared (all car_calls, if any,
            # failed the gate) — feed each error back so the next turn asks/corrects.
            for tc in car_calls:
                result = car_gate_results.get(tc.id) or {
                    "error": "car_booking_incomplete",
                    "instruction": "Ask the user for the pickup address, drop-off address, "
                                   "vehicle type (Sedan/SUV/Van) and pickup date & time.",
                }
                messages.append({
                    "role": "tool", "tool_call_id": tc.id,
                    "content": json.dumps(result),
                })

        # Loop ended with tools called but no final prose → synthesize one answer.
        if not final_text and not booking_data:
            try:
                # Bounded: a fallback provider that queues rather than 429s can sit
                # here for its full 35s budget, which on a late turn is exactly what
                # pushes us past the router's cancel and loses the whole answer.
                msg = await asyncio.wait_for(
                    generate_with_tools(messages, tools=None, temperature=0.5, max_output_tokens=1200),
                    timeout=_time_left(started),
                )
                final_text = (getattr(msg, "content", "") or "").strip()
            except Exception as exc:
                # Out of tool-call budget — synthesize from the data we ALREADY have,
                # via generate_text (Groq->Gemini failover). Never re-run the pipeline
                # from scratch (that double-spends quota and risks hallucinating).
                logger.warning("final tool-synthesis failed (%s) — synthesizing from gathered data", exc)
                final_text = await _synthesize_bounded(
                    started, system_prompt, history, user_message, gathered
                )

    except Exception as exc:
        # The loop broke (e.g. quota). If we already gathered real tool data, answer
        # from it — do NOT re-run the pipeline (it hallucinated under quota stress).
        logger.warning("agentic loop failed (%s)", exc)
        if gathered:
            final_text = await _synthesize_bounded(
                started, system_prompt, history, user_message, gathered
            )
        if not final_text:
            if looks_like_healthcare(user_message):
                # Safety-critical: a medical/hospital query must never degrade to a
                # transient "try again" just because the LLM chain is down. Answer
                # from curated facility data + the national emergency numbers.
                final_text = build_emergency_reply(
                    user_message,
                    [m.get("content", "") for m in history if m.get("role") == "user"],
                    urgent=has_emergency_signal(user_message),
                )
            elif _is_rate_limit_error(exc):
                # Per-minute rate limit with nothing gathered: re-running the legacy
                # pipeline just hits the same 429 and double-spends the budget. Fail
                # fast with an honest, transient message instead of hanging to 504.
                final_text = _RATE_LIMIT_MESSAGE
            elif _is_turn_timeout(exc):
                # Our own budget is spent, not just Groq's per-minute wall — the
                # legacy pipeline would only get a few seconds against the router's
                # absolute 60s cutoff before losing everything the same way again.
                final_text = _TIMEOUT_MESSAGE
            else:
                # Nothing gathered → safe to try the legacy pipeline as a last resort.
                return await process_message(user_id, conversation_id, user_message)

    # Package path → package_choice. Two or more components were prepared and each
    # one already passed the same gates and the same server-side reprice a single
    # booking gets — this only bundles them so the app can collect passenger details
    # once and take ONE payment for the combined total. The per-component totals are
    # the repriced ones, so the package total is a sum of server-verified numbers and
    # can never be a model-invented figure.
    if len(package_components) >= 2:
        package_data = build_package_data(package_components)
        summary = format_package_summary(package_data)
        await save_turn(
            conversation_id, user_id, user_message, summary,
            model_used=settings.GROQ_MODEL,
        )
        asyncio.ensure_future(_log_task(
            user_id, conversation_id, "booking", user_message, package_data,
        ))
        return {
            "response": summary,
            "conversation_id": conversation_id,
            "action": "package_choice",
            "booking_data": package_data,
        }

    # Booking path → payment_choice (same contract the Flutter app already handles)
    if booking_data:
        # Package continuity: keep the model's next_step if it set a safe one;
        # otherwise synthesize one deterministically so a forgotten next_step can't
        # silently dead-end a multi-piece package. Sanitize the result so BOTH the
        # summary and the app's post-payment handoff (which reads next_step raw)
        # get vetted text — never a fabricated PNR or a "booked" claim.
        safe_next = sanitize_next_step(booking_data.get("next_step"))
        if not safe_next:
            safe_next = _infer_package_next_step(
                booking_data, conversation_user_texts, history, learned
            )
        booking_data["next_step"] = safe_next
        summary = format_booking_summary(booking_data)
        await save_turn(
            conversation_id, user_id, user_message, summary,
            model_used=settings.GROQ_MODEL,
        )
        asyncio.ensure_future(_log_task(user_id, conversation_id, "booking", user_message, booking_data))
        return {
            "response": summary,
            "conversation_id": conversation_id,
            "action": "payment_choice",
            "booking_data": booking_data,
        }

    # Standalone car path → car_booking_choice (single confirm tap, no payment)
    if car_booking_data:
        summary = format_car_booking_summary(car_booking_data)
        await save_turn(
            conversation_id, user_id, user_message, summary,
            model_used=settings.GROQ_MODEL,
        )
        asyncio.ensure_future(_log_task(user_id, conversation_id, "booking", user_message, car_booking_data))
        return {
            "response": summary,
            "conversation_id": conversation_id,
            "action": "car_booking_choice",
            "booking_data": car_booking_data,
        }

    # Backstop: strip any internal tool name or raw tool-call markup the model
    # leaked into user-facing prose, THEN fall back if nothing usable remains
    # (so stripping a pure-markup reply can't leave the user a blank bubble).
    final_text = _redact_tool_names(final_text)
    # We only reach here when NO real booking was produced this turn. If the model
    # nonetheless faked the booking card or claimed a booking is done, replace the
    # whole reply — the user must never see a summary/confirmation with no real
    # booking (and no payment buttons) behind it.
    if _is_fabricated_booking(final_text):
        logger.warning(
            "Neutralized a fabricated booking reply (no booking_data this turn): %r",
            final_text[:160],
        )
        final_text = _BOOKING_NOT_DONE_MSG
    if not final_text:
        if looks_like_healthcare(user_message):
            final_text = build_emergency_reply(
                user_message,
                [m.get("content", "") for m in history if m.get("role") == "user"],
                urgent=has_emergency_signal(user_message),
            )
        else:
            final_text = "I'm having trouble responding right now. Could you rephrase that?"

    # Persist both messages (ordered so replay stays user-then-assistant)
    await save_turn(
        conversation_id, user_id, user_message, final_text,
        model_used=settings.GROQ_MODEL,
    )

    # Fire-and-forget: learn preferences, set a meaningful title, log the task
    derived_qt = _derive_query_type(tools_used)
    asyncio.ensure_future(_auto_save_preferences(user_id, learned, learned.get("travelers") or 1))
    asyncio.ensure_future(_update_conversation_title(
        conversation_id, derived_qt, learned.get("destination") or "", learned.get("origin") or "",
    ))
    asyncio.ensure_future(_log_task(user_id, conversation_id, derived_qt, user_message, {"tools": tools_used}))

    return {"response": final_text, "conversation_id": conversation_id}


# Routing

async def _route_to_agents(
    *,
    query_type: str,
    origin: str,
    destination: str,
    travel_date,
    check_in,
    check_out,
    travelers: int,
    duration_days: int,
    budget_pkr: float,
    travel_style: str,
    memory: dict,
) -> str:
    """
    Dispatch to specialist agents based on intent.
    Always uses asyncio.gather(return_exceptions=True) — one failing agent
    must not crash the whole response.
    """
    if query_type == "trip_planning":
        budget_per_night = round(budget_pkr * 0.30 / max(duration_days, 1))

        # Phase 1 — context-independent agents run in parallel
        # Pass actual travel_date so weather/itinerary advice is forward-looking
        travel_date_str = travel_date if isinstance(travel_date, str) else (
            travel_date.isoformat() if travel_date else None
        )
        phase1 = await asyncio.gather(
            get_weather_intelligence(destination, travel_date=travel_date_str),
            compare_transport(origin, destination, travel_date, travelers, budget_pkr),
            find_hotels(destination, check_in, check_out, travelers,
                        budget_per_night=budget_per_night, travel_style=travel_style),
            return_exceptions=True,
        )
        weather   = "" if isinstance(phase1[0], BaseException) else (phase1[0] or "")
        transport = "" if isinstance(phase1[1], BaseException) else (phase1[1] or "")
        hotels    = "" if isinstance(phase1[2], BaseException) else (phase1[2] or "")

        # Phase 2 — itinerary and budget use real phase-1 outputs
        phase2 = await asyncio.gather(
            generate_itinerary(
                destination, duration_days, travelers, travel_style, budget_pkr,
                weather_info=weather or None,
                hotel_summary=hotels or None,
                transport_summary=transport or None,
                travel_date=travel_date_str,
            ),
            calculate_budget(
                destination, duration_days, travelers, travel_style,
                transport_info=transport or None,
                hotel_info=hotels or None,
            ),
            return_exceptions=True,
        )
        itinerary = "" if isinstance(phase2[0], BaseException) else (phase2[0] or "")
        budget    = "" if isinstance(phase2[1], BaseException) else (phase2[1] or "")

        return "\n\n".join(filter(None, [weather, transport, hotels, itinerary, budget]))

    if query_type in ("flight_booking", "train_booking"):
        try:
            return await compare_transport(origin, destination, travel_date, travelers, budget_pkr)
        except Exception as exc:
            logger.warning("compare_transport failed: %s", exc)
            return ""

    if query_type == "hotel_search":
        budget_per_night = round(budget_pkr * 0.35 / max(duration_days, 1))
        try:
            return await find_hotels(
                destination, check_in, check_out, travelers,
                budget_per_night=budget_per_night, travel_style=travel_style,
            )
        except Exception as exc:
            logger.warning("find_hotels failed: %s", exc)
            return ""

    if query_type == "weather":
        travel_date_str = travel_date if isinstance(travel_date, str) else (
            travel_date.isoformat() if travel_date else None
        )
        try:
            return await get_weather_intelligence(destination, travel_date=travel_date_str)
        except Exception as exc:
            logger.warning("weather agent failed: %s", exc)
            return ""

    if query_type == "healthcare":
        try:
            return await get_safety_briefing(destination)
        except Exception as exc:
            logger.warning("healthcare agent failed: %s", exc)
            return ""

    if query_type == "recommendation":
        past = memory.get("past_destinations") or []
        try:
            return await get_recommendations(memory, past)
        except Exception as exc:
            logger.warning("recommendation agent failed: %s", exc)
            return ""

    if query_type == "car_booking":
        return (
            "Car booking is available in the Car tab on the Home screen. "
            "You can book a Sedan (PKR 800), SUV (PKR 1,200), or Van (PKR 1,500) "
            "with a verified driver for pickup and dropoff within your city. "
            "A 4-digit verification code will be assigned to your driver for security."
        )

    if query_type == "booking":
        return (
            "To complete your booking, search for your preferred flight, train, or hotel "
            "in the app, select your option, and proceed through the checkout flow. "
            "Payment is processed securely by card. Your PNR and confirmation email "
            "will be sent immediately after payment. You can view all bookings under My Bookings."
        )

    # general / unknown — let Gemini answer directly with no extra context
    return ""


# Background task logger

async def _log_task(
    user_id: str,
    conversation_id: str,
    query_type: str,
    user_message: str,
    extracted: dict,
) -> None:
    """
    Insert a completed-task row into agent_tasks.
    Logging failures are swallowed — they must NEVER crash the user response.
    """
    task_type = _QUERY_TYPE_TO_TASK_TYPE.get(query_type, "custom")
    now_iso   = datetime.now(timezone.utc).isoformat()

    payload = {
        "id":               str(uuid.uuid4()),
        "user_id":          user_id,
        "conversation_id":  conversation_id,
        "task_type":        task_type,
        "task_description": (user_message or "")[:200],
        "task_params":      extracted,
        "status":           "completed",
        "priority":         1,
        "started_at":       now_iso,
        "completed_at":     now_iso,
    }

    def _insert():
        return supabase_admin.table("agent_tasks").insert(payload).execute()

    try:
        await asyncio.to_thread(_insert)
    except Exception as exc:
        logger.debug("agent_tasks log insert failed (non-fatal): %s", exc)


# Re-exports — keep these so the router can import everything from master_agent

__all__ = [
    "process_message",
    "process_message_agentic",
    "start_new_conversation",
    "is_complete",
    "present_booking_summary",
]
