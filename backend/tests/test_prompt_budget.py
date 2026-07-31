"""
Request-size control: dynamic tool selection, prompt assembly, compact history,
deterministic trip state, and the overall token budget.

The budget assertions are the point of this file. Groq's free tier allows 100,000
tokens per DAY; at the old ~8.9k fixed cost per call the agent got roughly eleven
calls before every later request was refused outright. These tests fail if that
cost creeps back.
"""
import json

import pytest

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


def test_unrecognised_message_falls_back_to_everything_servable():
    """
    The fallback is the UNKNOWN-request case, so it has to hold whatever the
    agent might need to serve a request the regexes failed to recognise.

    It used to be the four search tools only. "gari chahiye airport se" landed
    here — the agent was asked for a car and handed no way to arrange one.
    find_healthcare had the same hole, and that is the one tool where failing
    to serve a request can actually matter.

    prepare_booking stays out: 793 tokens, the most expensive schema by far,
    meaningless before a search has produced something to book, and selected
    explicitly on a pick.
    """
    names = set(select_tool_names("hmm"))
    assert names == {
        "search_flights", "search_trains", "search_hotels",
        "get_weather", "find_healthcare", "book_car",
    }
    assert "prepare_booking" not in names


def test_an_unrecognised_car_request_can_still_be_served():
    """Roman Urdu the regexes don't cover must not leave the agent tool-less."""
    for message in ("gari chahiye airport se", "mujhe koi gaari chahiye"):
        assert "book_car" in select_tool_names(message), message


@pytest.mark.parametrize("message", [
    "Hi", "hello", "Hey!", "hi.", "Salam", "assalam o alaikum",
    "Assalamualaikum", "good morning", "thanks", "thank you", "ok", "okay",
    "who are you?", "what can you do?", "how are you",
])
def test_pure_greetings_get_no_tools_at_all(message):
    """
    "Hi" is not a request for anything, so there is no trip in progress for the
    agent to be tool-less FOR. Costs the full 6-tool fallback (3,340 tokens)
    before this: now 2,021, a 39% cut on the cheapest possible turn.
    """
    assert select_tool_names(message, []) == []


@pytest.mark.parametrize("message", [
    "hi, book me a flight to lahore",   # greeting word, but not ALL it says
    "mujhe Lahore jana hai",            # real travel intent, no greeting match
    "gari chahiye airport se",          # real request, must reach book_car
    "sab se sasti ticket chahiye",
    "ok book PA401",                    # "ok" alone would match; this doesn't
])
def test_a_real_request_is_never_mistaken_for_a_greeting(message):
    """
    The asymmetry that keeps this list narrow: missing a greeting costs
    nothing (falls through to the ordinary fallback), but wrongly matching a
    real request costs a whole extra turn — no tools, the agent has to ask,
    the user answers, only then does a real search happen.
    """
    assert select_tool_names(message, []) != []


def test_a_greeting_mid_conversation_keeps_the_running_tool():
    """
    "thanks" after a real turn is not the same turn as "thanks" cold — the
    conversation is already about something, and the greeting short-circuit is
    gated on empty history specifically so it can never strand a live request.
    """
    history = [
        {"role": "user", "content": "find me a train from Lahore to Karachi"},
        {"role": "assistant", "content": "Here are the trains..."},
    ]
    assert "search_trains" in select_tool_names("thanks", history)


def test_an_empty_tool_list_means_no_tools_not_every_tool():
    """
    `tool_names or [...all...]` treated an empty list as "send everything",
    because an empty list is falsy — so a no-tool prompt measured LARGER than
    a four-tool one.
    """
    from agents.prompt_builder import build_system_prompt

    empty = build_system_prompt(today="2026-07-31", weekday="Friday",
                                memory="", tool_names=[])
    everything = build_system_prompt(today="2026-07-31", weekday="Friday",
                                     memory="", tool_names=None)
    assert len(empty) < len(everything)


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


# ── prepare_booking must key off REAL offers, not any numbered list ──────────
#
# Live scenario that surfaced this: the assistant asked its own clarifying
# questions as a numbered list -
#
#   1. Outbound date (Karachi -> Lahore)
#   2. Return date (Lahore -> Karachi)
#   3. How many adults will be traveling?
#   4. Any budget ceiling for the round-trip (in PKR)?
#
# - and the user's numbered reply to it -
#
#   1. 20 August
#   2. 25 August
#   3. Economy
#   4. PKR 90,000
#
# - shipped prepare_booking (793 tokens, the most expensive schema) even
# though nothing had been offered yet; the user was answering questions, not
# picking from a list.
#
# _PICK_RE was the original suspect and is NOT the cause - it requires either
# the whole message to be a bare number, or literal words like "option"/
# "flight"/"train"/"hotel", none of which this message contains. The real
# cause is _OFFER_LIST_RE matching ANY numbered line, including the
# assistant's own numbered QUESTIONS, with no requirement that a real price be
# present - so _recent_assistant_offers reported "offers on the table" for a
# list that offered nothing.

