"""
Deterministic rendering of simple search results — the path that removes the
second LLM call from an ordinary search turn.

Two things are being protected here:
  * COST — a search turn used to cost two provider calls, the second one only to
    reformat data we already had, while carrying the whole tool payload back up.
  * FIDELITY — prices, flight numbers, airline names and hospital phone numbers
    are copied here rather than retyped by a model. Every one of those has been
    a real bug in this codebase.

The payload shapes below are exactly what agents/agent_tools.py serialises.
"""
import json

from agents import deterministic_reply as dr

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

FLIGHTS_RETURN = json.dumps({
    "search_date": "2026-08-25",
    "passengers": 2,
    "flights": [
        {"flight_number": "PK305", "airline_code": "PK", "airline": "PIA",
         "from": "KHI", "to": "LHE", "depart": "2026-08-25 09:00", "arrive": "10:55",
         "total_price_pkr": 36000, "price_per_seat_pkr": 18000},
        {"flight_number": "ER210", "airline_code": "ER", "airline": "AirSial",
         "from": "KHI", "to": "LHE", "depart": "2026-08-25 18:40", "arrive": "20:35",
         "total_price_pkr": 33000, "price_per_seat_pkr": 16500},
    ],
})

FLIGHTS_SOLO = json.dumps({
    "search_date": "2026-08-20", "passengers": 1,
    "flights": [{"flight_number": "PA401", "airline": "Airblue",
                 "depart": "2026-08-20 08:00", "arrive": "09:55",
                 "total_price_pkr": 17500, "price_per_seat_pkr": 17500}],
})

FLIGHTS_EMPTY = json.dumps({
    "flights": [], "available_count": 0, "search_date": "2026-08-20",
    "note": "NO AVAILABILITY: the live search returned ZERO flights for "
            "Lahore -> Skardu on 2026-08-20.",
})

FLIGHT_NO_AIRLINE = json.dumps({
    "passengers": 1,
    "flights": [{"flight_number": "XY123", "airline": "", "depart": "2026-08-20 07:00",
                 "arrive": "08:30", "total_price_pkr": 12000, "price_per_seat_pkr": 12000}],
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

WEATHER_OK = json.dumps({
    "city": "skardu",
    "weather": {"temperature_current": 18, "condition": "Clear", "feels_like": 16},
})
WEATHER_UNAVAILABLE = json.dumps({
    "city": "Naran", "weather_available": False,
    "note": "No live weather data is available for Naran right now.",
})

HEALTHCARE = json.dumps({
    "city": "Lahore", "location": "Lahore",
    "hospitals": [
        {"name": "Services Hospital", "address": "Jail Road", "distance_km": 2.1,
         "phone": "+92-42-99203402"},
        {"name": "Mayo Hospital", "address": "Address unavailable", "distance_km": 3.4,
         "phone": None},
    ],
    "pharmacies": [{"name": "Servaid Pharmacy", "address": "Main Blvd",
                    "distance_km": 0.8, "phone": "+92-42-111000111"}],
    "emergency_numbers": "Rescue 1122 · Ambulance 115 · Police 15",
})

TOOL_ERROR = json.dumps({"error": "tool_execution_error", "tool": "search_flights"})


# ── The gate ──────────────────────────────────────────────────────────────────

def test_a_plain_flight_search_qualifies():
    assert dr.should_render([("search_flights", FLIGHTS)], "flights Lahore to Karachi")


def test_two_legs_of_the_same_search_qualify():
    assert dr.should_render(
        [("search_flights", FLIGHTS), ("search_flights", FLIGHTS_RETURN)],
        "roundtrip Lahore Karachi",
    )


def test_a_flight_plus_hotel_pair_does_not_qualify():
    """That is a package — summarising it is judgement, not formatting."""
    assert not dr.should_render(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)], "flight and hotel")


def test_a_budget_verdict_keeps_the_llm():
    assert not dr.should_render(
        [("search_flights", FLIGHTS)], "flights", has_budget_note=True)


def test_a_pick_turn_keeps_the_llm():
    assert not dr.should_render(
        [("search_flights", FLIGHTS)], "option 2", has_pick_hint=True)


