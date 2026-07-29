"""
Request-size control: dynamic tool selection, prompt assembly, compact history,
deterministic trip state, and the overall token budget.

The budget assertions are the point of this file. Groq's free tier allows 100,000
tokens per DAY; at the old ~8.9k fixed cost per call the agent got roughly eleven
calls before every later request was refused outright. These tests fail if that
cost creeps back.
"""
import json

from agents.agent_tools import TOOL_SCHEMAS
from agents.conversation_state import derive_state, state_hint
from agents.master_agent import _compact_history
from agents.prompt_builder import (
    build_system_prompt,
    estimate_fixed_tokens,
    select_tool_names,
    select_tools,
)
from prompts.master_agent import MASTER_AGENTIC_SYSTEM
from services.llm_service import estimate_request_tokens

MEMORY = "User's name: Sameed | Travel preferences: home city=Lahore"

OFFER_LIST = {"role": "assistant", "content": (
    "Here are your options:\n"
    "1. Airblue PA401 · 08:00 → 09:55 — PKR 17,500\n"
    "2. PIA PK304 · 11:20 → 13:15 — PKR 19,100\n"
    "3. AirSial ER198 · 15:45 → 17:40 — PKR 16,300\n"
)}


def _fixed(message, history=None):
    names = select_tool_names(message, history)
    tools = select_tools(message, history)
    prompt = build_system_prompt(
        today="2026-07-29", weekday="Wednesday", memory=MEMORY, tool_names=names)
    return estimate_fixed_tokens(prompt, tools), names


# ── The headline budget ───────────────────────────────────────────────────────

def test_old_fixed_payload_was_the_problem():
    """Documents the baseline these tests exist to hold down."""
    old_system = MASTER_AGENTIC_SYSTEM.format(
        weekday="Wednesday", today="2026-07-29", memory=MEMORY)
    old = estimate_fixed_tokens(old_system, TOOL_SCHEMAS)
    assert old > 8000


def test_every_turn_shape_fits_the_5k_first_call_target():
    cases = [
        ("hi, who are you?", None),
        ("what's the weather in Skardu?", None),
        ("nearest hospital in Lahore please", None),
        ("I want to fly from Lahore to Karachi on 20 August for 2 people", None),
        ("book me a roundtrip Lahore to Karachi 15 aug to 25 aug for 2", None),
        ("1 for outbound and 3 for return", [OFFER_LIST, OFFER_LIST]),
        ("2", [OFFER_LIST]),
        ("find me a hotel in Islamabad for 3 nights", None),
        ("book me a sedan from DHA phase 5 to the airport tomorrow 9am", None),
        ("plan me a 4 day trip to Hunza with a budget of 150000", None),
    ]
    for message, history in cases:
        tokens, names = _fixed(message, history)
        assert tokens < 5000, f"{message!r} -> {tokens} tokens with {names}"


def test_worst_case_fixed_payload_is_at_least_40_percent_smaller():
    old_system = MASTER_AGENTIC_SYSTEM.format(
        weekday="Wednesday", today="2026-07-29", memory=MEMORY)
    old = estimate_fixed_tokens(old_system, TOOL_SCHEMAS)
    all_names = [t["function"]["name"] for t in TOOL_SCHEMAS]
    new = estimate_fixed_tokens(
        build_system_prompt(today="2026-07-29", weekday="Wednesday",
                            memory=MEMORY, tool_names=all_names),
        TOOL_SCHEMAS,
    )
    assert new < old * 0.6, (old, new)


def test_full_request_with_long_history_stays_under_6k():
    """The absolute ceiling, history included."""
    history = []
    for i in range(20):
        history.append({"role": "user", "content": f"question number {i} about my trip"})
        history.append({"role": "assistant", "content": "x" * 1800})   # a big options table
    message = "1 for outbound and 3 for return"
    names = select_tool_names(message, history)
    tools = select_tools(message, history)
    prompt = build_system_prompt(
        today="2026-07-29", weekday="Wednesday", memory=MEMORY, tool_names=names)
    messages = [{"role": "system", "content": prompt}]
    messages += _compact_history(history)
    messages.append({"role": "user", "content": message})
    hint = state_hint(history, message)
    if hint:
        messages.append({"role": "system", "content": hint})
    total = estimate_request_tokens(messages, tools)
    assert total < 6000, total


# ── Dynamic tool selection ────────────────────────────────────────────────────

def test_weather_question_sends_only_the_weather_tool():
    assert select_tool_names("what's the weather in Skardu?") == ["get_weather"]


def test_healthcare_question_sends_only_healthcare():
    assert select_tool_names("nearest hospital in Lahore") == ["find_healthcare"]


