"""
An explicitly stated transport preference is the traveller's decision, enforced
in code.

Two defects this closes, both found by tracing rather than by a failing test:

1. TripState.mode went blank whenever a message named more than one thing, and
   a Trip Planner opening almost always names a hotel — so "Karachi to Hunza,
   train, 4 star hotel" recorded NO transport preference at all. The one
   sentence where the choice matters most was the one that lost it.

2. The northern expansion in prompt_builder._signals ships BOTH transport
   searches regardless of what was asked for, and trip_package._collect takes
   whichever transport it meets FIRST in `gathered` — i.e. whichever the model
   happened to call first. Measured on identical input:

       model called flights first -> flight trip, hub Gilgit,     transfer PKR 7,000
       model called trains  first -> train  trip, hub Rawalpindi, transfer PKR 38,000

   Same request, different trip, different hub, 5x the transfer fare — decided
   by nothing more than tool-call ordering.

Enforcement is three narrow gates: the preference is parsed independently of
the hotel word (A), the unwanted search tool is withheld so the model cannot
call it (B1), and the unwanted results are dropped before composition even if
they somehow arrive (B2). When the requested mode has nothing, the traveller is
asked rather than switched (C).
"""
import json

import pytest

from agents import trip_selection as ts
from agents.conversation_state import derive_state, transport_preference
from agents.prompt_builder import select_tool_names

FLIGHTS = json.dumps({
    "passengers": 2,
    "flights": [{"flight_number": "PK605", "airline": "PIA", "from": "Karachi",
                 "to": "Gilgit", "depart": "2026-09-10 07:00", "arrive": "08:46",
                 "cabin": "ECONOMY", "total_price_pkr": 85120}],
})
TRAINS = json.dumps({
    "passengers": 2,
    "trains": [{"train_name": "Green Line", "train_number": "5-Up",
                "from": "Karachi", "to": "Rawalpindi",
                "depart": "2026-09-10 07:00", "arrive": "2026-09-11 05:00",
                "classes": [{"class": "AC Business", "total_price_pkr": 24000},
                            {"class": "Economy", "total_price_pkr": 9000}]}],
})


def _hotels(city):
    return json.dumps({"city": city, "nights": 3, "rooms": 1, "guests": 2,
                       "hotels": [{"name": f"{city} Inn", "stars": 4,
                                   "price_per_night_pkr": 9000,
                                   "total_stay_pkr": 27000}]})


def _searches(message, history=None):
    return [t for t in select_tool_names(message, history) if t.startswith("search_")]


# ── A. The preference survives a hotel in the same sentence ──────────────────

@pytest.mark.parametrize("message,expected", [
    ("I want to travel by train to Hunza", "train"),
    ("I prefer flight to Hunza", "flight"),
    ("Karachi to Hunza, train, 4 star hotel", "train"),
    ("Karachi to Hunza, business flight, 4 star hotel", "flight"),
    ("Karachi to Hunza, train, 2 adults, 4 star hotel, budget 300000", "train"),
    ("Karachi to Hunza 10 September 2026 for 2 adults, economy flight, 4 star hotel",
     "flight"),
])
def test_an_explicit_preference_is_recorded(message, expected):
    assert transport_preference(message) == expected
    assert derive_state([], message).transport_mode == expected


@pytest.mark.parametrize("message", [
    "Karachi to Hunza, flight or train?",
    "should I take a train or a flight to Naran?",
    "compare trains and flights to Swat",
])
def test_naming_both_modes_is_a_comparison_not_a_choice(message):
    """Guessing here would pick one of two things the traveller was weighing."""
    assert transport_preference(message) == ""


@pytest.mark.parametrize("message", [
    "Plan a trip to Hunza",
    "Karachi to Hunza for 2 adults, 4 star hotel, budget 300000",
])
def test_no_transport_word_means_no_preference(message):
    assert transport_preference(message) == ""


def test_the_existing_mode_field_is_left_alone():
    """Other code reads `mode`; only the new field carries enforcement."""
    state = derive_state([], "Karachi to Hunza, train, 4 star hotel")
    assert state.mode == ""              # unchanged: two things named
    assert state.transport_mode == "train"


def test_a_preference_carries_across_turns():
    history = [{"role": "user", "content": "by train to Hunza"}]
    assert transport_preference("4 star hotel please", history) == "train"


def test_a_later_change_of_mind_wins():
    history = [{"role": "user", "content": "by train to Hunza"}]
    assert transport_preference("actually make it a flight", history) == "flight"


# ── B1. The unwanted search tool is withheld ─────────────────────────────────

def test_explicit_train_withholds_the_flight_search():
    assert _searches("Karachi to Hunza, train, 4 star hotel") == [
        "search_trains", "search_hotels"]


def test_explicit_flight_withholds_the_train_search():
    assert _searches("Karachi to Hunza, business flight, 4 star hotel") == [
        "search_flights", "search_hotels"]


def test_no_preference_keeps_both_transport_searches():
    assert set(_searches("Plan a trip to Hunza")) == {
        "search_flights", "search_trains", "search_hotels"}


def test_a_comparison_keeps_both_transport_searches():
    assert set(_searches("Karachi to Hunza, flight or train?")) == {
        "search_flights", "search_trains", "search_hotels"}


def test_the_preference_filter_only_applies_to_northern_planning():
    """A non-northern trip never entered the both-tools expansion to begin with."""
    assert _searches("I want to fly Lahore to Karachi on 20 August 2026 for 2") == [
        "search_flights"]


# ── B2. Call order can never decide the mode ─────────────────────────────────

BOTH_FLIGHT_FIRST = [("search_flights", FLIGHTS), ("search_trains", TRAINS),
                     ("search_hotels", _hotels("Hunza"))]
