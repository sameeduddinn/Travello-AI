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
import uuid
from datetime import date as date_type, datetime, timedelta, timezone

from agents.memory_agent import (
    get_user_memory,
    get_user_profile,
    get_conversation_history,
    save_message,
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
)
from agents.recommendation_agent import get_recommendations
from agents.healthcare_agent import get_safety_briefing

from services.llm_service import generate_text, generate_with_tools, GeminiError, LLMError
from agents.agent_tools import (
    TOOL_SCHEMAS,
    execute_tool,
    get_missing_booking_fields,
    get_booking_count_error,
    get_booking_date_error,
    apply_traveler_totals,
    reprice_booking,
    missing_fields_result,
    offer_not_found_result,
    get_car_booking_error,
    build_car_booking_data,
)
from prompts.master_agent import MASTER_SYSTEM, MASTER_AGENTIC_SYSTEM
from prompts.knowledge import get_relevant_facts, EMERGENCY_NUMBERS
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
            await asyncio.gather(
                save_message(conversation_id, user_id, "user", user_message, message_type="text"),
                save_message(conversation_id, user_id, "assistant", summary,
                             model_used=settings.GROQ_MODEL, message_type="text"),
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
    today          = date_type.today()
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

    # Step 8 — persist both messages
    await asyncio.gather(
        save_message(conversation_id, user_id, "user", user_message, message_type="text"),
        save_message(
            conversation_id, user_id, "assistant", final_response,
            model_used=settings.GROQ_MODEL, message_type="text",
        ),
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

# Shown when the LLM provider is momentarily rate-limited (free-tier TPM 429).
# Deliberately transient and reassuring — this is a per-minute wall, not a failure.
_RATE_LIMIT_MESSAGE = (
    "I'm getting a burst of requests right now and hit a brief rate limit. "
    "Please try again in a minute — nothing was lost, your trip details are safe."
)


def _is_rate_limit_error(exc: Exception) -> bool:
    """True for the Groq/Gemini quota (429) signal raised by llm_service."""
    return isinstance(exc, LLMError) and "quota_exhausted" in str(exc)


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


async def process_message_agentic(
    user_id: str,
    conversation_id: str,
    user_message: str,
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
    memory_context = _format_memory(memory, profile)
    today = date_type.today()

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
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    booking_data: dict | None = None
    car_booking_data: dict | None = None
    final_text: str = ""
    tools_used: list[str] = []
    learned: dict = {}
    gathered: list[tuple[str, str]] = []  # (tool_name, result_json) — real data we collected

    try:
        for _ in range(_MAX_TOOL_STEPS):
            msg = await generate_with_tools(
                messages, tools=TOOL_SCHEMAS, temperature=0.4, max_output_tokens=1200,
            )
            tool_calls = getattr(msg, "tool_calls", None)

            if not tool_calls:
                final_text = (msg.content or "").strip()
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
                missing = get_missing_booking_fields(bd)
                if missing:
                    booking_gate_results[tc.id] = missing_fields_result(missing)
                    continue
                count_error = get_booking_count_error(bd)
                if count_error:
                    booking_gate_results[tc.id] = count_error
                    continue
                date_error = get_booking_date_error(bd)
                if date_error:
                    booking_gate_results[tc.id] = date_error
                    continue
                bd = apply_traveler_totals(bd)
                verified = await reprice_booking(bd)
                if verified:
                    booking_data = verified
                    break
                booking_gate_results[tc.id] = offer_not_found_result()

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
            other_calls = [
                (tc, args) for tc, args in zip(tool_calls, call_args)
                if tc.function.name not in ("prepare_booking", "book_car")
            ]
            results = await asyncio.gather(
                *[execute_tool(tc.function.name, args) for tc, args in other_calls],
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
                msg = await generate_with_tools(messages, tools=None, temperature=0.5, max_output_tokens=1200)
                final_text = (getattr(msg, "content", "") or "").strip()
            except Exception as exc:
                # Out of tool-call budget — synthesize from the data we ALREADY have,
                # via generate_text (Groq->Gemini failover). Never re-run the pipeline
                # from scratch (that double-spends quota and risks hallucinating).
                logger.warning("final tool-synthesis failed (%s) — synthesizing from gathered data", exc)
                final_text = await _synthesize_from_tools(system_prompt, history, user_message, gathered)

    except Exception as exc:
        # The loop broke (e.g. quota). If we already gathered real tool data, answer
        # from it — do NOT re-run the pipeline (it hallucinated under quota stress).
        logger.warning("agentic loop failed (%s)", exc)
        if gathered:
            final_text = await _synthesize_from_tools(system_prompt, history, user_message, gathered)
        if not final_text:
            if _is_rate_limit_error(exc):
                # Per-minute rate limit with nothing gathered: re-running the legacy
                # pipeline just hits the same 429 and double-spends the budget. Fail
                # fast with an honest, transient message instead of hanging to 504.
                final_text = _RATE_LIMIT_MESSAGE
            else:
                # Nothing gathered → safe to try the legacy pipeline as a last resort.
                return await process_message(user_id, conversation_id, user_message)

    # Booking path → payment_choice (same contract the Flutter app already handles)
    if booking_data:
        summary = format_booking_summary(booking_data)
        await asyncio.gather(
            save_message(conversation_id, user_id, "user", user_message, message_type="text"),
            save_message(conversation_id, user_id, "assistant", summary,
                         model_used=settings.GROQ_MODEL, message_type="text"),
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
        await asyncio.gather(
            save_message(conversation_id, user_id, "user", user_message, message_type="text"),
            save_message(conversation_id, user_id, "assistant", summary,
                         model_used=settings.GROQ_MODEL, message_type="text"),
        )
        asyncio.ensure_future(_log_task(user_id, conversation_id, "booking", user_message, car_booking_data))
        return {
            "response": summary,
            "conversation_id": conversation_id,
            "action": "car_booking_choice",
            "booking_data": car_booking_data,
        }

    if not final_text:
        final_text = "I'm having trouble responding right now. Could you rephrase that?"

    # Persist both messages
    await asyncio.gather(
        save_message(conversation_id, user_id, "user", user_message, message_type="text"),
        save_message(conversation_id, user_id, "assistant", final_text,
                     model_used=settings.GROQ_MODEL, message_type="text"),
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