def test_planning_and_advice_keep_the_llm():
    for message in ("plan me a 3 day trip", "which is better?", "what do you recommend?",
                    "compare train vs flight", "why is it so expensive"):
        assert not dr.should_render([("search_flights", FLIGHTS)], message), message


def test_a_failed_tool_result_keeps_the_llm():
    assert not dr.should_render([("search_flights", TOOL_ERROR)], "flights")


def test_nothing_gathered_does_not_qualify():
    assert not dr.should_render([], "flights")


def test_three_tools_do_not_qualify():
    assert not dr.should_render(
        [("search_flights", FLIGHTS), ("search_flights", FLIGHTS),
         ("search_flights", FLIGHTS)], "flights")


# ── Flight rendering ──────────────────────────────────────────────────────────

def test_flights_show_both_per_person_and_party_total():
    """
    A bare total next to "2 passengers" reads as though the head count was
    ignored — the complaint that produced this rule.
    """
    out = dr.render([("search_flights", FLIGHTS)])
    assert "PKR 17,500 per person × 2 = **PKR 35,000 total**" in out
    assert "PKR 16,500 per person × 2 = **PKR 33,000 total**" in out


def test_solo_traveller_gets_a_single_price():
    out = dr.render([("search_flights", FLIGHTS_SOLO)])
    assert "per person ×" not in out
    assert "PKR 17,500" in out


def test_flights_are_numbered_so_a_pick_can_be_resolved():
    out = dr.render([("search_flights", FLIGHTS)])
    assert out.startswith("1. ")
    assert "\n2. " in out


def test_airline_names_come_from_the_data_not_from_the_code():
    out = dr.render([("search_flights", FLIGHTS)])
    assert "Airblue PA401" in out
    assert "AirSial ER198" in out
    # PA is Airblue and ER is AirSial; a model translating the codes itself got
    # this wrong onto a paid ticket, so the mapping must never be inferred here.
    assert "PIA" not in out


def test_a_flight_with_no_airline_shows_the_number_alone():
    out = dr.render([("search_flights", FLIGHT_NO_AIRLINE)])
    assert "XY123" in out


def test_empty_flight_results_relay_the_no_availability_note():
    out = dr.render([("search_flights", FLIGHTS_EMPTY)])
    assert "NO AVAILABILITY" in out
    assert "Skardu" in out
    assert "tell me the number" not in out.lower()   # nothing to pick


def test_departure_time_is_shown_without_the_date_prefix():
    out = dr.render([("search_flights", FLIGHTS)])
    assert "08:00 → 09:55" in out
    assert "2026-08-20 08:00" not in out


# ── Round trip ────────────────────────────────────────────────────────────────

def test_round_trip_renders_two_labelled_lists():
    out = dr.render([("search_flights", FLIGHTS), ("search_flights", FLIGHTS_RETURN)])
    assert "**Outbound**" in out
    assert "**Return**" in out
    assert out.index("**Outbound**") < out.index("**Return**")
    assert "PK305" in out


def test_round_trip_asks_for_a_pick_per_leg():
    """The two-pick phrasing the deterministic leg parser understands."""
    out = dr.render([("search_flights", FLIGHTS), ("search_flights", FLIGHTS_RETURN)])
    assert "1 for outbound" in out
    assert "one payment" in out


def test_round_trip_numbering_restarts_so_picks_map_per_list():
    out = dr.render([("search_flights", FLIGHTS), ("search_flights", FLIGHTS_RETURN)])
    from agents.master_agent import _offer_lists
    lists = _offer_lists(out)
    assert len(lists) == 2, "the pick resolver must see exactly two offer lists"


def test_the_pick_resolver_understands_our_own_rendered_round_trip():
    """
    The integration point between the two halves: this renderer writes the lists,
    and _selection_hint has to be able to read them back a turn later. A detailed
    offer row is well over the old 60-character label ceiling, so before that
    ceiling was replaced by a price check every two-leg pick against a
    deterministically rendered reply silently produced no hint at all.
    """
    from agents.master_agent import _selection_hint

    rendered = dr.render([("search_flights", FLIGHTS), ("search_flights", FLIGHTS_RETURN)])
    history = [{"role": "assistant", "content": rendered}]

    hint = _selection_hint("1 for outbound and 2 for return", history)
    assert hint is not None
    assert "PA401" in hint          # outbound list, item 1
    assert "ER210" in hint          # return list, item 2
    assert "prepare_booking once for EVERY one" in hint