BOTH_TRAIN_FIRST = [("search_trains", TRAINS), ("search_flights", FLIGHTS),
                    ("search_hotels", _hotels("Hunza"))]


@pytest.mark.parametrize("gathered", [BOTH_FLIGHT_FIRST, BOTH_TRAIN_FIRST])
def test_an_explicit_train_composes_a_train_trip_whatever_the_call_order(gathered):
    options = ts.build_options(gathered, "Hunza", preferred_mode="train")
    assert options["transport_kind"] == "train"
    assert all(t["hub"] == "Rawalpindi" for t in options["transfers"])


@pytest.mark.parametrize("gathered", [BOTH_FLIGHT_FIRST, BOTH_TRAIN_FIRST])
def test_an_explicit_flight_composes_a_flight_trip_whatever_the_call_order(gathered):
    options = ts.build_options(gathered, "Hunza", preferred_mode="flight")
    assert options["transport_kind"] == "flight"
    assert all(t["hub"] == "Gilgit" for t in options["transfers"])


def test_the_unwanted_mode_never_appears_among_the_options():
    options = ts.build_options(BOTH_FLIGHT_FIRST, "Hunza", preferred_mode="train")
    labels = " ".join(r["label"] for r in options["transport"])
    assert "PK605" not in labels
    assert "Green Line" in labels


def test_without_a_preference_the_existing_behaviour_is_preserved():
    """Unchanged: first transport in `gathered` wins when nothing was asked for."""
    assert ts.build_options(BOTH_FLIGHT_FIRST, "Hunza")["transport_kind"] == "flight"
    assert ts.build_options(BOTH_TRAIN_FIRST, "Hunza")["transport_kind"] == "train"


# ── Hubs follow the mode actually chosen ─────────────────────────────────────

@pytest.mark.parametrize("destination,mode,hub", [
    ("Hunza", "flight", "Gilgit"),
    ("Hunza", "train", "Rawalpindi"),
    ("Naran", "flight", "Islamabad"),
    ("Naran", "train", "Rawalpindi"),
    ("Swat", "flight", "Islamabad"),
    ("Swat", "train", "Rawalpindi"),
])
def test_the_transfer_leaves_the_hub_for_the_chosen_mode(destination, mode, hub):
    gathered = [("search_flights", FLIGHTS), ("search_trains", TRAINS),
                ("search_hotels", _hotels(destination))]
    options = ts.build_options(gathered, destination, preferred_mode=mode)
    assert options["transport_kind"] == mode
    assert options["transfers"] and all(t["hub"] == hub for t in options["transfers"])


def test_skardu_stays_transfer_free_with_an_explicit_flight():
    gathered = [("search_flights", FLIGHTS), ("search_hotels", _hotels("Skardu"))]
    options = ts.build_options(gathered, "Skardu", preferred_mode="flight")
    assert options["transport_kind"] == "flight"
    assert options["transfers"] == []


# ── C. No silent switching ───────────────────────────────────────────────────

def test_no_trains_available_does_not_fall_back_to_flights():
    gathered = [("search_flights", FLIGHTS), ("search_hotels", _hotels("Hunza"))]
    assert ts.preferred_transport_missing(gathered, "train") == "flight"
    assert ts.build_options(gathered, "Hunza", preferred_mode="train") == {}


def test_no_flights_available_does_not_fall_back_to_trains():
    gathered = [("search_trains", TRAINS), ("search_hotels", _hotels("Hunza"))]
    assert ts.preferred_transport_missing(gathered, "flight") == "train"
    assert ts.build_options(gathered, "Hunza", preferred_mode="flight") == {}


def test_nothing_is_flagged_when_the_requested_mode_has_results():
    assert ts.preferred_transport_missing(BOTH_FLIGHT_FIRST, "train") == ""
    assert ts.preferred_transport_missing(BOTH_FLIGHT_FIRST, "flight") == ""


def test_nothing_is_flagged_without_a_preference():
    assert ts.preferred_transport_missing(BOTH_FLIGHT_FIRST, "") == ""


def test_the_message_names_the_gap_and_asks_rather_than_switching():
    text = ts.no_preferred_transport_message("train", "flight")
    assert "any train options" in text
    assert "haven't switched you" in text
    assert "Would you like me to search flights instead?" in text
    assert "PKR" not in text                       # invents no price
    assert not any(c.isdigit() for c in text)      # invents no figure at all


def test_agreeing_to_switch_becomes_the_new_preference():
    """The traveller's answer is an ordinary message — it just re-reads as a choice."""
    history = [{"role": "user", "content": "Karachi to Hunza by train"}]
    assert transport_preference("yes, search flights instead", history) == "flight"


# ── Standalone flows are untouched ───────────────────────────────────────────

@pytest.mark.parametrize("message,expected", [
    ("I want to fly Lahore to Karachi on 20 August 2026 for 2", ["search_flights"]),
    ("find me a train from Lahore to Karachi on 20 August 2026 for 2", ["search_trains"]),
    ("find me a hotel in Islamabad for 3 nights", ["search_hotels"]),
    ("book me a sedan from DHA phase 5 to the airport tomorrow 9am", ["book_car"]),
    ("book me a sedan to Naran for tomorrow 9am", ["book_car"]),
])
def test_standalone_requests_are_unchanged(message, expected):
    assert select_tool_names(message) == expected


def test_a_non_northern_flight_and_hotel_search_still_builds_no_option_block():
    gathered = [("search_flights", FLIGHTS), ("search_hotels", _hotels("Lahore"))]
    assert ts.build_options(gathered, "Lahore", preferred_mode="flight") == {}