def test_flight_search_does_not_pay_for_the_booking_schema():
    names = select_tool_names("I want to fly Lahore to Karachi on 20 August for 2")
    assert names == ["search_flights"]
    assert "prepare_booking" not in names


def test_hotel_search_is_not_expanded_into_a_whole_trip_plan():
    """"3 nights" is a hotel detail, not a trip-planning signal."""
    assert select_tool_names("find me a hotel in Islamabad for 3 nights") == ["search_hotels"]


def test_trip_planning_gets_the_full_search_set():
    names = select_tool_names("plan me a 4 day trip to Hunza")
    assert {"search_flights", "search_trains", "search_hotels", "get_weather"} <= set(names)


def test_a_pick_gets_prepare_booking():
    assert "prepare_booking" in select_tool_names("option 2", [OFFER_LIST])


def test_two_leg_pick_gets_prepare_booking():
    names = select_tool_names("1 for outbound and 3 for return", [OFFER_LIST, OFFER_LIST])
    assert "prepare_booking" in names


def test_naming_a_flight_code_gets_prepare_booking():
    assert "prepare_booking" in select_tool_names("book PA401 for me")


def test_a_date_range_is_not_mistaken_for_a_flight_code():
    """
    Matched case-insensitively, "to 25" in "15 aug to 25 aug" looks exactly like
    a flight code — which dragged the booking schema into every date range.
    """
    names = select_tool_names("book me a roundtrip Lahore to Karachi 15 aug to 25 aug for 2")
    assert "prepare_booking" not in names


def test_standalone_car_does_not_drag_in_flights_or_booking():
    names = select_tool_names("book me a sedan from DHA phase 5 to the airport tomorrow 9am")
    assert names == ["book_car"]


def test_car_inside_a_booking_conversation_stays_a_transfer():
    """An airport transfer is a FIELD on prepare_booking, not a second tool."""
    names = select_tool_names("yes add a car transfer", [OFFER_LIST])
    assert "prepare_booking" in names
    assert "book_car" not in names


def test_unrecognised_message_falls_back_to_the_search_set():
    names = select_tool_names("hmm")
    assert set(names) == {"search_flights", "search_trains", "search_hotels", "get_weather"}


def test_recent_context_is_carried_forward():
    """A follow-up must not lose the tool the previous turn was using."""
    history = [{"role": "user", "content": "find me a train from Lahore to Karachi"}]
    assert "search_trains" in select_tool_names("what about tomorrow instead?", history)


def test_tool_order_is_stable():
    """Byte-stable payloads keep provider-side prompt caching effective."""
    a = select_tool_names("plan a trip to Skardu")
    b = select_tool_names("plan a trip to Skardu")
    assert a == b == sorted(a, key=lambda n: [t["function"]["name"] for t in TOOL_SCHEMAS].index(n))


# ── Prompt assembly ───────────────────────────────────────────────────────────

def test_booking_block_only_ships_with_the_booking_tool():
    without = build_system_prompt(today="2026-07-29", weekday="Wednesday",
                                  memory=MEMORY, tool_names=["get_weather"])
    with_booking = build_system_prompt(today="2026-07-29", weekday="Wednesday",
                                       memory=MEMORY, tool_names=["prepare_booking"])
    assert "Booking & payment" not in without
    assert "Booking & payment" in with_booking


def test_car_block_only_ships_with_book_car():
    without = build_system_prompt(today="2026-07-29", weekday="Wednesday",
                                  memory=MEMORY, tool_names=["search_flights"])
    with_car = build_system_prompt(today="2026-07-29", weekday="Wednesday",
                                   memory=MEMORY, tool_names=["book_car"])
    assert "Standalone car booking" not in without
    assert "Standalone car booking" in with_car


def test_safety_rules_without_a_code_gate_survive_the_trim():
    """
    These have NO deterministic enforcement anywhere, so the prompt is the only
    thing holding them. Trimming one of these is a real regression, not a saving.
    """
    prompt = build_system_prompt(today="2026-07-29", weekday="Wednesday",
                                 memory=MEMORY, tool_names=["prepare_booking", "book_car"])
    required = [
        "within Pakistan only",       # international scope refusal
        "1122",                       # emergency numbers on an empty healthcare result
        "never invent a count",       # party size
        "CNIC",                       # no identity PII in chat
        "CARD-ONLY",                  # payment method
        "per person",                 # per-person x pax price display
        "NEVER translate a code",     # airline code -> carrier name
        "fraud",                      # refusal policy
        "live weather",               # weather honesty
    ]
    for phrase in required:
        assert phrase in prompt, phrase