def test_the_pick_resolver_refuses_a_pick_the_list_does_not_have():
    """Guessing beats nothing is exactly wrong here — a wrong leg gets booked."""
    from agents.master_agent import _selection_hint

    short_return = json.dumps({
        "passengers": 1,
        "flights": [{"flight_number": "PK305", "airline": "PIA",
                     "depart": "2026-08-25 09:00", "arrive": "10:55",
                     "total_price_pkr": 18000, "price_per_seat_pkr": 18000}],
    })
    rendered = dr.render([("search_flights", FLIGHTS), ("search_flights", short_return)])
    assert _selection_hint("1 for outbound and 2 for return",
                           [{"role": "assistant", "content": rendered}]) is None


def test_a_single_pick_resolves_against_a_rendered_single_search():
    from agents.master_agent import _selection_hint

    rendered = dr.render([("search_flights", FLIGHTS)])
    hint = _selection_hint("option 2", [{"role": "assistant", "content": rendered}])
    assert hint is not None
    assert "ER198" in hint


# ── Trains and hotels ─────────────────────────────────────────────────────────

def test_trains_show_every_fare_class():
    out = dr.render([("search_trains", TRAINS)])
    assert "Tezgam Express (7-Up)" in out
    assert "AC Business" in out and "Economy" in out
    assert "PKR 12,000 per person × 2 = **PKR 24,000 total**" in out


def test_hotels_quote_the_stay_total_verbatim():
    """
    total_stay_pkr is exactly what gets charged; recomputing it in prose drifted
    and could pair one hotel's rate with another's total.
    """
    out = dr.render([("search_hotels", HOTELS)])
    assert "PKR 30,000/night × 3 nights = **PKR 90,000**" in out
    assert "PKR 9,000/night × 3 nights = **PKR 27,000**" in out
    assert "**Serena Hotel** 5★" in out


# ── Weather ───────────────────────────────────────────────────────────────────

def test_weather_reports_the_live_reading():
    out = dr.render([("get_weather", WEATHER_OK)])
    assert "18°C" in out and "Clear" in out
    assert "Skardu" in out


def test_unavailable_weather_never_states_a_temperature():
    """The synthetic 27°C fallback record must never surface as a real reading."""
    out = dr.render([("get_weather", WEATHER_UNAVAILABLE)])
    assert "°C" not in out
    assert "don't have live weather" in out


# ── Healthcare ────────────────────────────────────────────────────────────────

def test_healthcare_relays_exactly_what_was_returned():
    out = dr.render([("find_healthcare", HEALTHCARE)])
    assert "Services Hospital" in out
    assert "+92-42-99203402" in out
    assert "Servaid Pharmacy" in out
    assert "1122" in out


def test_healthcare_omits_a_placeholder_address_rather_than_inventing_one():
    out = dr.render([("find_healthcare", HEALTHCARE)])
    assert "Address unavailable" not in out
    assert "Mayo Hospital" in out


def test_healthcare_with_no_facilities_still_gives_the_emergency_numbers():
    payload = json.dumps({"city": "Nowhere", "hospitals": [], "pharmacies": [],
                          "emergency_numbers": "Rescue 1122 · Ambulance 115 · Police 15"})
    out = dr.render([("find_healthcare", payload)])
    assert "won't name one from memory" in out
    assert "1122" in out


# ── Safety: rendering never fabricates a booking ──────────────────────────────

def test_no_rendered_reply_ever_looks_like_a_booking_confirmation():
    """
    These strings go straight to the user without a model in the loop, so they
    must never trip the fabricated-booking detector — no fake card, no "booked".
    """
    from agents.master_agent import _is_fabricated_booking

    for gathered in (
        [("search_flights", FLIGHTS)],
        [("search_flights", FLIGHTS), ("search_flights", FLIGHTS_RETURN)],
        [("search_trains", TRAINS)],
        [("search_hotels", HOTELS)],
        [("get_weather", WEATHER_OK)],
        [("get_weather", WEATHER_UNAVAILABLE)],
        [("find_healthcare", HEALTHCARE)],
        [("search_flights", FLIGHTS_EMPTY)],
    ):
        out = dr.render(gathered)
        assert out, gathered[0][0]
        assert not _is_fabricated_booking(out), out[:200]