CLARIFYING_QUESTIONS = {"role": "assistant", "content": (
    "Sure thing, bhai! To pull up the best flights for you, could you let me know:\n"
    "1. Outbound date (Karachi \u2192 Lahore)\n"
    "2. Return date (Lahore \u2192 Karachi)\n"
    "3. How many adults will be traveling?\n"
    "4. Any budget ceiling for the round-trip (in PKR)?"
)}
CLARIFYING_REPLY = "1. 20 August\n2. 25 August\n3. Economy\n4. PKR 90,000"

REAL_TRAIN_LIST = {"role": "assistant", "content": (
    "1. **Islamabad Express (9-Up/10-Dn)** \u00b7 06:00 \u2192 07:25\n"
    "   \u00b7 Economy \u2014 PKR 786 per person \u00d7 2 = PKR 1,572 total\n"
    "   \u00b7 AC Standard \u2014 PKR 2,655 per person \u00d7 2 = PKR 5,310 total\n"
    "2. **Shah Hussein Express (51-Up/52-Dn)** \u00b7 08:30 \u2192 11:10\n"
    "   \u00b7 Economy \u2014 PKR 906 per person \u00d7 2 = PKR 1,812 total\n"
    "3. **Tezgam Express (7-Up/8-Dn)** \u00b7 09:30 \u2192 12:15\n"
    "   \u00b7 AC Business \u2014 PKR 4,871 per person \u00d7 2 = PKR 9,742 total"
)}
REAL_HOTEL_LIST = {"role": "assistant", "content": (
    "1. **Park Lane Hotel** 4\u2605 \u2014 PKR 24,529/night \u00d7 2 nights = PKR 49,058\n"
    "2. **Hotel One Down Town, Lahore** 3\u2605 \u2014 PKR 20,432/night \u00d7 2 nights = PKR 40,864\n"
)}
REAL_PACKAGE_LIST = {"role": "assistant", "content": (
    "Here's a Skardu package:\n"
    "1. \u2708\ufe0f **Flight:** Lahore \u2192 Skardu, 2026-08-20 \u2014 PKR 21,210\n"
    "2. \U0001f3e8 **Hotel:** Shangrila Resort, 3 nights \u2014 PKR 45,000\n"
)}
REAL_ROUND_TRIP_LIST = {"role": "assistant", "content": (
    "**Outbound**\n"
    "1. **AirSial ER937** \u00b7 06:00 \u2192 07:25 \u2014 PKR 10,605 per person \u00d7 2 = PKR 21,210 total\n"
    "2. **Airblue PA489** \u00b7 06:00 \u2192 07:25 \u2014 PKR 10,932 per person \u00d7 2 = PKR 21,864 total\n\n"
    "**Return**\n"
    "1. **Airblue PA140** \u00b7 06:00 \u2192 07:25 \u2014 PKR 12,236 per person \u00d7 2 = PKR 24,472 total\n"
    "2. **PIA PK659** \u00b7 06:00 \u2192 07:25 \u2014 PKR 14,526 per person \u00d7 2 = PKR 29,052 total\n"
)}


def test_pick_re_itself_does_not_match_a_numbered_clarification_reply():
    """The originally-suspected cause, ruled out directly."""
    from agents.prompt_builder import _PICK_RE
    assert not _PICK_RE.search(CLARIFYING_REPLY)


def test_a_numbered_list_of_questions_is_not_an_offer_list():
    """The actual cause: _OFFER_LIST_RE alone can't tell a question from an offer."""
    from agents.prompt_builder import _looks_like_offer_list
    assert not _looks_like_offer_list(CLARIFYING_QUESTIONS["content"])


def test_numbered_clarification_replies_do_not_ship_prepare_booking():
    """The exact reported turn: answering dates/class/budget is not a pick."""
    names = select_tool_names(CLARIFYING_REPLY, [
        {"role": "user", "content": "I want to book round-trip flight from Karachi to Lahore"},
        CLARIFYING_QUESTIONS,
    ])
    assert "prepare_booking" not in names


def test_a_currency_mention_with_no_digit_is_not_mistaken_for_a_price():
    """
    The clarifying list's own line 4 says '...(in PKR)?' - PKR with no trailing
    digit. This must not itself count as a price and flip the result back to a
    false positive.
    """
    from agents.prompt_builder import _PRICE_IN_LABEL_RE, _looks_like_offer_list
    assert not _PRICE_IN_LABEL_RE.search("Any budget ceiling for the round-trip (in PKR)?")
    assert not _looks_like_offer_list(CLARIFYING_QUESTIONS["content"])


