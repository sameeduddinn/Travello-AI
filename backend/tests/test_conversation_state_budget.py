"""
A budget stated in "k" shorthand under PKR 100,000 ("50k", "5k") never parsed
into TripState.budget_pkr at all.

_BUDGET_RE required its digit-capture group to be 3-12 characters long — a
guard meant to stop a stray flight/gate number from being misread as a
budget — but that same floor applied even when the number carried a "k"
multiplier, whose own digits are legitimately only 1-2 characters ("50k" is
"50" + "k", i.e. 2 digits). So "budget is 50k" silently produced no budget at
all: not a wrong value, no value, meaning the Trip Planner never showed a
Budget/Remaining/Over-budget line and never warned the traveller their
selections were over what they'd actually stated.

A second, compounding gap: the keyword and the amount had to be adjacent
(only whitespace/connector words like "is"/"of" allowed between them), so
"my overall budget for flight and hotel is 50k" failed regardless of the
digit-floor fix, because "for flight and hotel" sits between "budget" and
"is 50k". Fixed alongside the digit-floor fix by tolerating a few filler
words in between.
"""
from agents.conversation_state import derive_state


def test_a_bare_k_shorthand_budget_is_parsed():
    state = derive_state([], "no my budget is 50k")
    assert state.budget_pkr == 50000


def test_a_single_digit_k_shorthand_budget_is_parsed():
    state = derive_state([], "budget is 5k")
    assert state.budget_pkr == 5000


def test_a_k_shorthand_budget_with_filler_words_is_parsed():
    state = derive_state(
        [], "my overall budget for flight and hotel is 50k that's is")
    assert state.budget_pkr == 50000


def test_a_three_digit_k_shorthand_budget_still_works():
    # Regression: this case worked before the fix — must keep working.
    state = derive_state([], "budget is 500k")
    assert state.budget_pkr == 500000


def test_a_spelled_out_budget_still_works():
    state = derive_state([], "budget is 300,000")
    assert state.budget_pkr == 300000


def test_a_flight_number_is_not_read_as_a_budget():
    # Regression: the {3,12}-digit floor exists specifically to reject this.
    state = derive_state([], "flight PK305 landing at gate 12")
    assert state.budget_pkr is None


def test_a_restated_k_shorthand_budget_overrides_the_earlier_none():
    history = [
        {"role": "user", "content": "i want to book a flight to hunza my overall "
                                     "budget for flight and hotel is 50k that's is"},
        {"role": "assistant", "content": "You're planning a trip to Hunza, bhai."},
    ]
    state = derive_state(history, "no my budget is 50k")
    assert state.budget_pkr == 50000