def test_rendering_never_leaks_a_tool_name():
    from agents.master_agent import _redact_tool_names

    for gathered in ([("search_flights", FLIGHTS)], [("search_hotels", HOTELS)],
                     [("find_healthcare", HEALTHCARE)]):
        out = dr.render(gathered)
        assert _redact_tool_names(out) == out.strip()


def test_render_returns_empty_on_unparseable_input_so_the_caller_falls_back():
    assert dr.render([("search_flights", "not json")]) == ""
    assert dr.render([]) == ""


# ── The displayed arithmetic has to survive a reader checking it ─────────────
#
# The services round the party total, and the per-unit figure is derived as
# round(total / count). Two independent roundings need not reconcile: Tezgam
# AC Standard for 3 came back as total 8,378 with a per-seat of 2,793, and
# 2,793 x 3 is 8,379. The total is the server-verified amount that gets
# charged, so it is the on-screen arithmetic that has to give.

import re


def _claims(text):
    """Every 'PKR a ... x n ... PKR b' the renderer asserts, as (a, n, b)."""
    return [(int(a.replace(",", "")), int(n), int(b.replace(",", "")))
            for a, n, b in re.findall(r"PKR ([\d,]+)[^\n]*?× (\d+)[^\n]*?PKR ([\d,]+)", text)]


def test_an_exact_fare_still_shows_the_multiplication():
    payload = {"passengers": 3, "flights": [{
        "airline": "AirSial", "flight_number": "ER618",
        "price_per_seat_pkr": 14102, "total_price_pkr": 42306}]}
    out = dr.render([("search_flights", json.dumps(payload))])
    assert "PKR 14,102 per person × 3 = **PKR 42,306 total**" in out


def test_a_fare_that_does_not_multiply_back_is_not_asserted_as_a_sum():
    """The live Tezgam AC Standard case, verbatim."""
    payload = {"passengers": 3, "trains": [{
        "train_name": "Tezgam Express", "depart": "2026-09-15 00:00",
        "classes": [{"class": "AC Standard",
                     "price_per_seat_pkr": 2793, "total_price_pkr": 8378}]}]}
    out = dr.render([("search_trains", json.dumps(payload))])

    assert "2,793 per person × 3" not in out          # the false claim
    assert "PKR 8,378" in out                          # what is actually charged
    assert "3" in out and "2,793" in out               # head count and per-seat kept
    assert not [c for c in _claims(out) if c[0] * c[1] != c[2]]


def test_a_nightly_rate_that_does_not_multiply_back_is_not_asserted_either():
    payload = {"nights": 3, "hotels": [{
        "name": "Park Lane Hotel", "price_per_night_pkr": 24529,
        "total_stay_pkr": 73586}]}                     # 24,529 x 3 = 73,587
    out = dr.render([("search_hotels", json.dumps(payload))])

    assert "24,529/night × 3 nights" not in out
    assert "PKR 73,586" in out
    assert not [c for c in _claims(out) if c[0] * c[1] != c[2]]


def test_an_exact_stay_still_shows_the_multiplication():
    payload = {"nights": 3, "hotels": [{
        "name": "Park Lane Hotel", "price_per_night_pkr": 24529,
        "total_stay_pkr": 73587}]}
    out = dr.render([("search_hotels", json.dumps(payload))])
    assert "PKR 24,529/night × 3 nights = **PKR 73,587**" in out


def test_a_single_traveller_never_gets_a_multiplication():
    payload = {"passengers": 1, "flights": [{
        "airline": "AirSial", "flight_number": "ER618",
        "price_per_seat_pkr": 14102, "total_price_pkr": 14102}]}
    out = dr.render([("search_flights", json.dumps(payload))])
    assert "×" not in out


def test_the_exactness_check_itself():
    exact = dr._multiplies_exactly
    assert exact(2793, 3, 8379) is True
    assert exact(2793, 3, 8378) is False
    assert exact(14102, 3, 42306) is True
    assert exact(None, 3, 8378) is False
    assert exact("junk", 3, 8378) is False
