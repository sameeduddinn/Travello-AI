"""
The Trip Planner opens by asking for everything at once as a numbered list, and
users answer it the same way. This file covers the two failures that shape had:

1. derive_state couldn't read any of the answers that matter for money — a
   written date range, a party given as adults + children, or a bare budget
   figure whose only clue is its POSITION in the list. Dates blank meant no
   stay length, "2 adults and 2 Children" priced four seats as two, and a
   missing budget silently killed the package recommendation entirely.

2. Even with the state right, the turn dead-ended. The gate correctly told the
   model "still needs hotels in Hunza", the model spent its next step
   re-searching flights instead, and _MAX_TOOL_STEPS ran out with nothing to
   show — the user got "I'm having trouble responding right now."
   _package_fill_call runs that missing search in code instead.

Traced against the real reply the app produced for:
    1. Yes
    2. 14 August 2026 to 25 August 2026
    3. 2 adults and 2 Children
    4. 300,000
    5. Flight (Business Class)
    6. 4 Star rating
    7. Yes
"""
from datetime import date

import pytest

from agents.conversation_state import derive_state
from agents.master_agent import _package_fill_call

TODAY = date(2026, 8, 7)

PLANNER_QUESTIONS = {"role": "assistant", "content": (
    "To put together a complete Hunza Valley package for you, I just need a few details:\n"
    "1. **Departure city** (Karachi is your home city, but let me confirm).\n"
    "2. **Travel dates** — either a specific start date and how many nights, or a range.\n"
    "3. **Number of travelers** — adults and children separately.\n"
    "4. **Budget** — total PKR you'd like to spend on the whole trip.\n"
    "5. **Transport preference** — a flight to Gilgit, or a train?\n"
    "6. **Hotel preference** — any star rating or type?\n"
    "7. **Car for the road leg** — a driver from Gilgit to Hunza?"
)}
PLANNER_ANSWERS = (
    "1. Yes\n"
    "2. 14 August 2026 to 25 August 2026\n"
    "3. 2 adults and 2 Children\n"
    "4. 300,000\n"
    "5. Flight (Business Class)\n"
    "6. 4 Star rating\n"
    "7. Yes"
)
HISTORY = [{"role": "user", "content": "Plan a trip to Hunza Valley"}, PLANNER_QUESTIONS]


def _state(message=PLANNER_ANSWERS, history=None):
    return derive_state(history if history is not None else HISTORY, message, today=TODAY)


# ── The reported turn, end to end ────────────────────────────────────────────

def test_the_reported_answers_are_read_completely():
    state = _state()
    assert state.destination == "Hunza"
    assert state.travel_date == "2026-08-14"
    assert state.return_date == "2026-08-25"
    assert state.passengers == 4
    assert state.budget_pkr == 300000


# ── Written dates ────────────────────────────────────────────────────────────

@pytest.mark.parametrize("text,expected", [
    ("14 August 2026 to 25 August 2026", ("2026-08-14", "2026-08-25")),
    ("14 Aug 2026 to 25 Aug 2026", ("2026-08-14", "2026-08-25")),
    ("14 to 25 August 2026", ("2026-08-14", "2026-08-25")),
    ("14-25 August 2026", ("2026-08-14", "2026-08-25")),
    ("August 14 2026 until August 25 2026", ("2026-08-14", "2026-08-25")),
    ("leaving 14th August 2026, back 25th August 2026", ("2026-08-14", "2026-08-25")),
])
def test_written_date_ranges_become_travel_and_return_dates(text, expected):
    state = derive_state([], text, today=TODAY)
    assert (state.travel_date, state.return_date) == expected


def test_a_single_written_date_sets_only_the_travel_date():
    state = derive_state([], "I want to leave on 20 September 2026", today=TODAY)
    assert state.travel_date == "2026-09-20"
    assert state.return_date == ""


def test_a_bare_written_date_rolls_forward_instead_of_landing_in_the_past():
    """"14 August" with today at 7 Aug 2026 means THIS August, not a past one."""
    assert derive_state([], "leaving 14 August", today=TODAY).travel_date == "2026-08-14"


def test_a_bare_written_date_already_past_this_year_rolls_to_next_year():
    assert derive_state([], "leaving 3 March", today=TODAY).travel_date == "2027-03-03"


def test_a_written_date_that_has_already_passed_is_ignored():
    assert derive_state([], "I flew on 1 January 2020", today=TODAY).travel_date == ""