def test_date_and_memory_placeholders_are_filled():
    prompt = build_system_prompt(today="2026-07-29", weekday="Wednesday",
                                 memory=MEMORY, tool_names=["get_weather"])
    assert "2026-07-29" in prompt and "Wednesday" in prompt and "Sameed" in prompt
    assert "{" not in prompt.split("## Tools")[0].replace("{memory}", "")


# ── Compact history ───────────────────────────────────────────────────────────

def test_compact_history_trims_old_assistant_tables_but_not_user_turns():
    history = [
        {"role": "user", "content": "u" * 2000},
        {"role": "assistant", "content": "a" * 2000},
        {"role": "user", "content": "recent question"},
        {"role": "assistant", "content": "recent answer"},
    ]
    out = _compact_history(history)
    assert len(out[0]["content"]) == 2000            # user turns untouched
    assert len(out[1]["content"]) < 600              # old assistant trimmed
    assert out[-1]["content"] == "recent answer"     # recent turns whole


def test_compact_history_enforces_a_total_ceiling_dropping_oldest_first():
    history = [{"role": "user", "content": f"message {i} " + "x" * 500} for i in range(40)]
    out = _compact_history(history)
    total = sum(len(m["content"]) for m in out)
    assert total <= 4600, total
    assert out[-1] == history[-1]                     # newest always survives


def test_compact_history_keeps_at_least_the_newest_turn():
    history = [{"role": "user", "content": "x" * 50000}]
    out = _compact_history(history)
    assert len(out) == 1


def test_compact_history_handles_empty():
    assert _compact_history([]) == []


# ── Deterministic conversation state ──────────────────────────────────────────

def test_state_extracts_route_date_pax_and_budget():
    history = [
        {"role": "user", "content": "I want to go from Lahore to Karachi"},
        {"role": "assistant", "content": "When would you like to travel?"},
        {"role": "user", "content": "on 2026-08-20 for 3 people, budget 150000"},
    ]
    state = derive_state(history)
    assert state.origin == "Lahore"
    assert state.destination == "Karachi"
    assert state.travel_date == "2026-08-20"
    assert state.passengers == 3
    assert state.budget_pkr == 150000


def test_state_reads_a_return_date_as_the_second_iso_date():
    state = derive_state([{"role": "user",
                           "content": "Lahore to Karachi 2026-08-15 to 2026-08-25"}])
    assert state.travel_date == "2026-08-15"
    assert state.return_date == "2026-08-25"


def test_state_takes_the_newest_correction():
    history = [
        {"role": "user", "content": "for 2 people"},
        {"role": "user", "content": "sorry, make it 4 people"},
    ]
    assert derive_state(history).passengers == 4


def test_state_records_what_was_already_prepared():
    history = [{"role": "assistant", "content":
                "**Booking Summary**\n\n✈️  **Flight:** Lahore → Karachi"}]
    assert "flight" in derive_state(history).prepared


def test_state_hint_is_small_and_empty_when_nothing_is_known():
    assert state_hint([], "hello there") == ""
    hint = state_hint([{"role": "user", "content":
                        "Lahore to Karachi on 2026-08-20 for 2 people"}], "")
    assert hint
    assert estimate_request_tokens([{"role": "system", "content": hint}]) < 120


def test_state_ignores_dates_that_have_already_passed():
    from datetime import date
    history = [{"role": "user", "content": "I flew on 2020-01-01; now book 2026-08-20"}]
    state = derive_state(history, today=date(2026, 7, 29))
    assert state.travel_date == "2026-08-20"


def test_state_never_invents_a_party_size():
    assert derive_state([{"role": "user", "content": "book a flight for my family"}]).passengers is None


def test_tool_schemas_are_valid_json_serialisable():
    """They go over the wire on every call; a non-serialisable one breaks everything."""
    assert json.loads(json.dumps(TOOL_SCHEMAS)) == TOOL_SCHEMAS


def test_required_search_fields_are_still_required():
    """
    Trimming schema prose must never quietly drop `passengers` — the fare is
    per-seat x passengers, so a silent default of 1 misprices the whole party.
    """
    by_name = {t["function"]["name"]: t["function"] for t in TOOL_SCHEMAS}
    assert "passengers" in by_name["search_flights"]["parameters"]["required"]
    assert "passengers" in by_name["search_trains"]["parameters"]["required"]
    assert "guests" not in by_name["search_hotels"]["parameters"]["required"]
    guests_desc = by_name["search_hotels"]["parameters"]["properties"]["guests"]["description"]
    assert "default" not in guests_desc.lower()
