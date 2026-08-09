"""
find_options() must not resolve a pick against an options block that no
longer belongs to the current trip.

The bug: a Swat trip is planned, its options are shown, the trip is booked —
then the user starts a NEW trip to Hunza. Before any Hunza options are ever
rendered, a pick-shaped reply ("Flight 1, Hotel 1, Transfer 1") walks find_options
straight past the intervening "book Hunza" conversation and resolves against
the OLD, already-paid-for Swat block, because nothing in the conversation
contradicted it on find_options' own (previously nonexistent) terms.

The fix reads the conversation directly: if any USER message AFTER a
candidate options block names a DIFFERENT one of the four known northern
destinations, the block is stale and find_options() returns {} — the same
"nothing to resolve" outcome as no options ever having been shown. This is
deliberately NOT keyed off TripState.destination, which is sticky by design
(see conversation_state.derive_state) and was proven, by direct execution, to
still report the OLD destination on the very turn this bug needs to catch.
"""
import json

import pytest

from agents import trip_selection as ts

FLIGHTS_SWAT = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [{"flight_number": "PK948", "airline": "PIA", "from": "Karachi",
                 "to": "Islamabad", "depart": "2026-08-14 07:00", "arrive": "09:03",
                 "cabin": "ECONOMY", "total_price_pkr": 69256}],
})
HOTELS_SWAT = json.dumps({
    "city": "Swat", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Hotel Pameer", "stars": 4, "price_per_night_pkr": 17482,
                "total_stay_pkr": 69928}],
})
FLIGHTS_HUNZA = json.dumps({
    "search_date": "2026-08-20", "passengers": 2,
    "flights": [{"flight_number": "PA900", "airline": "Airblue", "from": "Karachi",
                 "to": "Gilgit", "depart": "2026-08-20 07:00", "arrive": "09:05",
                 "cabin": "ECONOMY", "total_price_pkr": 45000}],
})
HOTELS_HUNZA = json.dumps({
    "city": "Hunza", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Old Hunza Inn", "stars": 4, "price_per_night_pkr": 13900,
                "total_stay_pkr": 55600}],
})


def _swat_options_block():
    return ts.render_options(ts.build_options(
        [("search_flights", FLIGHTS_SWAT), ("search_hotels", HOTELS_SWAT)],
        "Swat", passengers=2, preferred_mode="flight"))


def _hunza_options_block():
    return ts.render_options(ts.build_options(
        [("search_flights", FLIGHTS_HUNZA), ("search_hotels", HOTELS_HUNZA)],
        "Hunza", passengers=2, preferred_mode="flight"))


def _swat_plan_card():
    options = ts.parse_options(_swat_options_block())
    picks = ts.merge_picks(options, "Flight 1, Hotel 1, Transfer 1", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    return ts.render_plan(plan, options, picks, "Swat")


BOOKED_CONFIRMATION = {"role": "assistant", "content": "Your Swat trip is booked! PNR: ABC123."}


# ── Minimum required cases ────────────────────────────────────────────────────

def test_old_swat_options_are_rejected_once_a_new_hunza_trip_starts():
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "Flight 1, Hotel 1, Transfer 1"},
        {"role": "assistant", "content": _swat_plan_card()},
        {"role": "user", "content": "yes"},
        BOOKED_CONFIRMATION,
        {"role": "user", "content": "Now plan a trip to Hunza for me"},
        {"role": "assistant", "content": (
            "Sure! For your Hunza trip, could you tell me your travel dates, "
            "number of travellers, and budget?"
        )},
    ]
    assert ts.find_options(history) == {}


def test_current_swat_options_still_resolve_for_a_current_swat_selection():
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
    ]
    options = ts.find_options(history)
    assert options and options["destination"] == "Swat"
    picks = ts.merge_picks(options, "Flight 1, Hotel 1, Transfer 1", {}).picks
    assert ts.complete(options, picks)


def test_first_completion_selection_regression_still_passes():
    """Unrelated to staleness — the ordinary, single-turn happy path."""
    options = ts.build_options(
        [("search_flights", FLIGHTS_HUNZA), ("search_hotels", HOTELS_HUNZA)],
        "Hunza", passengers=2, preferred_mode="flight")
    rendered = ts.render_options(options)
    parsed = ts.parse_options(rendered)
    picks = ts.merge_picks(parsed, "Flight 1, Hotel 1, Transfer 1", {}).picks
    assert ts.complete(parsed, picks)
    plan = ts.build_plan(parsed, picks)
    assert plan is not None


def test_no_options_in_history_behaves_exactly_as_before():
    assert ts.find_options([]) == {}
    assert ts.find_options([{"role": "user", "content": "hello"}]) == {}
    assert ts.find_options([{"role": "assistant", "content": "Sure, what dates?"}]) == {}