def test_an_impossible_written_date_is_ignored_rather_than_guessed():
    assert derive_state([], "31 February 2026", today=TODAY).travel_date == ""


def test_iso_dates_still_win_over_written_ones():
    """ISO is unambiguous; the written pass exists only for turns without one."""
    state = derive_state([], "2026-09-01 to 2026-09-05 (that's 1 Sept to 5 Sept)", today=TODAY)
    assert (state.travel_date, state.return_date) == ("2026-09-01", "2026-09-05")


@pytest.mark.parametrize("text", [
    "4 Star rating",
    "300,000",
    "flight PK304",
    "2 adults and 2 children",
])
def test_ordinary_answers_are_never_mistaken_for_dates(text):
    assert derive_state([], text, today=TODAY).travel_date == ""


@pytest.mark.parametrize("text", [
    "we are 4 may be 5 people",
    "2 may be enough",
    "can you 2 march the price down",
])
def test_may_and_march_as_ordinary_words_do_not_become_travel_dates(text):
    """
    Both are English words as well as months, and both follow a number
    naturally — "we are 4 may be 5 people" set a 4 May travel date nobody gave.
    """
    assert derive_state([], text, today=TODAY).travel_date == ""


@pytest.mark.parametrize("text,expected", [
    ("book for 3 may 2027", "2027-05-03"),      # a year settles it
    ("leaving 3 May", "2027-05-03"),            # a date cue settles it
    ("departing 12 March", "2027-03-12"),
    ("3 to 8 May 2027", "2027-05-03"),          # a day range settles it
])
def test_may_and_march_are_still_read_when_genuinely_dates(text, expected):
    assert derive_state([], text, today=TODAY).travel_date == expected


# ── Party size: adults + children ────────────────────────────────────────────

@pytest.mark.parametrize("text,expected", [
    ("2 adults and 2 Children", 4),
    ("2 adults, 2 children", 4),
    ("2 adults and 1 child", 3),
    ("3 children and 2 adults", 5),
    ("2 adults with 2 kids", 4),
])
def test_adults_plus_children_is_the_real_seat_count(text, expected):
    """Fare is per-seat x passengers — reading only the adults halves the package."""
    assert derive_state([], text, today=TODAY).passengers == expected


@pytest.mark.parametrize("text,expected", [
    ("2 adults", 2),
    ("for 3 people", 3),
    ("4 passengers", 4),
    ("we are 2 travellers", 2),
])
def test_a_plain_party_size_is_unchanged(text, expected):
    assert derive_state([], text, today=TODAY).passengers == expected


def test_a_party_size_is_still_never_invented():
    assert derive_state([], "book a flight for my family", today=TODAY).passengers is None


# ── Budget read from the numbered question it answers ────────────────────────

def test_a_bare_budget_answer_is_read_from_its_question_number():
    """"4. 300,000" has no keyword at all — only its position says it's money."""
    assert _state().budget_pkr == 300000


def test_a_budget_answer_written_as_k_is_read():
    answers = PLANNER_ANSWERS.replace("4. 300,000", "4. 300k")
    assert _state(answers).budget_pkr == 300000


def test_a_number_answering_a_non_budget_question_is_not_a_budget():
    """Line 6 is the star rating and line 3 the party size — neither is money."""
    questions = {"role": "assistant", "content": (
        "1. How many travelers?\n"
        "2. What star rating do you want?\n"
    )}
    state = derive_state([questions], "1. 4\n2. 5", today=TODAY)
    assert state.budget_pkr is None


def test_alignment_never_overrides_an_explicit_budget_statement():
    answers = PLANNER_ANSWERS.replace("4. 300,000", "4. my budget is PKR 450,000")
    assert _state(answers).budget_pkr == 450000


def test_a_three_digit_answer_is_not_treated_as_a_budget():
    """Same floor the keyword scanner uses — a real PKR trip budget isn't 3 digits."""
    answers = PLANNER_ANSWERS.replace("4. 300,000", "4. 300")
    assert _state(answers).budget_pkr is None


def test_an_unnumbered_reply_to_a_numbered_list_is_not_misaligned():
    state = derive_state([PLANNER_QUESTIONS], "sounds good, let's do it", today=TODAY)
    assert state.budget_pkr is None


