"""
Selectable booking results MUST be rendered as a NUMBERED list.

This is a protocol contract between the two halves of the booking flow, not a
style preference. The backend recognises "there are offers on the table" by
looking for digit-prefixed rows (prompt_builder._OFFER_LIST_RE); a bullet or
dash list is invisible to it. When that detection fails, `offers_on_table`
stays False, prepare_booking is never selected for the follow-up turn, and the
model — with no tool to commit with — narrates "I've booked ..." in prose while
nothing is actually booked or charged.

That is a real bug this file exists to prevent: a Swat trip whose flights and
hotels were rendered as bullets, so the only thing that ever committed was the
standalone flat-rate car booking (whose tool needs no offer list to be
selected), bypassing the package/transfer flow entirely.

Both ends are pinned here: what our own deterministic renderer emits, and that
the prompts still instruct the model to do the same.
"""
import json

import pytest

from agents import deterministic_reply as dr
from agents.prompt_builder import _looks_like_offer_list, select_tool_names
from prompts.master_agent import MASTER_AGENTIC_CORE, MASTER_SYSTEM

FLIGHTS = json.dumps({
    "search_date": "2026-08-20",
    "passengers": 2,
    "flights": [
        {"flight_number": "PA401", "airline_code": "PA", "airline": "Airblue",
         "from": "LHE", "to": "KHI", "depart": "2026-08-20 08:00", "arrive": "09:55",
         "cabin": "ECONOMY", "total_price_pkr": 35000, "price_per_seat_pkr": 17500,
         "seats_left": 4},
        {"flight_number": "ER198", "airline_code": "ER", "airline": "AirSial",
         "from": "LHE", "to": "KHI", "depart": "2026-08-20 16:10", "arrive": "18:05",
         "cabin": "ECONOMY", "total_price_pkr": 33000, "price_per_seat_pkr": 16500,
         "seats_left": 9},
    ],
})

TRAINS = json.dumps({
    "passengers": 2, "search_date": "2026-08-20",
    "trains": [{
        "train_name": "Tezgam Express", "train_number": "7-Up",
        "depart": "2026-08-20 06:00", "arrive": "2026-08-20 22:30", "duration": "16h30m",
        "classes": [
            {"class": "AC Business", "total_price_pkr": 24000, "price_per_seat_pkr": 12000},
            {"class": "Economy", "total_price_pkr": 9000, "price_per_seat_pkr": 4500},
        ],
    }],
})

HOTELS = json.dumps({
    "city": "Islamabad", "check_in": "2026-08-20", "check_out": "2026-08-23",
    "nights": 3, "rooms": 1,
    "hotels": [
        {"name": "Serena Hotel", "stars": 5, "area": "Sector G-5",
         "price_per_night_pkr": 30000, "total_stay_pkr": 90000},
        {"name": "Hotel One", "stars": 3, "area": "Blue Area",
         "price_per_night_pkr": 9000, "total_stay_pkr": 27000},
    ],
})


# ── The detector itself: numbered counts, bulleted does not ──────────────────

BULLETED = (
    "Here are the options for the outbound journey on August 14:\n"
    "- Pakistan International Airlines: PKR 69,256 total, departing 7:00 AM\n"
    "- Airblue: PKR 129,492 total, departing 7:00 AM\n"
)
NUMBERED = (
    "Here are the options for the outbound journey on August 14:\n"
    "1. Pakistan International Airlines: PKR 69,256 total, departing 7:00 AM\n"
    "2. Airblue: PKR 129,492 total, departing 7:00 AM\n"
)


def test_a_bulleted_offer_list_is_not_recognised_as_offers():
    """Documents exactly why the prompt rule exists — this is the failure."""
    assert not _looks_like_offer_list(BULLETED)


def test_the_same_list_numbered_is_recognised():
    assert _looks_like_offer_list(NUMBERED)


# ── Our own renderer holds up its end of the same contract ──────────────────

@pytest.mark.parametrize("tool,payload", [
    ("search_flights", FLIGHTS),
    ("search_trains", TRAINS),
    ("search_hotels", HOTELS),
])
def test_every_rendered_result_list_is_recognised_as_offers(tool, payload):
    rendered = dr.render([(tool, payload)], "show me options")
    assert rendered, f"{tool} rendered nothing"
    assert _looks_like_offer_list(rendered), (
        f"{tool} rendered a list the offer detector cannot see:\n{rendered}"
    )


def test_a_rendered_round_trip_pair_is_recognised_as_offers():
    """Two labelled lists (Outbound, then Return) in one reply."""
    rendered = dr.render([("search_flights", FLIGHTS), ("search_flights", FLIGHTS)], "roundtrip")
    assert _looks_like_offer_list(rendered)


# ── The pick round-trip: "option 2" against a real rendered list ─────────────

@pytest.mark.parametrize("tool,payload", [
    ("search_flights", FLIGHTS),
    ("search_trains", TRAINS),
    ("search_hotels", HOTELS),
])
def test_option_2_against_a_rendered_list_still_selects_prepare_booking(tool, payload):
    history = [{"role": "assistant", "content": dr.render([(tool, payload)], "options")}]
    assert "prepare_booking" in select_tool_names("option 2", history)


def test_a_bare_number_against_a_rendered_list_still_selects_prepare_booking():
    history = [{"role": "assistant", "content": dr.render([("search_flights", FLIGHTS)], "options")}]
    assert "prepare_booking" in select_tool_names("2", history)


@pytest.mark.parametrize("reply", [
    # The real message from the reported Swat bug, plus ordinary phrasings.
    "3\ndrop off is selected hotel and SUV",
    "the cheapest one please",
    "yes that works",
])
def test_bulleting_the_same_list_withholds_prepare_booking(reply):
    """
    The counterexample, pinned so the coupling stays visible. A bare "2"
    is NOT the case that breaks — it matches the pick regex directly and
    survives either way. What breaks is every reply that instead leans on
    `offers_on_table`: in bullet form the offers are invisible, no
    prepare_booking is offered, and the turn can only end in prose.
    """
    assert "prepare_booking" in select_tool_names(reply, [{"role": "assistant", "content": NUMBERED}])
    assert "prepare_booking" not in select_tool_names(reply, [{"role": "assistant", "content": BULLETED}])


# ── The prompts still carry the rule (a future prose trim can't drop it) ─────

@pytest.mark.parametrize("prompt", [MASTER_AGENTIC_CORE, MASTER_SYSTEM])
def test_the_prompt_still_instructs_numbered_selectable_lists(prompt):
    lowered = prompt.lower()
    assert "numbered" in lowered
    assert "never bullets" in lowered