def test_same_destination_continuation_is_accepted():
    """The traveller keeps talking about Swat — nothing invalidates the block."""
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "What's the weather like there in August?"},
        {"role": "assistant", "content": "Warm days, cool evenings — pack layers."},
    ]
    options = ts.find_options(history)
    assert options and options["destination"] == "Swat"


# ── Edge cases A-H from the task ──────────────────────────────────────────────

def test_A_normal_continuation_still_resolves():
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
    ]
    options = ts.find_options(history)
    picks = ts.merge_picks(options, "Flight 1, Hotel 1, Transfer 1", {}).picks
    assert ts.complete(options, picks)
    plan = ts.build_plan(options, picks)
    assert plan is not None


def test_B_new_destination_after_booking_rejects_old_options():
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "Flight 1, Hotel 1, Transfer 1"},
        {"role": "assistant", "content": _swat_plan_card()},
        {"role": "user", "content": "yes"},
        BOOKED_CONFIRMATION,
        {"role": "user", "content": "Now plan a trip to Hunza for me"},
        {"role": "assistant", "content": "Sure! What dates, travellers and budget?"},
    ]
    assert ts.find_options(history) == {}


def test_C_same_destination_is_not_unnecessarily_invalidated():
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "Actually can you show me 5-star hotels only"},
        {"role": "assistant", "content": "Here are the same options, filtered..."},
    ]
    options = ts.find_options(history)
    assert options and options["destination"] == "Swat"


def test_D_different_destination_after_old_options_is_rejected():
    """Karachi -> Hunza mentioned after old Karachi -> Swat options."""
    history = [
        {"role": "user", "content": "Karachi to Swat please"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "Karachi to Hunza instead"},
        {"role": "assistant", "content": "Sure — what dates for Hunza?"},
    ]
    assert ts.find_options(history) == {}


def test_E_no_options_case_unchanged():
    history = [
        {"role": "user", "content": "book me a sedan to Naran for tomorrow 9am"},
        {"role": "assistant", "content": "Got it — what's the pickup address?"},
    ]
    assert ts.find_options(history) == {}


def test_F_this_task_does_not_touch_the_limit_20_behavior():
    """Nothing about this fix depends on or changes conversation window size —
    the same fixed-size history either resolves or doesn't, regardless of how
    many messages get fetched. Not a limit=20 regression test, just a sanity
    check that this fix's logic is length-agnostic."""
    history = [{"role": "user", "content": f"aside {i}"} for i in range(15)]
    history += [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
    ]
    options = ts.find_options(history)
    assert options and options["destination"] == "Swat"


def test_G_existing_confirmation_flow_unaffected():
    options = ts.parse_options(_swat_options_block())
    picks = ts.merge_picks(options, "Flight 1, Hotel 1, Transfer 1", {}).picks
    assert ts.is_confirmation("yes") is True
    plan = ts.build_plan(options, picks)
    assert plan is not None
    text = ts.render_plan(plan, options, picks, "Swat")
    assert ts.plan_was_shown([{"role": "assistant", "content": text}])


def test_H_existing_followup_answer_still_recognised():
    """"Islamabad Airport" answering the pickup-address question must still
    be classified as an answer, not a question — unrelated to this fix, but
    confirming it wasn't touched."""
    assert ts.looks_like_a_followup_answer("Islamabad Airport") is True
    assert ts.looks_like_a_followup_answer("Can I change the hotel?") is False


# ── The rejection falls back to the existing safe "nothing to resolve" path ──

def test_a_rejected_stale_block_produces_no_partial_plan():
    """Requirement 5: rejection must never silently book anything — {} is
    handled by the SAME existing code path as "no options ever shown"."""
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "Flight 1, Hotel 1, Transfer 1"},
        {"role": "assistant", "content": _swat_plan_card()},
        {"role": "user", "content": "yes"},
        BOOKED_CONFIRMATION,
        {"role": "user", "content": "Now plan a trip to Hunza for me"},
        {"role": "assistant", "content": "Sure! What dates, travellers and budget?"},
    ]
    options = ts.find_options(history)
    assert options == {}
    # complete()/build_plan() are never even reachable on an empty options dict
    # in the real caller (master_agent.py only enters that branch `if
    # _planner_options:`), but assert the pure functions agree too:
    assert ts.complete(options, {}) is False


# ── A same-destination options block genuinely newer than a stale one wins ───

def test_a_fresh_matching_destination_block_after_a_stale_one_is_used():
    """If Hunza options WERE actually rendered after the destination change,
    find_options must resolve against THOSE, not report staleness at all —
    the backward walk finds the nearer, valid block first."""
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _swat_options_block()},
        {"role": "user", "content": "Flight 1, Hotel 1, Transfer 1"},
        {"role": "assistant", "content": _swat_plan_card()},
        {"role": "user", "content": "yes"},
        BOOKED_CONFIRMATION,
        {"role": "user", "content": "Now plan a trip to Hunza for me"},
        {"role": "assistant", "content": _hunza_options_block()},
    ]
    options = ts.find_options(history)
    assert options and options["destination"] == "Hunza"