def test_alignment_pairs_each_answer_with_the_question_it_actually_answered():
    """
    Two rounds of numbered questions: the budget must come from the round the
    user was replying to, not from whichever list happened to be scanned last.
    """
    history = [
        {"role": "assistant", "content": "1. Which city?\n2. Budget in PKR?"},
        {"role": "user", "content": "1. Hunza\n2. 250,000"},
        {"role": "assistant", "content": "1. How many nights?\n2. How many rooms?"},
    ]
    assert derive_state(history, "1. 5\n2. 2", today=TODAY).budget_pkr == 250000


# ── Running the missing search in code instead of asking for it ──────────────

HOTEL_GAP = ["hotels in Hunza (search_hotels)"]
TRANSPORT_GAP = ["transport to the hub (search_flights or search_trains)"]
FLIGHT_ARGS = {
    "origin_city": "Karachi", "destination_city": "Gilgit",
    "travel_date": "2026-08-14", "passengers": 4, "cabin_class": "BUSINESS",
}


def test_a_missing_hotel_search_is_filled_from_state():
    fill = _package_fill_call(HOTEL_GAP, _state(), FLIGHT_ARGS)
    assert fill == ("search_hotels", {
        "city": "Hunza", "check_in": "2026-08-14",
        "check_out": "2026-08-25", "guests": 4,
    })


def test_the_filled_city_is_canonical_not_the_alias_the_user_typed():
    """Karimabad and Hunza are one place; the search must use the app's name."""
    state = derive_state(
        [PLANNER_QUESTIONS],
        "trip to Karimabad\n2. 14 August 2026 to 25 August 2026\n3. 2 adults",
        today=TODAY,
    )
    fill = _package_fill_call(HOTEL_GAP, state, {})
    assert fill and fill[1]["city"] == "Hunza"


def test_the_check_in_falls_back_to_the_date_the_transport_search_used():
    """The model resolves the date for its own search; reuse it rather than re-parse."""
    state = derive_state([], "trip to Hunza for 3 nights", today=TODAY)
    fill = _package_fill_call(HOTEL_GAP, state, FLIGHT_ARGS)
    assert fill and fill[1]["check_in"] == "2026-08-14"
    assert fill[1]["check_out"] == "2026-08-17"      # +3 nights, as stated


def test_no_fill_when_the_stay_length_would_have_to_be_invented():
    """One date and no return or nights count — a made-up stay is a made-up price."""
    state = derive_state([], "trip to Hunza on 14 August 2026", today=TODAY)
    assert _package_fill_call(HOTEL_GAP, state, {}) is None


def test_no_fill_when_no_destination_is_known():
    assert _package_fill_call(HOTEL_GAP, derive_state([], "plan me a trip"), FLIGHT_ARGS) is None


def test_no_fill_when_transport_is_missing_too():
    """Nothing to combine a hotel with — the model is asked, not second-guessed."""
    assert _package_fill_call(TRANSPORT_GAP + HOTEL_GAP, _state(), {}) is None


def test_the_transport_gap_alone_is_never_filled():
    """Choosing a hub, a mode and an origin unprompted is guesswork, not recovery."""
    assert _package_fill_call(TRANSPORT_GAP, _state(), {}) is None


def test_nothing_is_filled_when_nothing_is_missing():
    assert _package_fill_call([], _state(), FLIGHT_ARGS) is None


def test_guests_are_omitted_rather_than_assumed_when_the_party_is_unknown():
    state = derive_state([], "trip to Hunza 14 August 2026 to 25 August 2026", today=TODAY)
    fill = _package_fill_call(HOTEL_GAP, state, {})
    assert fill and "guests" not in fill[1]


def test_a_check_out_that_is_not_after_check_in_is_refused():
    state = derive_state([], "Hunza 2026-08-14 to 2026-08-14", today=TODAY)
    assert _package_fill_call(HOTEL_GAP, state, {}) is None


def test_a_stated_room_count_rides_along():
    state = derive_state(
        [], "Hunza 14 August 2026 to 25 August 2026 for 4 people, 2 rooms", today=TODAY)
    fill = _package_fill_call(HOTEL_GAP, state, {})
    assert fill and fill[1]["rooms"] == 2


