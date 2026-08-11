from __future__ import annotations
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

import asyncio
import json
import logging
import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import cast

from agents.memory_agent import (
    get_user_memory,
    get_user_profile,
    get_conversation_history,
    ConversationHistoryUnavailable,
    save_message,
    save_turn,
    save_user_memory,
    start_new_conversation,  # re-exported for callers (router uses this)
    save_planner_state,
    get_active_planner_state,
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
from services.llm_service import (
    generate_text,
    generate_with_tools,
    answering_model,
    begin_turn,
    estimate_request_tokens,
    error_kind,
    all_providers_exhausted,
    GeminiError,
    LLMError,
    QUOTA_MINUTE,
    QUOTA_DAILY,
    REQUEST_TOO_LARGE,
    INVALID_KEY,
)
from agents import deterministic_reply
from agents import trip_package
from agents import trip_selection
from agents.conversation_state import derive_state
from agents.prompt_builder import (
    build_system_prompt, select_tools, select_tools_by_name, select_tool_names,
    mentions_northern_destination,
)
from services.northern_routes import (
    canonical_destination, estimate_hub_car_fare, hub_options_for,
)
from agents.agent_tools import (
    get_missing_booking_fields,
    get_booking_count_error,
    get_already_booked_error,
    get_booking_date_error,
    get_transfer_error,
    get_trip_planner_incomplete_error,
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

from prompts.master_agent import MASTER_SYSTEM
from prompts.knowledge import get_relevant_facts, EMERGENCY_NUMBERS
from agents.emergency_healthcare import (
    is_medical_emergency,
    has_emergency_signal,
    looks_like_healthcare,
    build_emergency_reply,
)
from core.supabase_client import supabase_admin

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

# Words naming WHICH leg a pick belongs to, mapped to the order the legs are
# always listed in (outbound list first, return list second).
_LEG_RANK: dict[str, int] = {
    "outbound": 0, "onward": 0, "departing": 0, "departure": 0,
    "first": 0, "going": 0,
    "return": 1, "inbound": 1, "returning": 1, "second": 1, "back": 1,
}
_LEG_WORDS = "|".join(_LEG_RANK)

# "3 for outbound", "2 for the return", "2 for in return". The leg word may be
# preceded by filler the user threw in — requiring it to sit immediately after
# "for" (or "for the") is what made "2 for in return" parse as no pick at all,
# so only the outbound leg of a real round trip got booked.
_PICK_FOR_LEG_RE = re.compile(
    rf"\b(\d{{1,2}})\s+for\s+(?:\w+\s+){{0,2}}?({_LEG_WORDS})\b", re.I
)
# "outbound 3", "return #2", "return flight 2" — the leg named BEFORE the number.
# Only a small set of filler words may sit between them: allowing anything would
# read "returning on 2 Aug" as picking option 2, which would book the wrong seat.
_LEG_FIRST_RE = re.compile(
    rf"\b({_LEG_WORDS})\s*(?:flight|train|leg|option|number|no|is|it'?s|=)?"
    rf"\s*[:#-]?\s*(\d{{1,2}})\b",
    re.I,
)


def _leg_picks(message: str) -> list[int]:
    """
    Picks that say out loud which leg they belong to, returned in LEG order
    rather than the order typed — so "return 2, outbound 3" still books outbound
    #3 and return #2 instead of silently swapping the two flights. [] unless at
    least two DIFFERENT legs were named.
    """
    by_rank: dict[int, int] = {}
    for pattern, num_first in ((_PICK_FOR_LEG_RE, True), (_LEG_FIRST_RE, False)):
        for m in pattern.finditer(message):
            num, leg = (m.group(1), m.group(2)) if num_first else (m.group(2), m.group(1))
            by_rank.setdefault(_LEG_RANK[leg.lower()], int(num))
    if len(by_rank) < 2:
        return []
    return [by_rank[rank] for rank in sorted(by_rank)]


def _selected_indices(message: str) -> list[int]:
    """Every list position the user picked, in order. [] when it isn't a multi-pick."""
    message = _as_text(message)
    # Leg-aware parsing first: it knows which pick is the outbound and which is
    # the return, so it stays correct no matter which order they were typed in.
    legs = _leg_picks(message)
    if legs:
        return legs
    picks = [int(m.group(1)) for m in _PICK_KEYWORD_RE.finditer(message)]
    return picks if len(picks) >= 2 else []


# Telling an OFFER list ("1. PA-180 — PKR 17,500") apart from an instructional
# one ("1. Choose your outbound flight") matters because only offer lists may be
# paired with a pick — resolving "option 2" against a list of instructions would
# book something the user never saw.
#
# Length alone used to be the discriminator, and it was wrong in both directions:
# a fully-detailed offer row (airline, times, per-person price, party total, seats
# left) is comfortably over 60 characters, so real offers were being rejected and
# a two-leg pick silently lost its hint. A PRICE is the reliable signal — an
# instruction never quotes one — so a priced row qualifies at any length, and the
# old length rule stays as the fallback for terse lists that omit prices.
_OFFER_LABEL_MAX = 60
_PRICE_IN_LABEL_RE = re.compile(r"\bPKR\s*[\d,]+", re.IGNORECASE)


def _looks_like_offers(lst: dict[int, str]) -> bool:
    if not lst:
        return False
    if all(_PRICE_IN_LABEL_RE.search(v) for v in lst.values()):
        return True
    return len(lst) >= 2 and all(len(v) <= _OFFER_LABEL_MAX for v in lst.values())


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
    return [lst for lst in _numbered_lists(text) if _looks_like_offers(lst)]


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

async def _history_or_empty(conversation_id: str, limit: int = 20) -> list[dict]:
    """
    The legacy pipeline's original behaviour, kept byte-for-byte: a failed
    history read is treated the same as no history yet. process_message_agentic
    does NOT use this — it needs to tell the two apart, see its own call site.
    """
    try:
        return await get_conversation_history(conversation_id, limit)
    except ConversationHistoryUnavailable:
        return []


async def process_message(
    user_id: str,
    conversation_id: str,
    user_message: str,
) -> dict:
    """
    Run a single turn of the multi-agent conversation.
    Returns: {"response": str, "conversation_id": str}
    """
    # Reached either directly or as the agentic path's fallback; either way this
    # is the start of a turn, so attribution starts here too (idempotent).
    begin_turn()

    # Step 1 — load user profile + memory + conversation history IN PARALLEL
    (memory, profile), history = await asyncio.gather(
        asyncio.gather(get_user_memory(user_id), get_user_profile(user_id)),
        _history_or_empty(conversation_id, limit=20),
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
        if booking_data and _booking_data_is_valid(booking_data):
            summary = format_booking_summary(booking_data)
            await save_turn(
                conversation_id, user_id, user_message, summary,
                model_used=answering_model(),
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
        logger.warning(
            "master_agent final synthesis failed: kind=%s %s", error_kind(exc), exc)
        # Keyed off the typed `kind`, not the message text. The old string match
        # on "quota_exhausted" went dead the moment errors became typed, and
        # every provider failure silently collapsed into the generic "having
        # trouble connecting" — including a daily wall, where that advice is wrong.
        final_response = (
            _provider_failure_message(exc)
            or "I'm having trouble connecting right now. Please try again in a moment."
        )

    # Backstop: strip any internal tool name the model leaked into user-facing prose.
    final_response = _redact_tool_names(final_response)

    # Step 8 — persist both messages (ordered so replay stays user-then-assistant)
    await save_turn(
        conversation_id, user_id, user_message, final_response,
        model_used=answering_model(),
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

# ── Provider-failure messages ─────────────────────────────────────────────────
#
# These used to be one message for every kind of 429, which is why a user whose
# DAILY token budget was gone for the next several hours was told to "try again
# in a minute" — and did, every minute, to the same wall. Each cause now gets the
# truth, because the advice differs: wait a moment / come back later / say less /
# it's a configuration problem.

_RATE_LIMIT_MESSAGE = (
    "I'm getting a burst of requests right now and hit a brief rate limit. "
    "Please try again in a minute — nothing was lost, your trip details are safe."
)

_DAILY_QUOTA_MESSAGE = (
    "I've used up today's AI capacity on this account, so I can't reason about "
    "new trips until it resets. Nothing was lost and nothing was booked — your "
    "existing bookings are all still in My Bookings. Please try again later today."
)

_TOO_LARGE_MESSAGE = (
    "That conversation has grown too long for me to process in one go. Starting "
    "a fresh chat will fix it — your bookings and saved details stay exactly as "
    "they are."
)

_PROVIDER_DOWN_MESSAGE = (
    "My reasoning service isn't responding right now, so I can't work on that "
    "this moment. Nothing was booked or charged. Please try again shortly."
)

_MISCONFIGURED_MESSAGE = (
    "I can't reach my reasoning service — it looks like a configuration problem "
    "on our side rather than anything you did. Nothing was booked or charged."
)

_PROVIDER_MESSAGES = {
    QUOTA_MINUTE: _RATE_LIMIT_MESSAGE,
    QUOTA_DAILY: _DAILY_QUOTA_MESSAGE,
    REQUEST_TOO_LARGE: _TOO_LARGE_MESSAGE,
    INVALID_KEY: _MISCONFIGURED_MESSAGE,
}


def _provider_failure_message(exc: Exception) -> str | None:
    """The user-facing text for a typed provider failure, or None if it isn't one."""
    if not isinstance(exc, LLMError):
        return None
    return _PROVIDER_MESSAGES.get(error_kind(exc), _PROVIDER_DOWN_MESSAGE)


def _is_rate_limit_error(exc: Exception) -> bool:
    """True for either flavour of provider quota wall raised by llm_service."""
    return isinstance(exc, LLMError) and error_kind(exc) in (QUOTA_MINUTE, QUOTA_DAILY)


# Shown when our OWN turn-clock (not a provider) cut a call short. Distinct wording
# from _RATE_LIMIT_MESSAGE because the cause here is genuinely unknown — a slow or
# unresponsive fallback provider, not necessarily Groq's per-minute wall — and this
# fires only when generate_with_tools itself hung, so nothing was gathered to answer
# from either.
_TIMEOUT_MESSAGE = (
    "That's taking longer than it should on my end. Nothing was lost — please try "
    "again in a moment."
)

# Hand-written, not model output — _is_fabricated_booking must never scan these.
# _DAILY_QUOTA_MESSAGE's own reassurance ("nothing was booked — your existing
# bookings are all still in My Bookings") shape-matches _FAKE_CONFIRM_RE (a
# booking noun + a completion word), so without this exemption the turn's own
# honest "I'm out of capacity" message gets discarded and replaced with the
# unrelated _BOOKING_NOT_DONE_MSG — confirmed via direct regex testing and a
# live reproduction. The other five are exempted defensively: none currently
# match either regex, but they're equally code-authored, so a future wording
# tweak to any of them can't silently reopen this same failure.
# A trip-planner turn that fails must say so, not improvise. See
# _is_trip_planner_turn for why this exists instead of the legacy fallback.
_TRIP_PLANNER_FAILED_MESSAGE = (
    "I couldn't complete your trip plan right now. No booking was created and no "
    "payment was taken. Please try again."
)

_SCRIPTED_FALLBACK_MESSAGES = frozenset({
    _RATE_LIMIT_MESSAGE,
    _DAILY_QUOTA_MESSAGE,
    _TOO_LARGE_MESSAGE,
    _PROVIDER_DOWN_MESSAGE,
    _MISCONFIGURED_MESSAGE,
    _TIMEOUT_MESSAGE,
    _TRIP_PLANNER_FAILED_MESSAGE,
})


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


def _budget_verdict_note(
    other_calls: list,
    results: list,
    *,
    hub_car_pkr: float = 0.0,
    hub_car_label: str = "",
) -> str | None:
    """
    Deterministic whole-trip budget verdict, computed from the prices the search
    tools ACTUALLY returned this turn.

    The model is not trusted to do this arithmetic. Left to itself it reframed a
    whole-package budget as a per-night hotel ceiling, reported only that hotels
    were over, and never noticed the flight alone was ~50x the stated budget.
    The numbers here come from the tool results, so the verdict can't be wrong or
    quietly skipped. Returns None when there's no budget or nothing priced.

    `hub_car_pkr`/`hub_car_label` fold in the estimated hub->destination Car
    leg for a northern-destination trip (Naran/Hunza/Swat) — real transport
    still means flight/train AND car for these, so the total must too.
    """
    budget = None
    flight_pkr = train_pkr = hotel_per_night = 0.0
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
        elif name == "search_trains" and data.get("trains"):
            # Same per-seat basis as flights (see above), one level deeper —
            # each train offers several classes, so the cheapest is over ALL
            # of them, not just the first train returned.
            prices = [c.get("price_per_seat_pkr") or 0
                      for t in data["trains"] for c in t.get("classes", [])]
            prices = [p for p in prices if p > 0]
            if prices:
                train_pkr = min(prices)
                travelers = max(int(data.get("passengers") or 1), 1)
        elif name == "search_hotels" and data.get("hotels"):
            prices = [h.get("price_per_night_pkr") or 0 for h in data["hotels"]]
            prices = [p for p in prices if p > 0]
            if prices:
                hotel_per_night = min(prices)
                nights = max(int(data.get("nights") or 1), 1)
                rooms = max(int(args.get("rooms") or 1), 1)

    # Train is a substitute for flight, not additive — a trip only ever
    # travels by one of them, whichever was actually searched/cheaper.
    transport_pkr = flight_pkr or train_pkr

    if budget is None or budget <= 0 or (transport_pkr <= 0 and hotel_per_night <= 0):
        return None

    verdict = check_budget_feasibility(
        budget,
        flight_pkr=transport_pkr,
        travelers=travelers,
        hotel_per_night_pkr=hotel_per_night,
        nights=nights,
        rooms=rooms,
        transfer_pkr=hub_car_pkr,
    )
    car_part = (
        f" plus an estimated PKR {round(hub_car_pkr):,} car leg ({hub_car_label})"
        if hub_car_pkr else ""
    )
    return (
        "BUDGET CHECK (computed from the real prices above — state this verdict "
        "plainly to the user before offering options, and never contradict it): "
        f"{verdict['verdict']} Cheapest transport PKR {round(transport_pkr):,} x {travelers} "
        f"traveler(s){car_part}; cheapest hotel PKR {round(hotel_per_night):,}/night x {nights} "
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


# ── Atomic package failure ────────────────────────────────────────────────────
# A round trip or a flight+hotel package is ONE checkout. If some pieces verify
# and others don't, the only safe outcome is to commit NOTHING: a payment screen
# for half a round trip means the user pays, flies out, and finds on the day that
# there is no way back. These build the honest explanation that replaces it —
# with no `action` and no `booking_data`, so the app cannot render a pay button.

def _component_label(bd: dict) -> str:
    """A short human name for a booking piece, from the model's own arguments."""
    bd = bd if isinstance(bd, dict) else {}
    bt = str(bd.get("booking_type") or "")
    if bt == "hotel":
        where = bd.get("hotel_name") or bd.get("destination") or "the hotel"
        return f"the hotel ({where})"
    ident = str(bd.get("flight_number") or bd.get("train_name") or "").strip()
    route = ""
    if bd.get("origin") or bd.get("destination"):
        route = f"{bd.get('origin') or '?'} → {bd.get('destination') or '?'}"
    when = str(bd.get("travel_date") or "").strip()
    parts = [p for p in (ident, route, when) if p]
    return " ".join(parts) if parts else "that leg"


def _package_incomplete_message(
    verified: list[dict], failed: list[dict], expected: int,
    missing_labels: list[str] | None = None,
) -> str:
    """Explain which piece couldn't be prepared, and that nothing was charged.

    `missing_labels` — friendly component names (e.g. "Hotel", "Car Transfer
    (Islamabad -> Swat)") from get_trip_planner_incomplete_error's own output —
    is set only for a Trip Planner package the model failed to complete within
    its retries. It names exactly what's still missing instead of the generic
    wording below, using labels the backend already computed; nothing here is
    recalculated. Every other caller (an ordinary incomplete round trip, where
    there IS no fixed "required set" to name) is unaffected.
    """
    if missing_labels:
        # Same wording-safety note as below applies: no booking noun sits next
        # to a completion word, so this can never read as a fabricated confirm.
        return "\n\n".join([
            "I couldn't complete your trip package yet — some required "
            "components are still missing.",
            "Missing:\n" + "\n".join(f"- {label}" for label in missing_labels),
            "Nothing has been sent to payment, and no card has been charged.",
            "I'll first need to find these remaining services before I can "
            "generate your complete trip package.",
        ])

    ok_names = [_component_label(c) for c in verified]
    bad_names = [_component_label(c) for c in failed]
    # Wording note: this text must not trip _is_fabricated_booking. Phrases like
    # "nothing has been booked" pair a booking noun with a completion word and
    # read to that detector exactly like a fabricated confirmation, so the denial
    # is written without them — sentence breaks keep the two apart.
    lines = [
        "I couldn't set this up as a single trip. Nothing was sent to payment, "
        "and no card was charged."
    ]
    if ok_names:
        lines.append(f"✅ Ready to go: {', '.join(ok_names)}.")
    if bad_names:
        lines.append(
            f"❌ Not available to reserve right now: {', '.join(bad_names)}."
        )
    elif len(verified) < expected:
        missing = expected - len(verified)
        lines.append(
            f"❌ {missing} of the {expected} pieces you asked for couldn't be set up."
        )
    lines.append(
        "Going ahead with only part of it would leave you with half a trip, so I'd "
        "rather fix it first. Tell me which alternative you'd like for the missing "
        "part (or ask me to search that leg again) and I'll put the whole thing "
        "together in one go."
    )
    return "\n\n".join(lines)


def _car_booking_note(car_booking_data: dict | None) -> str:
    """
    A standalone car booking gated successfully this same turn, but a package
    or single booking is about to be returned instead — the response contract
    carries only one action per turn (see the ATOMIC PACKAGE GATE), so
    car_booking_data would otherwise be discarded with no trace at all. Say so
    plainly instead of silently dropping it; the user still has to ask again
    next turn to get the actual car_booking_choice confirm button, since this
    turn's action slot is already spoken for.
    """
    if not car_booking_data:
        return ""
    return (
        "\n\nI've also got your cab request ready — just ask me to confirm "
        "it and I'll set that up too."
    )


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


def _outstanding_other_components(
    conversation_user_texts: list[str], gathered: list[tuple[str, str]],
) -> set[str]:
    """
    Components besides transport (stay/car) the conversation asked for that
    AREN'T already covered by this turn's gathered results — used to decide
    whether rendering just the transport legs would silently drop the rest of
    a package. A hotel mentioned anywhere is only "still outstanding" if
    nothing has actually searched it yet in THIS turn; a car mention never
    clears (book_car is gated separately and never lands in `gathered`, so its
    presence should always hold off a transport-only render).
    """
    other = _components_in(" ".join(conversation_user_texts)) - {"transport"}
    if any(name == "search_hotels" for name, _ in gathered):
        other -= {"stay"}
    return other


# The traveller choosing every component is the default. Ready-made tiers are
# still built, but only when they actually ask to be recommended one rather
# than to choose — otherwise the app is picking their flight and hotel for them.
_RECOMMEND_RE = re.compile(
    r"\b(?:recommend|suggest|suggestion|pick for me|choose for me|decide for me|"
    r"best package|package options?|budget/standard|ready[- ]made|"
    r"what do you recommend|surprise me|up to you|whatever you think)\b",
    re.I,
)


def _wants_recommendations(user_texts: list[str] | None) -> bool:
    return any(_RECOMMEND_RE.search(t or "") for t in (user_texts or []))


# A transfer may also be picked by vehicle name alone ("SUV") with no digit
# at all — see trip_selection.parse_picks' vehicle-word branch. Kept as its
# own tiny, local check rather than reaching into trip_selection's private
# vocabulary, per "do not modify trip_selection.py".
_BARE_VEHICLE_RE = re.compile(r"^\s*(?:sedan|suv|van)\s*$", re.I)


def _looks_like_planner_continuation(user_message: str) -> bool:
    """
    True when `user_message` ALONE — no history available — reads as an
    answer to a previously-shown list or confirmation prompt: a bare pick
    ("Flight 2"), a multi-pick ("Flight 2, Hotel 3, Transfer 1"), a bare
    vehicle name ("SUV"), or a plain confirmation ("yes"). Reuses the same
    shape-detectors already trusted elsewhere in this file for exactly this
    judgment — no new parsing logic beyond the one vehicle-name check above.

    Used ONLY to decide, when the conversation history read has FAILED (see
    get_conversation_history/ConversationHistoryUnavailable), whether this
    turn must be refused outright rather than silently continued as if it
    were a brand-new conversation. A genuine new request ("Plan a trip to
    Hunza", "book me a sedan...") never matches any of these shapes, so it is
    unaffected and continues normally with an empty history — indistinguishable
    here from a real one, and deliberately left that way rather than guessed at.
    """
    return bool(
        _selected_index(user_message) is not None
        or _selected_indices(user_message)
        or trip_selection.is_confirmation(user_message)
        or _BARE_VEHICLE_RE.match(user_message or "")
    )


def _is_trip_planner_turn(
    user_message: str,
    history: list[dict] | None,
    trip_state,
    tool_names: list[str] | None,
) -> bool:
    """
    True when this turn is planning a northern trip, so an unexpected failure
    must NOT be handed to the legacy process_message pipeline.

    That pipeline answers through itinerary_agent, which is not bound by any of
    the gates in this file — no reprice_booking, no offer grounding, no
    "never invent a price". Observed output when a trip-planner turn fell
    through to it: a "Bus ISB -> GIL — PKR 15,000" and a "Taxi GIL -> Karimabad
    — PKR 5,000", neither a service this app sells nor a price anything
    returned. Failing closed is the only honest answer.

    Deliberately narrow so standalone requests keep their existing fallback:
    a live selection block settles it outright, and otherwise the turn must be
    doing an actual SEARCH — "book me a sedan to Naran" selects book_car alone
    and is a standalone car booking, not a trip plan.
    """
    if trip_selection.find_options(history):
        return True
    searching = {"search_flights", "search_trains", "search_hotels"} & set(tool_names or [])
    if not searching:
        return False
    destination = getattr(trip_state, "destination", "") or ""
    return (
        hub_options_for(destination) is not None
        or mentions_northern_destination(user_message, history)
    )


def _package_fill_call(
    still_needed: list[str],
    trip_state,
    transport_args: dict | None,
) -> tuple[str, dict] | None:
    """
    The search a half-finished trip-planner turn is missing, ready to dispatch —
    or None when its inputs aren't all known and it would have to be invented.

    The model is TOLD to run this search and routinely doesn't: observed on a
    real Hunza turn, it searched Karachi->Gilgit, was told "still needs hotels
    in Hunza", spent the next step searching Gilgit->Karachi instead, and ran
    out of steps with nothing to show — the turn dead-ended on "I'm having
    trouble responding right now." Every input is already pinned down in code
    by then, so the search is run here rather than asked for, exactly like the
    round-trip prefetch does. Same reasoning as every other deterministic gate
    in this file: a step the package cannot do without is not left to the model.

    Only the missing-hotel direction is filled. Transport is what a model
    reaches for first, so the reverse gap isn't what strands these turns — and
    picking a hub, a mode and an origin unprompted is real guesswork, which the
    nudge-then-ask fallback handles honestly instead.
    """
    if not any("search_hotels" in gap for gap in still_needed):
        return None
    if any("search_flights" in gap or "search_trains" in gap for gap in still_needed):
        return None                     # transport missing too — nothing to build on
    city = canonical_destination(getattr(trip_state, "destination", "") or "")
    if not city:
        return None

    args = transport_args or {}
    check_in = getattr(trip_state, "travel_date", "") or str(args.get("travel_date") or "")
    check_out = getattr(trip_state, "return_date", "") or ""
    if not check_out:
        # A stay length the user actually stated is fine; one we made up would
        # put an invented number of nights straight into the package price.
        nights = getattr(trip_state, "nights", None)
        if not (check_in and nights):
            return None
        try:
            check_out = (
                datetime.strptime(check_in, "%Y-%m-%d") + timedelta(days=int(nights))
            ).strftime("%Y-%m-%d")
        except (TypeError, ValueError):
            return None
    if not check_in or check_out <= check_in:
        return None

    fill: dict = {"city": city, "check_in": check_in, "check_out": check_out}
    guests = getattr(trip_state, "passengers", None) or args.get("passengers")
    try:
        if guests and int(guests) > 0:
            fill["guests"] = int(guests)
    except (TypeError, ValueError):
        pass                            # never guess a party size — omit it
    rooms = getattr(trip_state, "rooms", None)
    if rooms:
        fill["rooms"] = int(rooms)
    return "search_hotels", fill


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


# How many of the most recent turns stay verbatim, how hard older assistant turns
# are trimmed, and the overall ceiling on history sent to the model. Tuned for the
# package flow, which is by far the heaviest.
#
# These are tighter than they used to be (was 4 turns / 700 chars / no ceiling)
# because agents/conversation_state.py now re-states the route, dates, party size
# and budget in ~60 tokens. The facts a booking needs survive even when the tables
# they came from are cut, so the tables no longer have to ride along forever.
_HISTORY_RECENT_FULL = 3
_HISTORY_MAX_CHARS = 400
_HISTORY_TOTAL_CHARS = 4000     # ~1,000 tokens of conversation, newest first


# A return journey asked for anywhere in the recent conversation. Scanned over
# several turns because the request and the dates arrive separately: "round-trip
# Karachi to Hunza" then, two turns later, "5 August".
_ROUND_TRIP_RE = re.compile(
    r"\bround[\s-]?trip\b|\breturn\s+(?:flight|ticket|leg|journey|trip)\b"
    r"|\bcoming\s+back\b|\band\s+back\b|\bboth\s+ways\b|\btwo[\s-]way\b",
    re.I,
)
_ROUND_TRIP_LOOKBACK = 4


def _wants_round_trip(user_texts: list[str] | None) -> bool:
    return any(
        _ROUND_TRIP_RE.search(t)
        for t in (user_texts or [])[-_ROUND_TRIP_LOOKBACK:]
        if isinstance(t, str)
    )


# ── Deterministic round-trip prefetch ─────────────────────────────────────────
#
# A round trip with BOTH dates already known ("round trip flight, Lahore to
# Karachi, 2026-08-20 to 2026-08-25, 2 people") still cost two full LLM steps
# just to search each leg before a third step could even look at a booking —
# the model has to be asked for the tool call, read the result, then be asked
# again for the return leg. Every fact needed to run both searches is already
# sitting in the conversation in code-derivable form (agents/conversation_state
# .derive_state) once _wants_round_trip is true, so the searches themselves
# never need to wait on a reasoning step: run them here, deterministically, and
# hand the model (or the existing renderer, for a plain search) both legs
# already in hand.
#
# Mode words specific enough to name flights or trains without colliding with
# generic round-trip language. Deliberately narrower than prompt_builder's
# _FLIGHT_RE, which folds "round trip" / "one way" / "return flight" into its
# own flight signal — exactly the phrases _wants_round_trip fires on, so
# reusing it here would call every round-trip TRAIN request a flight. Ambiguous
# (neither, or both) means "don't guess" — the prefetch simply doesn't run, and
# the model resolves it exactly as it does today.
_TRAIN_MODE_RE = re.compile(
    r"\b(train|trains|rail|railway|railways|tezgam|khyber|green\s?line|"
    r"business\s?express|awam|jaffar|bogie|berth|coach)\b", re.I,
)
_FLIGHT_MODE_RE = re.compile(
    r"\b(flight|flights|fly|flying|flew|plane|air\s?line|airline|air\s?ticket|"
    r"pia|airblue|air\s?sial|serene|jazeera)\b", re.I,
)


def _round_trip_prefetch_mode(user_texts: list[str] | None) -> str | None:
    """'search_flights' / 'search_trains' / None (ambiguous — don't prefetch)."""
    text = " ".join(t for t in (user_texts or []) if isinstance(t, str))
    has_train = bool(_TRAIN_MODE_RE.search(text))
    has_flight = bool(_FLIGHT_MODE_RE.search(text))
    if has_train and not has_flight:
        return "search_trains"
    if has_flight and not has_train:
        return "search_flights"
    return None


def _last_assistant_text(history: list[dict] | None) -> str:
    for m in reversed(list(history or [])):
        if (m.get("role") or "").lower() == "assistant":
            text = m.get("content")
            return text.strip() if isinstance(text, str) else ""
    return ""


def _repeat_guard(history: list[dict] | None) -> str:
    """
    A nudge sent only when the previous reply ended in a question.

    Observed on device: asked "Round-trip available?" twice, the agent replied
    with the byte-identical sentence three times — "Can you please tell me what
    date you're planning to travel and how many passengers are traveling,
    bhai?". It had nothing to answer the question with and no search it could
    legally run without a date, so it fell back to the only script it had.
    Whatever the cause, sending the same sentence again reads like a broken bot
    rather than someone listening.

    Phrased CONDITIONALLY on purpose. Code cannot tell whether this turn
    answered the question — "2 August, 2 people" does, "is it available?" does
    not — so the note must not assert either. A hint that states a false
    premise is how it starts causing the behaviour it was added to prevent.
    """
    previous = _last_assistant_text(history)
    if not previous.endswith("?"):
        return ""
    return (
        "CONVERSATION CHECK: your previous reply ended by asking the user "
        "something. If their new message does NOT answer it, do not send that "
        "same question again — repeating a sentence word for word reads like a "
        "broken bot. Answer what they actually asked this turn first, in your "
        "own words, then ask for the missing detail differently and more "
        "briefly. If their message DOES answer it, simply carry on. Never "
        "mention this note."
    )


def _compact_history(history: list[dict]) -> list[dict]:
    """
    Shrink the history that goes to the MODEL, without touching `history` itself.

    A package turn emits very large assistant messages — six-row flight, hotel
    and train tables plus a budget breakdown. All twenty of those then rode along
    in EVERY later call, and on the free tier that bulk alone pushed a turn past
    the 52s budget: a plain "yes" to "shall I book the hotel?" timed out with
    nothing wrong except payload size.

    Two passes:
      1. Trim older ASSISTANT messages to _HISTORY_MAX_CHARS. User turns stay
         verbatim — they are what the party size, dates, addresses and car
         details are read from, and every provenance gate scans them — and the
         last few turns stay whole so immediate context is never lossy.
      2. Enforce a total ceiling, dropping the OLDEST turns first. Without it a
         long conversation grows without bound and eventually trips the
         provider's context limit as a 413 that no cooldown can fix.

    The caller keeps using the untrimmed `history` for the gates.
    """
    if not history:
        return []
    cutoff = len(history) - _HISTORY_RECENT_FULL
    trimmed: list[dict] = []
    for i, m in enumerate(history):
        content = m.get("content") or ""
        if (
            m.get("role") == "assistant"
            and i < cutoff
            and len(content) > _HISTORY_MAX_CHARS
        ):
            trimmed.append({
                **m,
                "content": content[:_HISTORY_MAX_CHARS].rstrip()
                + "\n…[earlier options trimmed — re-run the search if you need them]",
            })
        else:
            trimmed.append(m)

    # Newest-first accumulation, so what survives is always the recent context.
    kept: list[dict] = []
    budget = _HISTORY_TOTAL_CHARS
    for m in reversed(trimmed):
        size = len(m.get("content") or "")
        if kept and size > budget:
            break
        budget -= size
        kept.append(m)
    kept.reverse()
    return kept


def log_gate_failure(
    user_id: str, conversation_id: str, user_message: str,
    tool_name: str, args: dict, error: dict,
) -> None:
    """
    Fire-and-forget log for a prepare_booking/book_car gate rejection.
    These are never auto-retried — fixing them means guessing a date, a
    party size, or an address the caller didn't give, which is exactly what
    every one of these gates exists to prevent. Logged for a human to
    review whether the prompt (or, for a non-chat caller, the form) needs
    to ask more clearly up front.
    """
    asyncio.ensure_future(self_improvement.log_agent_failure(
        user_id=user_id, conversation_id=conversation_id,
        failure_type="slot_fill_failure", user_message=user_message,
        tool_name=tool_name, tool_args=args, error_detail=str(error.get("error")),
    ))


async def verify_booking_payload(
    bd: dict,
    *,
    user_message: str,
    history: list[dict],
    conversation_user_texts: list[str],
    trip_destination: str,
) -> tuple[dict | None, dict | None, dict]:
    """
    Run one prepare_booking payload through the exact gate sequence a
    model-issued call already goes through: missing fields, count, date,
    already-booked, transfer, then server-side reprice. Returns
    (verified, None, bd) on success or (None, error, bd) on the first
    failing gate — same checks, same order, whether the payload came
    from the model's own tool call (see the ATOMIC PACKAGE GATE in
    process_message_agentic) or was built deterministically for a plan
    the traveller already confirmed (see complete_trip_planner_confirmation),
    or — in future — a Trip Package UI submission. Module-level and
    parameterized (not a closure) specifically so every caller, chat or
    otherwise, goes through this ONE implementation; there must never be a
    second verification/repricing engine. The returned `bd` is the
    recovered payload actually checked, for callers that log or inspect it
    on failure.
    """
    bd = recover_booking_location(
        bd, [user_message, *(m.get("content", "") for m in reversed(history))]
    )
    missing = get_missing_booking_fields(bd)
    if missing:
        return None, missing_fields_result(missing), bd
    count_error = get_booking_count_error(bd)
    if count_error:
        return None, count_error, bd
    date_error = get_booking_date_error(bd)
    if date_error:
        return None, date_error, bd
    booked_error = get_already_booked_error(bd, history)
    if booked_error:
        return None, booked_error, bd
    transfer_error = get_transfer_error(
        bd, user_texts=conversation_user_texts, trip_destination=trip_destination,
    )
    if transfer_error:
        return None, transfer_error, bd
    bd = apply_traveler_totals(bd)
    verified = await reprice_booking(bd)
    if verified:
        return verified, None, bd
    return None, offer_not_found_result(), bd


async def complete_trip_planner_confirmation(
    plan, options, picks, pickup_location,
    *,
    user_id: str,
    conversation_id: str,
    user_message: str,
    history: list[dict],
    conversation_user_texts: list[str],
    trip_destination: str,
    travel_date_fallback: str,
) -> tuple[dict | None, dict | None]:
    """
    Try to complete a traveller-confirmed Trip Planner plan entirely in
    code, without asking the model to compose the prepare_booking calls.
    Everything needed (flight/train, hotel, and — once pickup_location is
    known — the transfer) is already known server-side from the plan
    itself (trip_selection.confirmation_booking_payloads), so this reuses
    the SAME gates and the SAME server-side reprice a model-issued call
    goes through — verify_booking_payload, above.

    Originally added because the ATOMIC PACKAGE GATE (in
    process_message_agentic) requires every component to land in ONE model
    turn, and a free-tier model was not reliably managing that for a Trip
    Planner confirmation — dropping the hotel on one attempt, the
    flight+transfer on the next, leaving the traveller stuck with nothing
    ever completing even after repeated "Yes". Module-level and
    parameterized so a future non-chat caller (e.g. a Trip Package UI
    submit endpoint) can drive the exact same deterministic booking engine
    the chat path uses — see CLAUDE.md's "one booking/payment engine"
    principle.

    Returns (booking_response, stale_component):
    - (dict, None) on success — the same {"response", "conversation_id",
      "action": "package_choice", "booking_data"} dict the existing package
      path always returned.
    - (None, {"booking_type": ..., "bd": ...}) when a component failed
      verification specifically because reprice_booking couldn't re-confirm
      the EXACT option any more (offer_not_found — e.g. a hotel that was
      live moments ago dropped out of a fresh search, a real, observed
      failure mode when the underlying provider changes results between the
      pick and the confirm). This is recoverable: `bd` is the failed
      payload, carrying everything needed to re-search that one category.
      The caller decides whether to act on it — chat auto-recovers (see
      process_message_agentic's _recover_stale_pick); a REST caller may
      just report it.
    - (None, None) for every other failure reason (missing fields, a bad
      date, already-booked, the transfer gate) — none of those are fixable
      by re-searching, so the caller falls back to its own next-best path,
      exactly as before this distinction existed.
    """
    payloads = trip_selection.confirmation_booking_payloads(
        plan, options, picks, pickup_location=pickup_location,
        fallback_date=travel_date_fallback,
    )
    verified_components: list[dict] = []
    for bd in payloads:
        verified, error, bd = await verify_booking_payload(
            bd,
            user_message=user_message,
            history=history,
            conversation_user_texts=conversation_user_texts,
            trip_destination=trip_destination,
        )
        if not verified:
            log_gate_failure(
                user_id, conversation_id, user_message,
                "prepare_booking", bd, error or {},
            )
            stale = (
                {"booking_type": bd.get("booking_type"), "bd": bd}
                if (error or {}).get("error") == "offer_not_found" else None
            )
            return None, stale
        verified_components.append(verified)
    # Same safety net the model-driven path runs — belt and braces, since
    # this already sent exactly transport + hotel (+ transfer once known).
    if get_trip_planner_incomplete_error(
        verified_components, history, trip_destination,
    ):
        return None, None
    package_data = build_package_data(verified_components)
    summary = format_package_summary(package_data)
    await save_turn(conversation_id, user_id, user_message, summary,
                     model_used=answering_model())
    asyncio.ensure_future(_log_task(
        user_id, conversation_id, "booking", user_message, package_data,
    ))
    return {
        "response": summary,
        "conversation_id": conversation_id,
        "action": "package_choice",
        "booking_data": package_data,
    }, None


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
    # Open attribution for this turn BEFORE any provider call, in the request's
    # own task, so whatever ends up answering (Groq, OpenRouter or Gemini) is
    # what gets written to the message record — see llm_service.begin_turn.
    begin_turn()

    # Step 1 — load context in parallel. Only the history fetch's own
    # exception is meant to be inspected below (see ConversationHistoryUnavailable
    # handling) — catching it locally, rather than via return_exceptions=True on
    # the whole gather, keeps get_user_memory/get_user_profile's result slot a
    # plain (dict, dict) tuple. With return_exceptions=True on the outer gather,
    # a future failure in either of those (both currently guaranteed not to
    # raise) would land here as a bare exception object, and unpacking
    # `(memory, profile)` from it would raise a confusing "cannot unpack
    # non-iterable" TypeError instead of the real error.
    async def _history_or_exception():
        try:
            return await get_conversation_history(conversation_id, limit=20)
        except Exception as exc:
            return exc

    (memory, profile), history_or_error = await asyncio.gather(
        asyncio.gather(get_user_memory(user_id), get_user_profile(user_id)),
        _history_or_exception(),
    )
    # A genuine empty history (a brand-new conversation) and a FAILED history
    # read both arrive as "nothing to work with" — but they are not the same
    # thing. Silently treating the second as the first is exactly how a
    # selection turn ("Flight 2, Hotel 3, Transfer 1") loses the option list
    # it's answering and gets read as the start of a new conversation instead
    # — see the forensic trace for this bug. get_conversation_history raises
    # ConversationHistoryUnavailable specifically so this can be told apart.
    if isinstance(history_or_error, BaseException):
        if _looks_like_planner_continuation(user_message):
            # This message only makes sense as an answer to something already
            # shown — with no history to recover what that was, silently
            # restarting would either re-ask questions the traveller already
            # answered or let the model guess at a booking with nothing real
            # to verify it against. Refuse instead: no LLM call, no legacy
            # fallback, no fabricated itinerary, no booking, no payment.
            logger.error(
                "conversation history unavailable for conv=%s on what looks "
                "like a trip-planner continuation (%r) — refusing rather "
                "than restarting", conversation_id, user_message[:60],
            )
            await save_turn(
                conversation_id, user_id, user_message, _TRIP_PLANNER_FAILED_MESSAGE,
                model_used="history-fetch-guard",
            )
            return {"response": _TRIP_PLANNER_FAILED_MESSAGE, "conversation_id": conversation_id}
        # Nothing about this message distinguishes it from a genuine first
        # turn, which also has an empty history — proceeding is the same
        # "never guess" posture this file uses everywhere else: no evidence
        # of harm, so no invented refusal.
        history: list[dict] = []
    else:
        history = history_or_error

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

    # ── Provider budget guard ─────────────────────────────────────────────────
    # Every configured provider is sitting on a KNOWN daily quota wall, reported
    # by the provider itself with its own reset time. Sending three more requests
    # to confirm that would burn the turn's clock to learn nothing, and the user
    # would wait ~40s for the same answer. Say it immediately and honestly. Only
    # a DAILY wall short-circuits here — a per-minute wall clears in seconds and
    # is always worth retrying.
    if all_providers_exhausted():
        logger.warning("all providers report a daily quota wall — short-circuiting turn")
        await save_turn(
            conversation_id, user_id, user_message, _DAILY_QUOTA_MESSAGE,
            model_used="quota-guard",
        )
        return {"response": _DAILY_QUOTA_MESSAGE, "conversation_id": conversation_id}

    memory_context = _format_memory(memory, profile)
    # PK date, not the host's. On a UTC server this line is what tells a
    # 2am Karachi user it is still yesterday, so their "tomorrow" books a
    # day early. Pakistan is UTC+5 — see core/pk_time.
    today = pk_today()

    # Only the tools this turn could plausibly use, and only the rule blocks that
    # match them. Sending all seven schemas and the full rule set cost ~8.9k tokens
    # on every call, which on Groq's free tier is ~11 calls before the DAILY token
    # budget refuses the next request — see agents/prompt_builder.py.
    turn_tool_names = select_tool_names(user_message, history)
    turn_tools = select_tools(user_message, history)
    # Hoisted so the deterministic transport-mode gate below (dispatch_tool_
    # with_retry's is_trip_planner) uses the EXACT same signal that decided
    # whether AGENTIC_TRIP_PLANNER_BLOCK is even in the prompt this turn —
    # rather than a second, possibly-differing computation of "is this a
    # Trip Planner turn". Named distinctly from the existing
    # _is_trip_planner_turn() FUNCTION (used further down, near the crash
    # fallback) — a local variable of that exact name would silently shadow
    # it for the rest of this function.
    _mentions_northern_dest_this_turn = mentions_northern_destination(user_message, history)
    system_prompt = build_system_prompt(
        today=today.isoformat(),
        weekday=today.strftime("%A"),
        memory=memory_context or "(no saved preferences yet)",
        tool_names=turn_tool_names,
        trip_planner=_mentions_northern_dest_this_turn,
    )

    # Route, dates, party size and budget pulled out of the conversation in code.
    # This is what makes the harder history trimming above safe: the facts a
    # booking needs survive in ~60 tokens even when the tables they came from
    # have been cut. Purely a hint — every booking gate still runs. Derived once
    # here so its `destination` can also ground the northern-hub fact below,
    # even on a follow-up turn that doesn't re-name the city.
    _trip_state = derive_state(history, user_message, today=today)

    # Grounded static facts (visa/baggage/rail-class/emergency/northern-hub) —
    # only added for turns where they're actually relevant, to stay within
    # Groq's TPM budget.
    facts = get_relevant_facts(user_message, _trip_state.destination)
    if facts:
        system_prompt += (
            "\n\n## Grounded facts for this turn — use these, don't contradict them\n"
            f"{facts}"
        )

    messages: list[dict] = [{"role": "system", "content": system_prompt}]
    # Trimmed for the model only — the gates below still read the full `history`.
    messages.extend(_compact_history(history))
    messages.append({"role": "user", "content": user_message})

    trip_hint = _trip_state.render()
    if trip_hint:
        messages.append({"role": "system", "content": trip_hint})

    repeat_hint = _repeat_guard(history)
    if repeat_hint:
        messages.append({"role": "system", "content": repeat_hint})

    # Deterministic pick-from-a-list nudge (see _selection_hint): when the user
    # answers a numbered list with "6" / "option 6" / "the second one", name the
    # exact item so the model converges in ONE prepare_booking call instead of
    # re-deriving it from the whole history under a tight turn budget — the thrash
    # that produced the "trouble responding" / "taking longer" replies. The booking
    # gates and server-side reprice still run, so this can never misbook.
    pick_hint = _selection_hint(user_message, history)
    # A pick answering a rendered TRIP PACKAGE list is resolved from that list
    # itself, not from the generic nudge above — which would name only the tier
    # ("Standard — PKR 402,265"), leaving the model to re-read its own prose for
    # which flight, which hotel and whether there was a car leg. That re-reading
    # is exactly where a package silently decomposes back into parts. Recovering
    # the components from our own rendered text keeps the pick exact.
    # The user's own messages in CHRONOLOGICAL order (oldest first, this turn
    # last). Shared by both provenance gates below and by the deterministic
    # Trip Planner confirmation path (hoisted up here so both can use it); the
    # car gate relies on the order to scope its scan to the car sub-conversation.
    conversation_user_texts = [
        *(m.get("content", "") for m in history if m.get("role") == "user"),
        user_message,
    ]

    def _log_gate_failure(tool_name: str, args: dict, error: dict) -> None:
        log_gate_failure(user_id, conversation_id, user_message, tool_name, args, error)

    async def _verify_booking_payload(bd: dict) -> tuple[dict | None, dict | None, dict]:
        # Thin closure over this turn's context — the actual gate sequence
        # lives in the module-level verify_booking_payload so a future
        # non-chat caller (e.g. a Trip Package UI submit endpoint) can drive
        # the identical checks. See that function's docstring.
        return await verify_booking_payload(
            bd,
            user_message=user_message,
            history=history,
            conversation_user_texts=conversation_user_texts,
            trip_destination=_trip_state.destination,
        )

    async def _recover_stale_pick(options: dict, stale: dict) -> dict | None:
        """
        A component the traveller already picked and confirmed could not be
        re-verified because the exact option is gone from a fresh search
        (offer_not_found) — observed in practice when an external provider's
        result set changes between the pick and the confirm (e.g. a hotel
        aggregator falling back to a different upstream mid-session). Rather
        than let that fall through to a model turn that (per the bug this
        closes) produces a dead-end "still missing: Hotel" message with no
        real next step, re-run the SAME search deterministically and
        re-render — reusing trip_selection.merge_fresh_search exactly as the
        "switched to business class mid-conversation" fix earlier does, just
        triggered by a stale re-verify instead of a fresh user request.
        Returns a plain {"response", "conversation_id"} reply (no booking
        action — the traveller re-picks from the refreshed list), or None if
        the re-search comes back empty too, in which case the caller falls
        back to its existing next-best path unchanged.
        """
        bd = stale["bd"]
        booking_type = stale.get("booking_type")
        passengers = bd.get("guests") or bd.get("adults") or options.get("passengers") or 1
        if booking_type == "hotel":
            tool_name = "search_hotels"
            args = {
                "city": bd.get("destination", ""),
                "check_in": bd.get("check_in", ""),
                "check_out": bd.get("check_out", ""),
                "guests": passengers,
                "rooms": bd.get("rooms") or 1,
            }
            stale_label = bd.get("hotel_name") or "the hotel you picked"
        elif booking_type in ("flight", "train"):
            tool_name = "search_flights" if booking_type == "flight" else "search_trains"
            args = {
                "origin_city": bd.get("origin", ""),
                "destination_city": bd.get("destination", ""),
                "travel_date": bd.get("travel_date", ""),
                "passengers": passengers,
            }
            if booking_type == "flight":
                args["cabin_class"] = bd.get("cabin_class") or "ECONOMY"
            stale_label = bd.get("flight_number") or bd.get("train_name") or "the option you picked"
        else:
            return None

        # has_user_date=True: this date came from the traveller's OWN already-
        # confirmed plan (built by confirmation_booking_payloads), not a
        # guess — the date-provenance gate exists to stop an INVENTED date,
        # which this is not.
        result_json = await self_improvement.dispatch_tool_with_retry(
            user_id=user_id, conversation_id=conversation_id, user_message=user_message,
            name=tool_name, args=args, has_user_date=True,
        )
        merged = trip_selection.merge_fresh_search(
            options, [(tool_name, result_json)],
            passengers=_trip_state.passengers or 0,
            preferred_mode=_trip_state.transport_mode,
        )
        if not merged:
            return None
        await save_planner_state(conversation_id, user_id, merged)
        reply = (
            f"{stale_label} is no longer available at that exact price — listings "
            "just changed. Nothing has been booked or charged. I've refreshed the "
            "options below; please pick again.\n\n"
            + trip_selection.render_options(merged)
        )
        await save_turn(conversation_id, user_id, user_message, reply,
                         model_used="deterministic-stale-recovery")
        return {"response": reply, "conversation_id": conversation_id}

    async def _complete_trip_planner_confirmation(plan, options, picks, pickup_location):
        # Thin closure over this turn's context — see the module-level
        # complete_trip_planner_confirmation's docstring.
        result, stale = await complete_trip_planner_confirmation(
            plan, options, picks, pickup_location,
            user_id=user_id,
            conversation_id=conversation_id,
            user_message=user_message,
            history=history,
            conversation_user_texts=conversation_user_texts,
            trip_destination=_trip_state.destination,
            travel_date_fallback=_trip_state.travel_date,
        )
        if result is not None:
            return result
        if stale is not None:
            recovered = await _recover_stale_pick(options, stale)
            if recovered is not None:
                return recovered
        return None

    # ── Interactive Trip Planner: resolve the traveller's component choices ──
    #
    # "Flight 2", "Hotel 1", "SUV" arrive over separate turns and each is
    # answered from the rendered option block alone — no model call at all, so
    # a selection can never be re-interpreted, re-priced or substituted. The
    # single exception is the final confirmation, which becomes a booking
    # instruction and rejoins the ordinary prepare_booking path.
    # Structured planner state (see memory_agent.save_planner_state) is tried
    # FIRST — a targeted, single-row lookup independent of the conversational
    # history window, so it survives the trip's options block falling outside
    # get_conversation_history's limit=20 in a long conversation. Absent,
    # stale, or a failed read all fall back to the original find_options(history)
    # text parser — byte-for-byte the same fallback path this already had,
    # preserved for every conversation that predates this feature.
    _planner_options: dict = {}
    _prior_picks: dict = {}
    _structured_state = await get_active_planner_state(conversation_id)
    if _structured_state and not trip_selection.is_valid_planner_state(_structured_state):
        # Defensive only — build_options() never produces anything but this
        # exact shape, so reaching here means the DB row is corrupted/
        # tampered. Treated exactly like "no state yet": never raise, fall
        # back to find_options(history) below.
        logger.warning(
            "structured planner state for conv=%s failed shape validation — "
            "falling back to find_options(history)", conversation_id,
        )
        _structured_state = None
    if _structured_state:
        _state_destination = _structured_state.get("destination") or ""
        # Same staleness rule as find_options' own fallback — reused, not
        # reimplemented, so structured state can't reopen the stale-options
        # bug that check already closes. Checked against every user message
        # this turn's history carries (always the most recent ones, so any
        # destination change genuinely more recent than the state is visible
        # here regardless of how old the state itself is).
        _recent_user_texts = [
            *(m.get("content", "") for m in history if m.get("role") == "user"),
            user_message,
        ]
        _state_stale = bool(_state_destination) and any(
            isinstance(t, str) and trip_selection.named_a_different_destination(t, _state_destination)
            for t in _recent_user_texts
        )
        if not _state_stale:
            _planner_options = _structured_state
            # The state's OWN picks — not find_picks(history), which is
            # exactly as window-bounded as find_options and would silently
            # "forget" a pick recorded further back than limit=20.
            _prior_picks = dict(_structured_state.get("picks") or {})
    if not _planner_options:
        _planner_options = trip_selection.find_options(history)
        _prior_picks = trip_selection.find_picks(history)
    # The optional return-leg offer (below) needs its own extra state
    # (_return_rows etc.) to survive to the NEXT turn, and only
    # save_planner_state/get_active_planner_state carry arbitrary extra keys
    # across turns — find_options(history)'s text-reparse fallback recovers
    # only what render_options' own AVAILABLE FLIGHTS/HOTELS/TRANSFERS shape
    # carries. So the offer itself is skipped (silently — the trip books
    # exactly as one-way, same as before this feature existed) whenever this
    # turn is running on that fallback rather than real structured state.
    _planner_options_are_structured = bool(_structured_state) and _planner_options is _structured_state
    if _planner_options:
        _merged = trip_selection.merge_picks(_planner_options, user_message, _prior_picks)
        if _merged.picks_changed:
            # Keep the structured record current so the NEXT turn's targeted
            # lookup (not find_options(history)) sees this turn's pick,
            # regardless of how deep in the conversation this turn ends up.
            await save_planner_state(
                conversation_id, user_id, {**_planner_options, "picks": _merged.picks})
        _plan_shown = trip_selection.plan_was_shown(history)
        _return_offered = trip_selection.return_was_offered(history)
        if _merged.problems:
            # Ambiguous or out-of-range: ask, never guess. Silently resolving
            # this is exactly how "Flight 2, Hotel 1, SUV" used to become
            # "package 2" and book something nobody chose.
            _reply = trip_selection.clarification(
                _merged.problems, _planner_options, _merged.picks)
            logger.info("trip selection needs clarification: %s", _merged.problems)
            await save_turn(conversation_id, user_id, user_message, _reply,
                            model_used=answering_model())
            return {"response": _reply, "conversation_id": conversation_id}
        if trip_selection.complete(_planner_options, _merged.picks):
            _plan = trip_selection.build_plan(_planner_options, _merged.picks)
            # A return leg resolved on an EARLIER turn (e.g. this turn is
            # only supplying the pickup address, or is the deterministic
            # booking call itself) has to be re-applied here every time —
            # `_plan` is rebuilt fresh from scratch each turn/request, so the
            # in-memory mutation apply_return_pick made on the turn the
            # traveller actually picked it does not itself survive; only the
            # persisted index does.
            if _plan and _planner_options.get("_return_resolved"):
                trip_selection.apply_return_pick(
                    _plan, _planner_options.get("_return_rows") or [],
                    _planner_options.get("_return_kind", ""),
                    _planner_options.get("_return_pick_index") or 0,
                )
            # Resolving the "would you like a return trip?" question asked on
            # the PREVIOUS turn (see the return-leg offer further down) takes
            # priority over everything else below: a bare "2" or "no thanks"
            # here must never be misread as an outbound pick change, a fresh
            # "yes, proceed", or a pickup-address follow-up answer.
            _resolving_return = bool(
                _plan and _return_offered and _planner_options.get("_return_rows")
                and not _planner_options.get("_return_resolved")
            )
            if _resolving_return:
                _return_rows = _planner_options.get("_return_rows") or []
                _return_pick = trip_selection.parse_return_pick(user_message, _return_rows)
                if _return_pick is None:
                    _reply = trip_selection.render_return_options(
                        _return_rows, _planner_options.get("_return_origin", ""),
                        _planner_options.get("_return_date", ""),
                    )
                    await save_turn(conversation_id, user_id, user_message, _reply,
                                    model_used=answering_model())
                    return {"response": _reply, "conversation_id": conversation_id}
                if _return_pick and _plan:
                    trip_selection.apply_return_pick(
                        _plan, _return_rows, _planner_options.get("_return_kind", ""),
                        _return_pick,
                    )
                # Remember the return leg was already handled (and which row,
                # so the re-apply above can rebuild the SAME choice on every
                # later turn) — this also stops the offer or this branch from
                # ever re-triggering for the same plan.
                _planner_options = {
                    **_planner_options, "_return_resolved": True,
                    "_return_pick_index": _return_pick,
                }
                await save_planner_state(conversation_id, user_id, _planner_options)
            _confirming = _resolving_return or (
                _plan_shown and not _merged.picks_changed
                and trip_selection.is_confirmation(user_message)
            )
            if _plan and _confirming:
                if not _resolving_return:
                    # A genuinely fresh "yes, proceed" — before asking for the
                    # pickup address or booking, offer a return leg if the
                    # traveller gave a real second (return) date anywhere in
                    # the conversation. Searched deterministically server-side
                    # (never left to the model — see hub_mismatch_error's own
                    # reasoning for why that matters), and skipped entirely
                    # when no real return date exists, or it was already
                    # resolved once for this plan. A traveller who never gave
                    # a return date sees no change at all from today.
                    _return_date_signal = (
                        _trip_state.return_date
                        if _trip_state.return_date != _trip_state.travel_date else ""
                    )
                    if (
                        _return_date_signal and _planner_options_are_structured
                        and not _planner_options.get("_return_resolved")
                    ):
                        _outbound_rows = _planner_options.get("transport") or [{}]
                        _return_hub = _outbound_rows[0].get("destination", "")
                        _return_origin = _outbound_rows[0].get("origin", "")
                        _return_kind = _planner_options.get("transport_kind") or "flight"
                        if _return_hub and _return_origin:
                            _return_tool = (
                                "search_flights" if _return_kind == "flight" else "search_trains")
                            _return_args: dict = {
                                "origin_city": _return_hub, "destination_city": _return_origin,
                                "travel_date": _return_date_signal,
                                "passengers": _planner_options.get("passengers") or 1,
                            }
                            if _return_kind == "flight":
                                _return_args["cabin_class"] = (
                                    _outbound_rows[0].get("cabin") or "ECONOMY")
                            try:
                                _return_raw = await self_improvement.dispatch_tool_with_retry(
                                    user_id=user_id, conversation_id=conversation_id,
                                    user_message=user_message, name=_return_tool,
                                    args=_return_args, has_user_date=True,
                                )
                            except Exception:
                                logger.warning(
                                    "return-leg prefetch failed — offering the plan one-way",
                                    exc_info=True,
                                )
                                _return_raw = None
                            _return_rows_found, _return_kind_found = (
                                trip_selection.build_return_options([(_return_tool, _return_raw)])
                                if _return_raw else ([], "")
                            )
                            if _return_rows_found:
                                _return_state = {
                                    **_planner_options, "_return_rows": _return_rows_found,
                                    "_return_kind": _return_kind_found,
                                    "_return_origin": _return_origin,
                                    "_return_date": _return_date_signal,
                                }
                                await save_planner_state(
                                    conversation_id, user_id, _return_state)
                                _reply = trip_selection.render_return_options(
                                    _return_rows_found, _return_origin, _return_date_signal)
                                await save_turn(conversation_id, user_id, user_message, _reply,
                                                model_used=answering_model())
                                return {"response": _reply, "conversation_id": conversation_id}
                            # Nothing found for the return leg — fall through
                            # and book one-way, exactly as if no return date
                            # had ever been given.
                if _plan.transfer:
                    # Everything else is already known server-side, but the
                    # transfer's pickup address isn't -- ask directly, in
                    # code, rather than let the model decide when/whether to
                    # ask (it was inconsistently dropping the transfer, or
                    # the hotel, or both, trying to juggle that itself — see
                    # _complete_trip_planner_confirmation). The traveller's
                    # next reply resumes below as a follow-up answer.
                    _dest = _planner_options.get("destination") or _trip_state.destination
                    _reply = (
                        f"Your {_dest} trip (PKR {_plan.total_pkr:,}) is confirmed. "
                        f"I just need the pickup address at {_plan.transfer['hub']} "
                        f"for the {_plan.transfer['vehicle']} transfer, then I'll "
                        "book the whole trip in one checkout."
                    )
                    await save_turn(conversation_id, user_id, user_message, _reply,
                                    model_used=answering_model())
                    return {"response": _reply, "conversation_id": conversation_id}
                _completed = await _complete_trip_planner_confirmation(
                    _plan, _planner_options, _merged.picks, "")
                if _completed is not None:
                    return _completed
                # Fall back to the model-driven path — unchanged safety net
                # for whatever made the deterministic attempt above decline
                # (e.g. the fresh reprice couldn't confirm an option anymore).
                pick_hint = trip_selection.booking_instruction(
                    _plan, _planner_options, _merged.picks)
                # This turn books, so it needs the booking schema even though
                # the confirmation itself ("yes") looks like nothing.
                if "prepare_booking" not in turn_tool_names:
                    turn_tool_names = [*turn_tool_names, "prepare_booking"]
                    turn_tools = select_tools_by_name(turn_tool_names)
                logger.info(
                    "trip plan confirmed — booking %s + hotel%s as one checkout",
                    _plan.transport_kind, " + transfer" if _plan.transfer else "",
                )
            elif (
                _plan and not _plan_shown and not _merged.picks_changed
                and trip_selection.looks_like_a_followup_answer(user_message)
            ):
                # The plan was already confirmed on an earlier turn (the last
                # message shown was neither the option list nor the plan card
                # — it was the assistant's own follow-up question, e.g. "what's
                # the pickup address?"), and this reply neither picked/changed
                # a component nor reads as a question. Rather than silently
                # re-answering with the same Trip Plan (the bug this closes),
                # let it reach the real booking turn as an answer.
                if _plan.transfer and trip_selection.looks_like_a_bare_number(user_message):
                    # A lone number here is never a real pickup address —
                    # most likely a stray reply to some other question (e.g.
                    # the model free-lancing an over-budget "1/2/3" choice on
                    # an earlier, now-superseded turn — the confirmation path
                    # above no longer reaches the model at this point, so
                    # that shouldn't recur, but a bare number is never a
                    # street address regardless of where it came from). Ask
                    # plainly rather than let it slip through the transfer
                    # gates as literal address text, or get silently
                    # misrouted to the model.
                    _reply = (
                        "That doesn't look like a pickup address — could you "
                        f"give me the street address for pickup at {_plan.transfer['hub']}?"
                    )
                    await save_turn(conversation_id, user_id, user_message, _reply,
                                    model_used=answering_model())
                    return {"response": _reply, "conversation_id": conversation_id}
                if _plan.transfer:
                    # A real answer very often echoes "pickup address is..."
                    # back naturally — strip just that leading frame so it
                    # isn't mistaken for the placeholder text that exact
                    # wording usually signals when a MODEL produces it
                    # instead (see trip_selection.clean_pickup_reply).
                    _pickup = trip_selection.clean_pickup_reply(user_message)
                    _completed = await _complete_trip_planner_confirmation(
                        _plan, _planner_options, _merged.picks, _pickup)
                    if _completed is not None:
                        return _completed
                # Fall back to the model-driven path — every existing gate
                # (get_transfer_error, reprice_booking, the atomic package
                # gate) still runs on whatever the model calls, unchanged.
                pick_hint = trip_selection.booking_instruction(
                    _plan, _planner_options, _merged.picks)
                if "prepare_booking" not in turn_tool_names:
                    turn_tool_names = [*turn_tool_names, "prepare_booking"]
                    turn_tools = select_tools_by_name(turn_tool_names)
                logger.info(
                    "trip plan follow-up answer (%r) — resuming booking, not "
                    "re-rendering", user_message[:60],
                )
            elif (
                _plan and _plan_shown and not _merged.picks_changed
                and trip_selection.looks_like_a_budget_objection(user_message)
            ):
                # Free-text budget pushback right after the plan card ("its
                # not in my budget") named no pick and isn't a recognized
                # confirmation, so it used to fall straight into the plain
                # re-render below — the exact same card, verbatim, with no
                # acknowledgement and no path forward. Answer it directly
                # instead of silently repeating the plan.
                _reply = trip_selection.budget_objection_reply(
                    _plan, _trip_state.budget_pkr)
                await save_turn(conversation_id, user_id, user_message, _reply,
                                model_used=answering_model())
                return {"response": _reply, "conversation_id": conversation_id}
            elif _plan:
                _reply = trip_selection.render_plan(
                    _plan, _planner_options, _merged.picks,
                    _planner_options.get("destination") or _trip_state.destination,
                    budget_pkr=_trip_state.budget_pkr,
                    travel_date=_trip_state.travel_date,
                    return_date=_trip_state.return_date,
                )
                await save_turn(conversation_id, user_id, user_message, _reply,
                                model_used=answering_model())
                return {"response": _reply, "conversation_id": conversation_id}
        elif _merged.picks_changed:
            # Something was chosen but the trip isn't complete — show what's
            # left, with the choice so far recorded on the block itself.
            _reply = trip_selection.render_options(
                {**_planner_options, "picks": _merged.picks})
            await save_turn(conversation_id, user_id, user_message, _reply,
                            model_used=answering_model())
            return {"response": _reply, "conversation_id": conversation_id}

    _picked_number = _selected_index(user_message)
    if _picked_number is not None and not pick_hint:
        _rendered_packages = trip_package.find_rendered(history)
        _picked_package = _rendered_packages.get(_picked_number)
        if _picked_package:
            pick_hint = trip_package.selection_instruction(_picked_package)
            logger.info(
                "trip package %d picked (%s) — booking %d component(s) as one checkout",
                _picked_number, _picked_package.get("tier", "?"),
                2 if _picked_package.get("hotel_name") else 1,
            )
    if pick_hint:
        messages.append({"role": "system", "content": pick_hint})

    booking_data: dict | None = None
    car_booking_data: dict | None = None
    # Every server-repriced component prepared this turn. 2+ => a package.
    package_components: list[dict] = []
    # Atomicity bookkeeping — see the ATOMIC PACKAGE GATE inside the loop.
    user_picks: list[int] = _selected_indices(user_message)
    expected_components: int = 0
    package_incomplete: bool = False
    package_ok: list[dict] = []
    package_failed: list[dict] = []
    # Friendly labels from the LAST get_trip_planner_incomplete_error this turn
    # attempted (see the ATOMIC PACKAGE GATE) — only set for a Trip Planner
    # package, used solely to make the post-retry fallback message name what's
    # actually missing instead of the generic wording every other caller keeps.
    trip_planner_missing_labels: list[str] = []
    final_text: str = ""
    # Set alongside final_text whenever this turn renders a FRESH interactive-
    # planner options block, so it can be persisted as structured state
    # (see memory_agent.save_planner_state) at the same point final_text is
    # saved — never populated by the trip_package/tier or deterministic-reply
    # renderers, which are a different feature.
    _new_planner_options: dict | None = None
    tools_used: list[str] = []
    learned: dict = {}
    gathered: list[tuple[str, str]] = []  # (tool_name, result_json) — real data we collected
    turn_transport_args: dict = {}       # args of this turn's first transport search

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

    started = time.monotonic()

    # See _round_trip_prefetch_mode above. Skipped whenever pick_hint is set —
    # a pick must resolve against the EXACT list the user is replying to by
    # position ("1 for outbound and 2 for return"), and a fresh search can come
    # back reordered or re-priced, which would silently point the pick at the
    # wrong flight. Every other round trip with both dates already known is
    # fair game, including a follow-up refinement ("actually make it 3
    # people") — re-running the search is exactly what the model would have
    # done itself, just without spending a step to do it.
    prefetch_mode = (
        _round_trip_prefetch_mode(conversation_user_texts[-_ROUND_TRIP_LOOKBACK:])
        if _wants_round_trip(conversation_user_texts) and not pick_hint
        else None
    )
    trip_state = None
    if prefetch_mode:
        trip_state = derive_state(history, user_message, today=today)
        mode_prepared = "flight" if prefetch_mode == "search_flights" else "train"
        if not (
            trip_state.origin and trip_state.destination
            and trip_state.travel_date and trip_state.return_date
            and mode_prepared not in trip_state.prepared
        ):
            prefetch_mode = None
            trip_state = None

    if prefetch_mode and trip_state is not None:
        pax = trip_state.passengers or 1
        outbound_args = {
            "origin_city": trip_state.origin, "destination_city": trip_state.destination,
            "travel_date": trip_state.travel_date, "passengers": pax,
        }
        return_args = {
            "origin_city": trip_state.destination, "destination_city": trip_state.origin,
            "travel_date": trip_state.return_date, "passengers": pax,
        }
        try:
            prefetch_raw = await asyncio.wait_for(
                asyncio.gather(
                    self_improvement.dispatch_tool_with_retry(
                        user_id=user_id, conversation_id=conversation_id, user_message=user_message,
                        name=prefetch_mode, args=outbound_args, has_user_date=user_dates_known,
                    ),
                    self_improvement.dispatch_tool_with_retry(
                        user_id=user_id, conversation_id=conversation_id, user_message=user_message,
                        name=prefetch_mode, args=return_args, has_user_date=user_dates_known,
                    ),
                    return_exceptions=True,
                ),
                timeout=_time_left(started),
            )
        except Exception:
            logger.warning("round-trip prefetch timed out — falling back to the normal loop", exc_info=True)
            prefetch_raw = None

        if prefetch_raw is not None and not any(isinstance(r, BaseException) for r in prefetch_raw):
            _absorb_learned(learned, outbound_args)
            # Every element was just proven not a BaseException above — the
            # isinstance check itself is what dispatch_tool_with_retry's
            # return_exceptions=True union requires; cast narrows the type,
            # not the value.
            prefetch_results = cast("list[str]", prefetch_raw)
            prefetched: list[tuple[str, str]] = [(prefetch_mode, r) for r in prefetch_results]
            tools_used.append(prefetch_mode)
            gathered.extend(prefetched)
            # Same shape the real loop produces after a genuine tool-calling
            # step (assistant tool_calls message, then one tool result per
            # call) — see below — so the model reads this exactly like its
            # own earlier tool round, and nothing downstream (history replay,
            # provider request shape) needs to know it never actually asked.
            prefetch_tool_calls = [
                {"id": f"prefetch-out-{uuid.uuid4().hex[:8]}", "type": "function",
                 "function": {"name": prefetch_mode, "arguments": json.dumps(outbound_args)}},
                {"id": f"prefetch-ret-{uuid.uuid4().hex[:8]}", "type": "function",
                 "function": {"name": prefetch_mode, "arguments": json.dumps(return_args)}},
            ]
            messages.append({"role": "assistant", "content": None, "tool_calls": prefetch_tool_calls})
            for (_, content), tc in zip(prefetched, prefetch_tool_calls):
                messages.append({"role": "tool", "tool_call_id": tc["id"], "content": content})

            # The plain-search case: nothing left to decide, so answer straight
            # from these two results exactly as the in-loop renderer would —
            # same should_render/render, just reached before any LLM call runs
            # instead of after one or two of them. Anything needing judgement
            # (a budget verdict, planning/package prose) declines here exactly
            # as it always has, and the model takes the turn with both legs
            # already in context instead of needing to search for them itself.
            # A hotel or car mentioned anywhere in the conversation means this
            # is a package, not a plain search — the two transport legs are
            # only PART of the answer, and rendering just those two would
            # silently drop the rest of what the user asked for. should_render
            # can't see that on its own (it only ever sees the transport
            # results), so it's checked here before the fast path is even
            # attempted. See _outstanding_other_components — shared with the
            # equivalent guard on the general in-loop renderer below.
            other_components = _outstanding_other_components(conversation_user_texts, prefetched)
            if not other_components and deterministic_reply.should_render(
                prefetched, user_message,
                has_budget_note=False, has_pick_hint=bool(pick_hint),
                round_trip_incomplete=False,
            ):
                rendered = deterministic_reply.render(prefetched, user_message)
                if rendered:
                    logger.info(
                        "deterministic reply for prefetched round trip (%s) — "
                        "skipped the tool-calling loop entirely", prefetch_mode,
                    )
                    final_text = rendered

    try:
        for step in range(_MAX_TOOL_STEPS if not final_text else 0):
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
            logger.info(
                "agent step %d — est_in=%d tokens tools=%s",
                step + 1,
                estimate_request_tokens(messages, turn_tools),
                ",".join(turn_tool_names),
            )
            msg = await asyncio.wait_for(
                generate_with_tools(
                    messages, tools=turn_tools, temperature=0.4, max_output_tokens=1200,
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
            # Components verified IN THIS STEP. A package must be assembled in one
            # reply (that is the rule the model is given), so this list is per-step
            # rather than cumulative — otherwise a leg verified in step 1 and a
            # different leg in step 3 would silently become a "package" the user
            # never saw offered together.
            step_components: list[dict] = []
            step_failures: list[dict] = []
            # Calls refused because that component is already paid for. Counted
            # apart from step_failures because it is NOT a failure of this
            # checkout — the piece simply isn't part of it, so it must not make
            # the package look short and withhold the piece that IS new.
            already_booked = 0
            for tc in booking_calls:
                bd = _safe_args(tc.function.arguments)
                # Same gate sequence _complete_trip_planner_confirmation's
                # deterministic payloads go through, above — single source of
                # truth, so a model-issued call and a server-built one can
                # never be checked differently.
                verified, error, bd = await _verify_booking_payload(bd)
                if verified:
                    # Collect EVERY component the model prepared this turn, not just
                    # the first. A package ("flight + hotel + car", or the two legs
                    # of a round trip) is exactly this: several prepare_booking calls
                    # in one turn, each independently gated and server-repriced by
                    # the code above. Two or more verified components become a single
                    # package_choice with one combined total, so the user fills
                    # passenger details once and pays once.
                    step_components.append(verified)
                    continue
                # _verify_booking_payload always returns one of (verified,
                # error) non-None — this narrows `error` for the checker.
                assert error is not None
                booking_gate_results[tc.id] = error
                if error.get("error") == "already_booked":
                    # Already paid for, earlier in this same conversation. NOT a
                    # failure of this checkout — the piece simply isn't part of
                    # it, so it must not make the package look short and
                    # withhold the piece that IS new.
                    already_booked += 1
                else:
                    step_failures.append(bd)
                _log_gate_failure("prepare_booking", bd, error)

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

            # ── ATOMIC PACKAGE GATE ───────────────────────────────────────────
            # How many pieces this checkout is SUPPOSED to contain: whichever is
            # larger of what the user picked ("1 for outbound and 3 for return"
            # = 2) and what the model actually attempted. Taking the max matters
            # in both directions — the user's picks catch a model that only
            # prepared one leg, and the model's calls catch a package the user
            # described in prose rather than by numbers.
            if booking_calls:
                # Pieces already paid for don't belong to this checkout, so they
                # don't count towards what it owes. Without this, re-proposing a
                # paid flight alongside a genuinely new hotel would make the
                # package look incomplete and withhold the hotel too.
                expected_components = max(
                    len(booking_calls) - already_booked, len(user_picks), 1
                )
                # Trip Planner mode (a recognised northern destination): transport,
                # hotel, and — for a hub-less destination — the car transfer must
                # ALL be prepared together. A single verified leg that happens to
                # satisfy expected_components (e.g. the user only picked one item
                # this turn because a hotel was never even searched) must still
                # not reach payment on its own.
                trip_planner_error = get_trip_planner_incomplete_error(
                    step_components, history, _trip_state.destination,
                )
                if len(step_components) >= expected_components and not trip_planner_error:
                    package_components = step_components
                    booking_data = step_components[0]
                    package_incomplete = False
                    break
                # Not every piece survived, or (Trip Planner mode) not every
                # REQUIRED piece was even attempted. Committing what DID verify
                # would hand the user a payment screen for part of the trip —
                # they pay, then discover the rest still isn't booked. So nothing
                # is committed: the gate errors go back to the model, which can
                # re-search or ask, and if the turn ends still short we return an
                # explanation with NO payment action attached.
                if expected_components >= 2 or trip_planner_error:
                    package_incomplete = True
                    package_ok = step_components
                    package_failed = step_failures
                    trip_planner_missing_labels = (
                        trip_planner_error["missing_labels"] if trip_planner_error else []
                    )
                    logger.warning(
                        "package incomplete — %d of %d component(s) verified "
                        "(trip_planner_error=%s); withholding payment action",
                        len(step_components), expected_components, bool(trip_planner_error),
                    )
                    # Tell the model what is missing. The per-call gate errors
                    # below only cover calls that FAILED; when the model simply
                    # never made the second call (or never searched a required
                    # piece at all, in Trip Planner mode) there is no error to
                    # feed back, and that silence is how a partial booking used
                    # to slip through.
                    messages.append({"role": "system", "content": (
                        trip_planner_error["instruction"] if trip_planner_error else (
                            f"INCOMPLETE PACKAGE: this checkout needs {expected_components} "
                            f"pieces but only {len(step_components)} could be confirmed. "
                            "Nothing has been sent to payment. Prepare EVERY remaining "
                            "piece in your next reply, or — if a piece genuinely isn't "
                            "available — tell the user plainly which one and ask them to "
                            "pick a replacement. Never proceed with only part of it."
                        )
                    )})

            if car_booking_data:
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
                      name=tc.function.name, args=args, has_user_date=user_dates_known,
                      is_trip_planner=_mentions_northern_dest_this_turn,
                      has_transport_mode=bool(_trip_state.transport_mode),
                      trip_destination=_trip_state.destination or "")
                  for tc, args in other_calls],
                return_exceptions=True,
            )
            for (tc, args), res in zip(other_calls, results):
                tools_used.append(tc.function.name)
                _absorb_learned(learned, args)
                # The transport leg the model actually searched — the date it
                # resolved is the check-in a missing hotel search needs, and
                # it's a fact from this turn rather than a re-parse of prose.
                if tc.function.name in ("search_flights", "search_trains") and not turn_transport_args:
                    turn_transport_args = dict(args)
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
            hub_fare = (
                estimate_hub_car_fare(_trip_state.destination) if _trip_state.destination else None
            )
            budget_note = _budget_verdict_note(
                other_calls, results,
                hub_car_pkr=(hub_fare[0] if hub_fare else 0),
                hub_car_label=(hub_fare[1] if hub_fare else ""),
            )
            if budget_note:
                gathered.append(("budget_check", budget_note))
                messages.append({"role": "system", "content": budget_note})

            # ── Deterministic answer for a plain search ───────────────────────
            # A search turn otherwise costs a SECOND provider call whose only job
            # is to reformat results we already have — and that second call
            # carries the whole tool payload back up, so it is the more expensive
            # of the two. When the turn is simple enough (see should_render), the
            # list is formatted in code instead: half the tokens, and the prices,
            # flight numbers and hospital phone numbers are copied rather than
            # re-typed by a model. Anything needing judgement (a budget verdict,
            # planning, a package, a pick) fails the gate and keeps the LLM.
            # A round trip that only got one leg searched must not be rendered
            # as a finished list — see should_render. The model needs the turn so
            # it can ask for the return date.
            one_leg = (len(gathered) == 1
                       and gathered[0][0] in ("search_flights", "search_trains"))
            # A hotel or car also asked for anywhere in this conversation means
            # the two transport legs are only PART of the answer — rendering
            # just those and breaking the loop silently drops the rest of a
            # "round trip flight AND hotel" request with no acknowledgement
            # that anything is still missing. Reachable whenever the model
            # searches both legs across two separate steps before ever
            # reaching the hotel (see agents/deterministic_reply.should_render:
            # two same-tool renderable results is otherwise sufficient to
            # render). Same guard as the round-trip prefetch's own fast path —
            # see _outstanding_other_components, which also correctly stops
            # objecting once a hotel search actually IS among this turn's
            # results (a plain hotel-only search must still render).
            # ── Trip Planner: answer with complete PACKAGES, not a parts list ──
            # A northern trip is a package product, not a flight search that
            # happens to mention a hotel. Once this turn holds transport AND
            # hotel results, they are combined into whole priced itineraries
            # (transport + stay + the hub transfer) and compared against the
            # stated budget — so the traveller picks a TRIP rather than being
            # handed the parts to assemble themselves. Composed in code for the
            # same reason every other total is: a package total is money, and
            # money is never left to the model to add up.
            # Skipped on a pick turn — then the job is to BOOK the chosen
            # package, not to re-list them.
            #
            # The traveller chooses each component. Auto-composed tiers used to
            # be rendered here instead, which meant the app picked their flight,
            # their hotel and their vehicle in order to have a package to show.
            # Now the real options are listed per category and they select from
            # them; tiers remain available only when they explicitly ask to be
            # recommended one (_wants_recommendations).
            if not booking_calls and not car_calls and not pick_hint:
                rendered = ""
                if _wants_recommendations(conversation_user_texts):
                    if trip_package.can_build(gathered, _trip_state.destination):
                        packages = trip_package.build(gathered, _trip_state.destination)
                        rendered = trip_package.render(
                            packages, _trip_state.destination,
                            budget_pkr=_trip_state.budget_pkr,
                        )
                        if rendered:
                            logger.info(
                                "TRIP PACKAGES (recommendations asked for) for %s — %d option(s)",
                                _trip_state.destination, len(packages),
                            )
                else:
                    # The traveller asked for a mode we have nothing for. Say so
                    # and ask — switching them to the other one is a decision
                    # that belongs to them, and composing the trip around it
                    # would silently price a different hub.
                    _alternative = trip_selection.preferred_transport_missing(
                        gathered, _trip_state.transport_mode,
                    )
                    if _alternative:
                        logger.info(
                            "no %s options for %s — offering %s rather than switching",
                            _trip_state.transport_mode, _trip_state.destination,
                            _alternative,
                        )
                        rendered = trip_selection.no_preferred_transport_message(
                            _trip_state.transport_mode, _alternative,
                        )
                    elif trip_selection.can_offer(
                        gathered, _trip_state.destination,
                        preferred_mode=_trip_state.transport_mode,
                    ):
                        _options = trip_selection.build_options(
                            gathered, _trip_state.destination,
                            passengers=_trip_state.passengers or 0,
                            preferred_mode=_trip_state.transport_mode,
                        )
                        rendered = trip_selection.render_options(_options)
                        if rendered:
                            logger.info(
                                "interactive TRIP OPTIONS for %s (%s) — %d transport, "
                                "%d hotel, %d transfer", _trip_state.destination,
                                _trip_state.transport_mode or "any mode",
                                len(_options["transport"]), len(_options["hotels"]),
                                len(_options["transfers"]),
                            )
                            _new_planner_options = _options
                    else:
                        # This turn's own gathered results can't stand alone as a
                        # full options block (e.g. "I want business class
                        # flights" only re-searched transport, not hotels) — but
                        # options ARE already active for this destination. Merge
                        # the fresh category onto them rather than let the model
                        # answer from raw search data in free text, which reads
                        # fine but never updates the SAVED state: the traveller
                        # would see real fresh prices and then have a later pick
                        # silently resolve against the stale, pre-refresh ones.
                        _merged_options = trip_selection.merge_fresh_search(
                            _planner_options, gathered,
                            passengers=_trip_state.passengers or 0,
                            preferred_mode=_trip_state.transport_mode,
                        )
                        if _merged_options:
                            rendered = trip_selection.render_options(_merged_options)
                            if rendered:
                                logger.info(
                                    "interactive TRIP OPTIONS refreshed for %s — merged "
                                    "a partial re-search onto the already-active options "
                                    "(%d transport, %d hotel, %d transfer)",
                                    _trip_state.destination, len(_merged_options["transport"]),
                                    len(_merged_options["hotels"]), len(_merged_options["transfers"]),
                                )
                                _new_planner_options = _merged_options
                if rendered:
                    final_text = rendered
                    break

            # Half a trip-planner search (transport but no hotel, or the
            # reverse) has nothing to combine, so it would fall back to
            # listing parts — the very behaviour packages exist to replace.
            # Name the gap and let the model close it in the next step rather
            # than answering with a parts list.
            still_needed: list[str] = []
            if not booking_calls and not car_calls and not pick_hint:
                still_needed = trip_package.missing_for_package(
                    gathered, _trip_state.destination,
                )
                if still_needed:
                    logger.info(
                        "trip planner turn incomplete — still needs %s",
                        ", ".join(still_needed),
                    )
                # Run the missing search ourselves when every input for it is
                # already known. Asking the model costs a step it often spends
                # on the wrong search, and _MAX_TOOL_STEPS leaves no room for
                # that — see _package_fill_call.
                fill = _package_fill_call(still_needed, _trip_state, turn_transport_args)
                if fill:
                    fill_name, fill_args = fill
                    try:
                        fill_result = await asyncio.wait_for(
                            self_improvement.dispatch_tool_with_retry(
                                user_id=user_id, conversation_id=conversation_id,
                                user_message=user_message, name=fill_name,
                                args=fill_args, has_user_date=user_dates_known,
                            ),
                            timeout=_time_left(started),
                        )
                    except Exception:
                        logger.warning(
                            "package fill (%s) failed — falling back to asking the model",
                            fill_name, exc_info=True,
                        )
                        fill_result = None
                    if isinstance(fill_result, str) and fill_result:
                        logger.info("package fill ran %s(%s) in code", fill_name, fill_args)
                        tools_used.append(fill_name)
                        _absorb_learned(learned, fill_args)
                        gathered.append((fill_name, fill_result))
                        # Same shape a real tool round leaves behind, so history
                        # replay and the provider request stay well-formed.
                        fill_call = {
                            "id": f"fill-{uuid.uuid4().hex[:8]}", "type": "function",
                            "function": {"name": fill_name, "arguments": json.dumps(fill_args)},
                        }
                        messages.append(
                            {"role": "assistant", "content": None, "tool_calls": [fill_call]})
                        messages.append(
                            {"role": "tool", "tool_call_id": fill_call["id"], "content": fill_result})
                        still_needed = trip_package.missing_for_package(
                            gathered, _trip_state.destination,
                        )
                        rendered = ""
                        if _wants_recommendations(conversation_user_texts):
                            if trip_package.can_build(gathered, _trip_state.destination):
                                packages = trip_package.build(
                                    gathered, _trip_state.destination)
                                rendered = trip_package.render(
                                    packages, _trip_state.destination,
                                    budget_pkr=_trip_state.budget_pkr,
                                )
                        elif trip_selection.can_offer(
                            gathered, _trip_state.destination,
                            preferred_mode=_trip_state.transport_mode,
                        ):
                            _fill_options = trip_selection.build_options(
                                gathered, _trip_state.destination,
                                passengers=_trip_state.passengers or 0,
                                preferred_mode=_trip_state.transport_mode,
                            )
                            rendered = trip_selection.render_options(_fill_options)
                            if rendered:
                                _new_planner_options = _fill_options
                        else:
                            # Same partial-refresh merge as the main render
                            # site above — harmless no-op when no options
                            # are already active for this destination yet.
                            _merged_options = trip_selection.merge_fresh_search(
                                _planner_options, gathered,
                                passengers=_trip_state.passengers or 0,
                                preferred_mode=_trip_state.transport_mode,
                            )
                            if _merged_options:
                                rendered = trip_selection.render_options(_merged_options)
                                if rendered:
                                    _new_planner_options = _merged_options
                        if rendered:
                            logger.info(
                                "TRIP options/packages for %s rendered after completing "
                                "the missing search in code", _trip_state.destination,
                            )
                            final_text = rendered
                            break
                if still_needed:
                    messages.append({"role": "system", "content": (
                        "TRIP PACKAGE INCOMPLETE: this is package planning, not a "
                        f"single-service search. Still missing: {', '.join(still_needed)}. "
                        "Run that search NOW, in your next reply. Do NOT list what you "
                        "already found and do NOT ask them to pick a flight or a hotel "
                        "— the complete packages are built and shown for you once every "
                        "piece has been searched."
                    )})

            other_components = _outstanding_other_components(conversation_user_texts, gathered)
            # `still_needed` guards the same thing one level up: a trip-planner
            # turn missing a piece must not be answered with a tidy list of the
            # piece it does have.
            if not still_needed and not other_components and not booking_calls and not car_calls and deterministic_reply.should_render(
                gathered, user_message,
                has_budget_note=bool(budget_note), has_pick_hint=bool(pick_hint),
                round_trip_incomplete=one_leg and _wants_round_trip(conversation_user_texts),
            ):
                rendered = deterministic_reply.render(gathered, user_message)
                if rendered:
                    logger.info(
                        "deterministic reply for %s — skipped synthesis call",
                        ",".join(name for name, _ in gathered),
                    )
                    final_text = rendered
                    break

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

        if not final_text and not booking_data and not car_booking_data:
            try:
                msg = await asyncio.wait_for(
                    generate_with_tools(messages, tools=None, temperature=0.5, max_output_tokens=1200),
                    timeout=_time_left(started),
                )
                final_text = (getattr(msg, "content", "") or "").strip()
            except Exception as exc:
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
            elif isinstance(exc, LLMError):
                # A typed provider failure with nothing gathered. Re-running the
                # legacy pipeline would hit the same wall and double-spend the
                # budget, so answer with the truth for THIS cause — a per-minute
                # blip, a spent daily budget, an oversized conversation, or a
                # configuration problem all need different advice from the user.
                final_text = _provider_failure_message(exc) or _PROVIDER_DOWN_MESSAGE
            elif _is_turn_timeout(exc):
                # Our own budget is spent, not just Groq's per-minute wall — the
                # legacy pipeline would only get a few seconds against the router's
                # absolute 60s cutoff before losing everything the same way again.
                final_text = _TIMEOUT_MESSAGE
            elif _is_trip_planner_turn(user_message, history, _trip_state, turn_tool_names):
                # A trip-planner turn NEVER degrades into the legacy pipeline:
                # itinerary_agent isn't bound by this file's gates and will
                # quote a bus fare or a taxi price that came from nowhere.
                # Nothing was booked and nothing was charged at this point —
                # the failure happened before any component was verified — so
                # say exactly that instead of improvising a trip.
                logger.error(
                    "trip planner turn failed (%s) — refusing the legacy fallback",
                    exc, exc_info=True,
                )
                final_text = _TRIP_PLANNER_FAILED_MESSAGE
            else:
                # Nothing gathered → safe to try the legacy pipeline as a last resort.
                return await process_message(user_id, conversation_id, user_message)

    # Incomplete package → NO action, NO booking_data. The turn ends with an
    # explanation instead of a payment button, because a partially-verified
    # package is the one outcome that must never reach a card. This is checked
    # BEFORE the commit paths below so a single verified leg can't slip through
    # as an ordinary payment_choice.
    if package_incomplete and not package_components:
        summary = _package_incomplete_message(
            package_ok, package_failed, expected_components, trip_planner_missing_labels,
        )
        summary += _car_booking_note(car_booking_data)
        await save_turn(
            conversation_id, user_id, user_message, summary,
            model_used=answering_model(),
        )
        asyncio.ensure_future(_log_task(
            user_id, conversation_id, "booking", user_message,
            {"package_incomplete": True, "expected": expected_components,
             "verified": len(package_ok)},
        ))
        return {"response": summary, "conversation_id": conversation_id}

    if len(package_components) >= 2:
        package_data = build_package_data(package_components)
        summary = format_package_summary(package_data)
        summary += _car_booking_note(car_booking_data)
        await save_turn(
            conversation_id, user_id, user_message, summary,
            model_used=answering_model(),
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
    if booking_data:
        safe_next = sanitize_next_step(booking_data.get("next_step"))
        if not safe_next:
            safe_next = _infer_package_next_step(
                booking_data, conversation_user_texts, history, learned
            )
        booking_data["next_step"] = safe_next
        summary = format_booking_summary(booking_data)
        summary += _car_booking_note(car_booking_data)
        await save_turn(
            conversation_id, user_id, user_message, summary,
            model_used=answering_model(),
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
            model_used=answering_model(),
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
    # booking (and no payment buttons) behind it. Scripted fallback text (a
    # provider outage, a spent quota) is never model output, so it's exempt from
    # this scan — see _SCRIPTED_FALLBACK_MESSAGES.
    if final_text not in _SCRIPTED_FALLBACK_MESSAGES and _is_fabricated_booking(final_text):
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

    await save_turn(
        conversation_id, user_id, user_message, final_text,
        model_used=answering_model(),
    )
    if _new_planner_options:
        await save_planner_state(conversation_id, user_id, _new_planner_options)

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
            "You can book a Sedan (PKR 3,000), SUV (PKR 6,000), or Van (PKR 9,000) "
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