def test_selecting_flight_option_1_still_ships_prepare_booking():
    assert "prepare_booking" in select_tool_names("1", [OFFER_LIST])


def test_selecting_hotel_option_2_still_ships_prepare_booking():
    assert "prepare_booking" in select_tool_names("2", [REAL_HOTEL_LIST])


def test_selecting_train_option_3_still_ships_prepare_booking():
    """
    The non-regression case that mattered most: the train's price sits on an
    INDENTED SUB-LINE below the numbered train name, not on the numbered line
    itself. A same-line price requirement would have broken this.
    """
    assert "prepare_booking" in select_tool_names("3", [REAL_TRAIN_LIST])


def test_package_booking_selections_still_ship_prepare_booking():
    assert "prepare_booking" in select_tool_names("1 and 2", [REAL_PACKAGE_LIST])


def test_round_trip_selections_still_ship_prepare_booking():
    names = select_tool_names("1 for outbound and 2 for return", [REAL_ROUND_TRIP_LIST])
    assert "prepare_booking" in names


def test_mixed_conversation_clarify_then_real_offers_then_pick():
    """
    The full shape: a clarifying-question turn must NOT ship prepare_booking,
    but once the agent comes back with REAL priced offers, a pick against
    THOSE must still work exactly as before. Proves the fix doesn't
    overcorrect into suppressing genuine picks.
    """
    base_history = [
        {"role": "user", "content": "book train from Karachi to Lahore"},
        CLARIFYING_QUESTIONS,
    ]
    clarify_answer_names = select_tool_names(CLARIFYING_REPLY, base_history)
    assert "prepare_booking" not in clarify_answer_names

    history_with_real_offers = base_history + [
        {"role": "user", "content": CLARIFYING_REPLY},
        REAL_TRAIN_LIST,
    ]
    pick_names = select_tool_names("2", history_with_real_offers)
    assert "prepare_booking" in pick_names


@pytest.mark.parametrize("offers", [
    OFFER_LIST, REAL_TRAIN_LIST, REAL_HOTEL_LIST, REAL_PACKAGE_LIST, REAL_ROUND_TRIP_LIST,
])
def test_every_real_offer_shape_is_still_recognised(offers):
    """Existing behaviour, unchanged: each real offer format still enables a pick."""
    from agents.prompt_builder import _looks_like_offer_list
    assert _looks_like_offer_list(offers["content"])


# ── Adversarial review of _looks_like_offer_list ─────────────────────────────
#
# Follow-up review of the fix above. Found genuine regressions (realistic
# offer messages that USED TO be detected and no longer were) and pre-existing
# false positives (numbered lists that were NEVER offers but matched anyway,
# unaffected by the fix either way). Only the former were changed - "do not
# change the implementation unless you find a genuine regression" is the bar,
# and a pre-existing false positive that the fix didn't create is not one.

def _was_true_before_the_price_gate(text: str) -> bool:
    """What _looks_like_offer_list returned before this session's fix - numbered
    shape alone, no price requirement at all. Used only to tell a REGRESSION
    (was True, now False) apart from a PRE-EXISTING gap (was already True)."""
    from agents.prompt_builder import _OFFER_LIST_RE
    return bool(_OFFER_LIST_RE.search(text or ""))


@pytest.mark.parametrize("text", [
    "1. AirSial ER937 - Rs. 21,210\n2. Airblue PA489 - Rs. 21,864",
    "1. AirSial ER937 - \u20a821,210\n2. Airblue PA489 - \u20a821,864",
])
def test_currency_notation_regressions_are_fixed(text):
    """
    Genuine regressions this review found: the original fix required the
    LITERAL string "PKR", which the deterministic renderer always uses but a
    free-form LLM reply (exactly the budget/planning turns this gate exists
    for) may write as "Rs." or the Rupee sign instead. Both used to be
    detected (numbered shape was the only requirement) and briefly stopped
    being detected once the price gate was added.
    """
    from agents.prompt_builder import _looks_like_offer_list
    assert _was_true_before_the_price_gate(text)      # confirms it's a regression, not new
    assert _looks_like_offer_list(text)


@pytest.mark.parametrize("marker,text", [
    ("hrs", "The flight takes 8 hrs 30 mins to Karachi."),
    ("Mrs.", "Booked for Mrs. Khan and 1 child."),
    ("yrs", "Our guide has 2 yrs of experience."),
    ("flight code", "Flight ERS204 departs at 6am."),
])
def test_the_rs_marker_does_not_collide_with_ordinary_text(marker, text):
    """"Rs" is two letters - narrow enough to risk false hits inside ordinary
    words. Checked explicitly against the shapes most likely to collide."""
    from agents.prompt_builder import _looks_like_offer_list
    assert not _looks_like_offer_list(text), marker