# ── The dead-end itself, through the real loop ───────────────────────────────
#
# Same harness as test_northern_trip_planning.py: the REAL
# process_message_agentic loop, with a scripted model that behaves the way the
# live one actually did — it searches flights, is told "still needs hotels in
# Hunza", and searches flights AGAIN. Before the fill, that burned every step
# in _MAX_TOOL_STEPS and the turn ended on "I'm having trouble responding
# right now." Now the hotel search runs in code on the first gap and the turn
# answers with packages regardless of what the model does next.
import asyncio
import json

from agents import master_agent as ma


class _Fn:
    def __init__(self, name, arguments):
        self.name, self.arguments = name, arguments


class _Call:
    def __init__(self, call_id, name, args):
        self.id, self.type = call_id, "function"
        self.function = _Fn(name, json.dumps(args))


class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content, self.tool_calls = content, tool_calls or []


FLIGHT_RESULT = json.dumps({
    "search_date": "2026-08-14", "passengers": 4,
    "flights": [
        {"flight_number": "PA900", "airline": "Airblue",
         "depart": "2026-08-14 07:00", "arrive": "09:05", "total_price_pkr": 113640},
        {"flight_number": "ER628", "airline": "AirSial",
         "depart": "2026-08-14 08:00", "arrive": "10:05", "total_price_pkr": 176712},
    ],
})
HOTEL_RESULT = json.dumps({
    "city": "Hunza", "nights": 11, "rooms": 1, "guests": 4,
    "hotels": [
        {"name": "Old Hunza Inn", "stars": 4.3, "price_per_night_pkr": 13900,
         "total_stay_pkr": 152900, "review_score": 4.3, "breakfast_included": False},
        {"name": "Paradise Valley Guest House", "stars": 3,
         "price_per_night_pkr": 26504, "total_stay_pkr": 291544,
         "review_score": 4.1, "breakfast_included": False},
    ],
})


@pytest.fixture
def planner(monkeypatch):
    """The real loop, with every I/O edge stubbed and the searches scripted."""
    dispatched: list[tuple[str, dict]] = []
    replies: list[str] = []
    model_steps = {"n": 0}

    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return list(HISTORY)

    async def _no_planner_state(_cid):
        return None

    async def _noop_save_planner_state(*a, **k):
        pass

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        replies.append(reply)

    async def _noop(*a, **k):
        return None

    async def _dispatch(*, name, args, **kwargs):
        dispatched.append((name, args))
        if name == "search_flights":
            return FLIGHT_RESULT
        if name == "search_hotels":
            return HOTEL_RESULT
        return json.dumps({})

    async def _model(messages, tools=None, **kwargs):
        """Searches flights, then keeps searching flights — the observed failure."""
        model_steps["n"] += 1
        return _Msg(tool_calls=[_Call(
            f"c{model_steps['n']}", "search_flights",
            {"origin_city": "Karachi", "destination_city": "Gilgit",
             "travel_date": "2026-08-14", "passengers": 4, "cabin_class": "BUSINESS"},
        )])

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _noop)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _noop)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    class _Planner:
        def run(self):
            out = asyncio.run(ma.process_message_agentic("u1", "c1", PLANNER_ANSWERS))
            return out, dispatched, model_steps["n"], replies

    return _Planner()


def test_the_turn_answers_with_options_even_though_the_model_never_searched_hotels(planner):
    out, dispatched, _steps, _replies = planner.run()
    assert [name for name, _ in dispatched].count("search_hotels") == 1
    response = out["response"]
    assert "AVAILABLE FLIGHTS" in response and "AVAILABLE HOTELS" in response
    assert "trouble responding" not in response


def test_the_fill_uses_the_dates_and_party_the_user_actually_gave(planner):
    _out, dispatched, _steps, _replies = planner.run()
    hotel_args = next(args for name, args in dispatched if name == "search_hotels")
    assert hotel_args["city"] == "Hunza"
    assert hotel_args["check_in"] == "2026-08-14"
    assert hotel_args["check_out"] == "2026-08-25"
    assert hotel_args["guests"] == 4


def test_the_package_is_completed_without_spending_another_model_step(planner):
    """The whole point: the step the model would have wasted is never taken."""
    _out, _dispatched, steps, _replies = planner.run()
    assert steps == 1


def test_the_options_are_offered_for_selection_not_auto_composed(planner):
    """The traveller picks each component; nothing is chosen for them."""
    out, _dispatched, _steps, _replies = planner.run()
    response = out["response"]
    assert "Budget —" not in response and "Premium —" not in response
    assert "Pick one from each list" in response