@pytest.mark.parametrize("text", [
    "All prices below are in PKR.\n1. AirSial ER937 - 21,210\n2. Airblue PA489 - 21,864",
    "1. ER937 - 21210\n2. PA489 - 21864",
])
def test_two_currency_gaps_are_a_documented_accepted_risk_not_a_silent_regression(text):
    """
    NOT fixed, on purpose - both of these ALSO returned True before the price
    gate existed, so leaving them is not a regression by the same standard the
    fix above is held to. A bare "does this contain a 4+ digit number"
    fallback was tested as a possible fix and rejected: it flags a clarifying
    question list as an offer the moment a date in it has a 4-digit year
    ("25 August 2026"), reopening the exact bug this file exists to fix (see
    test_a_plausible_date_year_does_not_reopen_the_original_bug below). This
    test exists so a future change to close this gap has to consciously
    re-examine that trade-off rather than silently pass.
    """
    from agents.prompt_builder import _looks_like_offer_list
    assert _was_true_before_the_price_gate(text)
    assert not _looks_like_offer_list(text)


def test_a_plausible_date_year_does_not_reopen_the_original_bug():
    """
    The clarifying-question list, with a realistic 4-digit year in each date
    example - exactly the shape a bare "N+ digit number" fallback would have
    misread as a price. Confirms the actual implementation (currency-marker
    gated, not digit-count gated) does not regress here.
    """
    from agents.prompt_builder import _looks_like_offer_list
    text = (
        "1. Outbound date (Karachi \u2192 Lahore), e.g. 20 August 2026\n"
        "2. Return date (Lahore \u2192 Karachi), e.g. 25 August 2026\n"
        "3. How many adults will be traveling?\n"
        "4. Any budget ceiling for the round-trip (in PKR)?"
    )
    assert not _looks_like_offer_list(text)


@pytest.mark.parametrize("text", [
    "1. Is a budget of PKR 50,000 enough?\n2. How many travelers?",
    "1. A flight is around PKR 15,000-30,000\n2. A hotel is around PKR 8,000/night",
    "1. Flooding near Skardu\n2. Fuel prices risen to PKR 280/litre",
    "Total: PKR 45,783\n\n1. Add Passenger Details\n2. Choose how to pay",
])
def test_pre_existing_false_positives_are_unaffected_either_way(text):
    """
    A numbered list that mentions real money without being a list of bookable
    search results (a clarifying question with a suggested figure, a cost FAQ,
    a travel advisory, a next-steps checklist next to an unrelated total) was
    ALREADY misclassified before the price gate, and still is - the gate
    narrows "any numbered list" down to "any numbered list with a price it it
    somewhere", not down to "a numbered list of this app's own search results".
    Distinguishing those needs understanding context, not just digits, and is
    out of scope for this fix. Documented here so it's a known, named gap
    rather than a silent one.
    """
    from agents.prompt_builder import _looks_like_offer_list
    assert _was_true_before_the_price_gate(text)
    assert _looks_like_offer_list(text)   # unchanged - not what this fix targets


@pytest.mark.parametrize("text", [
    "1. **AirSial ER937** \u2014 PKR 10,605 per person \u00d7 2 = PKR 21,210 total\n"
    "2. **Airblue PA489** \u2014 PKR 10,932 per person \u00d7 2 = PKR 21,864 total",
    "1. **Islamabad Express** \u00b7 06:00 \u2192 07:25\n"
    "   \u00b7 Economy \u2014 PKR 786 per person \u00d7 2 = PKR 1,572 total",
    "1. **Park Lane Hotel** 4\u2605 \u2014 PKR 24,529/night \u00d7 2 nights = PKR 49,058",
    "Nothing was under your PKR 15,000 budget; the cheapest option is:\n"
    "1. AirSial ER937 \u2014 PKR 21,210",
    "**Outbound**\n1. **AirSial ER937** \u2014 PKR 21,210 total\n\n"
    "**Return**\n1. **PIA PK659** \u2014 PKR 29,052 total",
])
def test_real_offer_shapes_remain_correctly_detected(text):
    """The actual renderer output formats - unaffected by any of this review's changes."""
    from agents.prompt_builder import _looks_like_offer_list
    assert _looks_like_offer_list(text)


def test_a_deterministic_healthcare_list_was_never_and_is_still_not_an_offer():
    """
    Healthcare has no booking flow (no "book a hospital visit"), so a numbered
    hospital list was never meant to count as offers-on-the-table either way.
    """
    from agents.prompt_builder import _looks_like_offer_list
    text = "1. Services Hospital - Jail Road - 2.1km - +92-42-99203402\n2. Mayo Hospital - 3.4km"
    assert not _looks_like_offer_list(text)
