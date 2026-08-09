"""
Trip Planner builds complete PACKAGES, not a parts list.

The behaviour this locks in: a northern trip request must never come back as
"here are 6 flights, pick one". Once a turn holds transport AND hotel results
they are combined into whole priced itineraries — transport + stay + the
hub->destination car leg — compared against the stated budget, and offered as
numbered packages the traveller picks ONE of.

Composition and every total are computed here in code rather than by the
model, for the same reason the rest of this codebase derives money
server-side: a model asked to add four figures will eventually quote a
nightly rate as a stay total or pair a price with the wrong row.
"""
import json

import pytest

from agents.trip_package import (
    build,
    can_build,
    find_rendered,
    missing_for_package,
    parse_rendered,
    render,
    selection_instruction,
)

FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 4,
    "flights": [
        {"flight_number": "PK948", "airline": "Pakistan International Airlines",
         "depart": "2026-08-14 07:00", "arrive": "09:03", "total_price_pkr": 69256},
        {"flight_number": "PA911", "airline": "Airblue",
         "depart": "2026-08-14 07:00", "arrive": "08:50", "total_price_pkr": 129492},
        {"flight_number": "PK276", "airline": "Pakistan International Airlines",
         "depart": "2026-08-14 07:00", "arrive": "08:50", "total_price_pkr": 133896},
    ],
})

HOTELS = json.dumps({
    "city": "Swat", "nights": 11, "rooms": 1, "guests": 4,
    "hotels": [
        {"name": "Hotel Intercon", "stars": 3, "price_per_night_pkr": 15941,
         "total_stay_pkr": 175351, "review_score": 7.4, "breakfast_included": False},
        {"name": "Rock City Resort", "stars": 4, "price_per_night_pkr": 22579,
         "total_stay_pkr": 248369, "review_score": 8.6, "breakfast_included": True},
        {"name": "Swat Serena Hotel", "stars": 5, "price_per_night_pkr": 38920,
         "total_stay_pkr": 428120, "review_score": 9.1, "breakfast_included": True},
    ],
})

TRAINS = json.dumps({
    "passengers": 2, "search_date": "2026-08-14",
    "trains": [
        {"train_name": "Green Line", "train_number": "5-Up",
         "classes": [{"class": "AC Business", "total_price_pkr": 24000},
                     {"class": "Economy", "total_price_pkr": 9000}]},
        {"train_name": "Tezgam Express", "train_number": "7-Up",
         "classes": [{"class": "Economy", "total_price_pkr": 11000}]},
    ],
})

NARAN_HOTELS = json.dumps({
    "city": "Naran", "nights": 3, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "PTDC Motel Naran", "stars": 3, "price_per_night_pkr": 12000,
         "total_stay_pkr": 36000, "breakfast_included": False},
        {"name": "Naran Continental", "stars": 4, "price_per_night_pkr": 19000,
         "total_stay_pkr": 57000, "review_score": 8.2, "breakfast_included": True},
    ],
})

FLIGHT_AND_HOTEL = [("search_flights", FLIGHTS), ("search_hotels", HOTELS)]
TRAIN_AND_HOTEL = [("search_trains", TRAINS), ("search_hotels", NARAN_HOTELS)]


# ── can_build: only a real, complete trip-planner turn qualifies ─────────────

def test_transport_and_hotel_for_a_northern_destination_can_build():
    assert can_build(FLIGHT_AND_HOTEL, "Swat")


def test_an_alias_destination_can_build():
    assert can_build(TRAIN_AND_HOTEL, "Kaghan")      # Kaghan == Naran


@pytest.mark.parametrize("gathered,destination,why", [
    ([("search_flights", FLIGHTS)], "Swat", "transport alone is not a package"),
    ([("search_hotels", HOTELS)], "Swat", "a hotel alone is not a package"),
    (FLIGHT_AND_HOTEL, "Lahore", "not a trip-planner destination"),
    ([], "Swat", "nothing gathered"),
])
def test_incomplete_turns_do_not_build(gathered, destination, why):
    assert not can_build(gathered, destination), why


# ── The gap detector: half a search must not become a parts list ────────────
#
# Searching only flights is exactly what made the Trip Planner behave like the
# flight module — the turn had nothing to combine, so it listed parts. This
# names the gap so the model is pushed to close it instead.

def test_a_flights_only_turn_reports_the_missing_hotel_search():
    missing = missing_for_package([("search_flights", FLIGHTS)], "Swat")
    assert missing == ["hotels in Swat (search_hotels)"]


def test_a_hotels_only_turn_reports_the_missing_transport_search():
    missing = missing_for_package([("search_hotels", HOTELS)], "Swat")
    assert len(missing) == 1
    assert "transport to the hub" in missing[0]


def test_a_complete_turn_reports_nothing_missing():
    assert missing_for_package(FLIGHT_AND_HOTEL, "Swat") == []


def test_a_turn_that_searched_nothing_yet_is_left_alone():
    """Before any search there is no gap to complain about — the model may
    still be gathering trip details."""
    assert missing_for_package([], "Swat") == []


def test_an_ordinary_destination_is_never_pushed_for_a_package():
    """Trip-planner rules apply to northern destinations only; a plain Lahore
    flight search must stay a flight search."""
    assert missing_for_package([("search_flights", FLIGHTS)], "Lahore") == []


def test_the_gap_detector_reports_the_canonical_destination_name():
    missing = missing_for_package([("search_flights", FLIGHTS)], "Kaghan")
    assert missing == ["hotels in Naran (search_hotels)"]


# ── Composition ──────────────────────────────────────────────────────────────

def test_three_packages_are_built_cheapest_first():
    packages = build(FLIGHT_AND_HOTEL, "Swat")
    assert [p.tier for p in packages] == ["Budget", "Standard", "Premium"]
    totals = [p.total_pkr for p in packages]
    assert totals == sorted(totals)


def test_every_total_is_the_real_sum_of_its_own_parts():
    """The whole reason this is code: the arithmetic has to be exact."""
    for pkg in build(FLIGHT_AND_HOTEL, "Swat"):
        assert pkg.transfer is not None
        expected = pkg.transport_pkr + pkg.hotel_pkr + pkg.transfer["fare_pkr"]
        assert pkg.total_pkr == expected


def test_the_budget_package_is_the_cheapest_real_combination():
    budget = build(FLIGHT_AND_HOTEL, "Swat")[0]
    assert budget.transport["flight_number"] == "PK948"      # cheapest flight
    assert budget.hotel["name"] == "Hotel Intercon"          # cheapest hotel
    assert budget.total_pkr == 69256 + 175351 + 20000        # + SUV to Swat


def test_the_transfer_vehicle_follows_party_size_not_tier():
    """Selling a family of four a Sedan to make a tier look cheaper would be
    selling them a car they do not fit in."""
    for pkg in build(FLIGHT_AND_HOTEL, "Swat"):              # 4 passengers
        assert pkg.transfer is not None
        assert pkg.transfer["vehicle"] == "SUV"
    for pkg in build(TRAIN_AND_HOTEL, "Naran"):              # 2 passengers
        assert pkg.transfer is not None
        assert pkg.transfer["vehicle"] == "Sedan"


def test_the_transfer_hub_matches_how_they_are_travelling():
    """Naran's flight hub is Islamabad, its train hub is Rawalpindi — a train
    traveller collected from an airport they never landed at is a driver sent
    to the wrong city."""
    for pkg in build(TRAIN_AND_HOTEL, "Naran"):
        assert pkg.transfer is not None
        assert pkg.transfer["hub"] == "Rawalpindi"
    for pkg in build(FLIGHT_AND_HOTEL, "Swat"):
        assert pkg.transfer is not None
        assert pkg.transfer["hub"] == "Islamabad"


def test_a_train_is_priced_from_its_cheapest_fare_class():
    packages = build(TRAIN_AND_HOTEL, "Naran")
    assert packages[0].transport_pkr == 9000       # Green Line Economy, not AC Business


def test_skardu_packages_carry_no_transfer():
    """Skardu has its own airport — there is no hub leg to sell."""
    skardu_hotels = json.dumps({
        "city": "Skardu", "nights": 3, "guests": 4,
        "hotels": [{"name": "Shangrila Resort", "stars": 4,
                    "price_per_night_pkr": 20000, "total_stay_pkr": 60000}],
    })
    packages = build([("search_flights", FLIGHTS), ("search_hotels", skardu_hotels)], "Skardu")
    assert packages
    for pkg in packages:
        assert pkg.transfer is None
        assert pkg.total_pkr == pkg.transport_pkr + pkg.hotel_pkr


def test_a_single_combination_yields_a_single_package():
    """Fewer real options must mean fewer packages, never a padded list."""
    one_flight = json.dumps({"passengers": 2, "flights": [
        {"flight_number": "PK948", "airline": "PIA", "total_price_pkr": 40000}]})
    one_hotel = json.dumps({"city": "Naran", "nights": 2, "guests": 2, "hotels": [
        {"name": "PTDC Motel Naran", "stars": 3, "total_stay_pkr": 24000}]})
    packages = build([("search_flights", one_flight), ("search_hotels", one_hotel)], "Naran")
    assert len(packages) == 1
    assert packages[0].tier == "Budget"


def test_rows_without_a_usable_price_are_skipped_not_priced_at_zero():
    broken = json.dumps({"passengers": 2, "flights": [
        {"flight_number": "XX1", "airline": "Nowhere Air"},          # no price
        {"flight_number": "PK948", "airline": "PIA", "total_price_pkr": 40000},
    ]})
    one_hotel = json.dumps({"city": "Naran", "nights": 2, "guests": 2, "hotels": [
        {"name": "PTDC Motel Naran", "stars": 3, "total_stay_pkr": 24000}]})
    packages = build([("search_flights", broken), ("search_hotels", one_hotel)], "Naran")
    assert len(packages) == 1
    assert packages[0].transport["flight_number"] == "PK948"


# ── Highlights are copied facts, never inferred ─────────────────────────────

def test_highlights_only_claim_what_the_payload_carries():
    packages = build(FLIGHT_AND_HOTEL, "Swat")
    budget, premium = packages[0], packages[-1]
    assert "Lowest total" in budget.highlights
    # Hotel Intercon has breakfast_included False — must never be claimed.
    assert not any("Breakfast" in h for h in budget.highlights)
    assert any("Breakfast included" == h for h in premium.highlights)
    assert any("5★" in h for h in premium.highlights)


# ── Rendering: a selectable, numbered package list ──────────────────────────

def test_rendered_packages_are_a_numbered_priced_list():
    """The shape the rest of the pipeline recognises as selectable offers —
    see test_offer_list_numbering.py for why that matters."""
    from agents.prompt_builder import _looks_like_offer_list
    text = render(build(FLIGHT_AND_HOTEL, "Swat"), "Swat", budget_pkr=300000)
    assert _looks_like_offer_list(text)
    assert "1. **Budget" in text
    assert "2. **Standard" in text
    assert "3. **Premium" in text


def test_the_rendering_names_the_bookable_components():
    """A pick has to be turnable back into real booking components, so the
    flight number and hotel name must both survive into the text."""
    text = render(build(FLIGHT_AND_HOTEL, "Swat"), "Swat")
    assert "PK948" in text
    assert "Hotel Intercon" in text
    assert "Islamabad → Swat" in text


def test_the_rendering_asks_for_a_package_not_a_flight():
    text = render(build(FLIGHT_AND_HOTEL, "Swat"), "Swat")
    assert "which package" in text.lower()
    assert "one booking" in text.lower()


def test_an_alias_destination_renders_under_its_canonical_name():
    text = render(build(TRAIN_AND_HOTEL, "Kaghan"), "Kaghan")
    assert "Naran" in text


def test_nothing_renders_when_there_are_no_packages():
    assert render([], "Swat", budget_pkr=100000) == ""


# ── The recommendation explains WHY ─────────────────────────────────────────

def test_recommendation_picks_the_most_complete_option_within_budget():
    text = render(build(TRAIN_AND_HOTEL, "Naran"), "Naran", budget_pkr=100000)
    # Every Naran package fits 100k, so the dearest (Premium) is the pick.
    assert "**Premium** is my pick" in text
    assert "spare" in text


def test_recommendation_names_the_shortfall_when_nothing_fits():
    text = render(build(FLIGHT_AND_HOTEL, "Swat"), "Swat", budget_pkr=100000)
    assert "None of these fit" in text
    assert "comes closest" in text
    assert "over by" in text


def test_recommendation_quantifies_how_far_over_each_option_is():
    packages = build(FLIGHT_AND_HOTEL, "Swat")
    text = render(packages, "Swat", budget_pkr=300000)
    over = packages[1].total_pkr - 300000
    assert f"Standard is over by PKR {over:,}" in text


def test_no_budget_still_gives_a_recommendation():
    text = render(build(FLIGHT_AND_HOTEL, "Swat"), "Swat", budget_pkr=None)
    assert "**Budget**" in text
    assert "tell me your budget" in text.lower()


# ── Resolving a pick back into the RIGHT components ──────────────────────────
#
# "Package 2" has to become that package's flight, hotel and car leg. This is
# where a package would otherwise decompose back into parts: the model re-reads
# its own prose and picks a neighbouring row, drops the transfer, or re-prices
# from memory. Parsing our OWN rendered text keeps the pick exact.

def _rendered(gathered=None, destination="Swat", budget=300000):
    return render(build(gathered or FLIGHT_AND_HOTEL, destination), destination, budget_pkr=budget)


def test_a_rendered_package_list_parses_back_into_its_components():
    packages = parse_rendered(_rendered())
    assert set(packages) == {1, 2, 3}
    for pkg in packages.values():
        assert pkg["flight_number"]
        assert pkg["hotel_name"]
        assert pkg["transfer_vehicle"]


def test_each_parsed_package_matches_the_package_that_was_built():
    """The parse must recover exactly what was composed — not a neighbour."""
    built = build(FLIGHT_AND_HOTEL, "Swat")
    parsed = parse_rendered(render(built, "Swat", budget_pkr=300000))
    for number, original in enumerate(built, start=1):
        recovered = parsed[number]
        assert recovered["tier"] == original.tier
        assert recovered["total_pkr"] == original.total_pkr
        assert recovered["transport_pkr"] == original.transport_pkr
        assert recovered["hotel_pkr"] == original.hotel_pkr
        assert recovered["hotel_name"] == original.hotel["name"]
        assert recovered["flight_number"] == original.transport["flight_number"]


def test_the_parsed_totals_still_add_up():
    for pkg in parse_rendered(_rendered()).values():
        assert pkg["transport_pkr"] + pkg["hotel_pkr"] + pkg["transfer_pkr"] == pkg["total_pkr"]


def test_a_train_package_parses_back_as_a_train_not_a_flight():
    packages = parse_rendered(_rendered(TRAIN_AND_HOTEL, "Naran", 200000))
    for pkg in packages.values():
        assert pkg["transport_kind"] == "train"
        assert pkg.get("train_name")
        assert "flight_number" not in pkg


def test_skardu_packages_parse_with_no_transfer():
    gathered = [("search_flights", FLIGHTS), ("search_hotels", json.dumps({
        "city": "Skardu", "nights": 3, "guests": 4,
        "hotels": [{"name": "Shangrila Resort", "stars": 4, "total_stay_pkr": 60000}],
    }))]
    for pkg in parse_rendered(_rendered(gathered, "Skardu", 300000)).values():
        assert "transfer_vehicle" not in pkg


def test_ordinary_prose_parses_as_no_packages():
    assert parse_rendered("Here are some flights:\n1. PIA PK948 — PKR 69,256") == {}
    assert parse_rendered("") == {}


def test_find_rendered_takes_the_most_recent_package_list():
    old = _rendered(TRAIN_AND_HOTEL, "Naran", 200000)
    new = _rendered()
    history = [
        {"role": "assistant", "content": old},
        {"role": "user", "content": "actually let's fly instead"},
        {"role": "assistant", "content": new},
    ]
    assert find_rendered(history)[1]["transport_kind"] == "flight"


def test_find_rendered_ignores_conversations_with_no_package_list():
    assert find_rendered([{"role": "assistant", "content": "Which destination?"}]) == {}
    assert find_rendered(None) == {}


def test_the_selection_instruction_names_every_component_of_the_pick():
    picked = parse_rendered(_rendered())[2]
    text = selection_instruction(picked)
    assert picked["flight_number"] in text
    assert picked["hotel_name"] in text
    assert picked["transfer_vehicle"] in text
    # One checkout, explicitly.
    assert "SAME reply" in text
    assert "book_car" in text          # told NOT to use it for this leg


def test_the_selection_instruction_forbids_a_partial_booking():
    text = selection_instruction(parse_rendered(_rendered())[1])
    assert "only part of it" in text.lower()


def test_the_selection_instruction_omits_the_car_when_there_is_none():
    """Skardu has its own airport — no transfer leg to mention, and none invented."""
    gathered = [("search_flights", FLIGHTS), ("search_hotels", json.dumps({
        "city": "Skardu", "nights": 3, "guests": 4,
        "hotels": [{"name": "Shangrila Resort", "stars": 4, "total_stay_pkr": 60000}],
    }))]
    text = selection_instruction(parse_rendered(_rendered(gathered, "Skardu", 300000))[1])
    assert "transfer_vehicle_type" not in text
    assert "book_car" not in text


# ── Guest score is rendered on the scale its provider actually used ──────────
#
# review_score is not normalised: Google Places rates out of 5 (the source for
# most northern-destination hotels, where TripAdvisor has no coverage), while
# Booking-style feeds and the seeded fallbacks rate out of 10. A hard-coded
# "/10" printed a real 4.3/5 Hunza hotel — an excellent one — as "4.3/10", which
# reads as dire and steers travellers away from the package they should pick.

def _score_line(review_score):
    hotels = json.dumps({
        "city": "Hunza", "nights": 3, "rooms": 1, "guests": 2,
        "hotels": [{"name": "Old Hunza Inn", "stars": 4.3,
                    "price_per_night_pkr": 12000, "total_stay_pkr": 36000,
                    "review_score": review_score, "breakfast_included": False}],
    })
    packages = build([("search_flights", FLIGHTS), ("search_hotels", hotels)], "Hunza")
    return render(packages, "Hunza")


def test_a_five_point_guest_score_is_not_printed_out_of_ten():
    assert "Guest score 4.3/5" in _score_line(4.3)
    assert "4.3/10" not in _score_line(4.3)


def test_a_ten_point_guest_score_is_still_printed_out_of_ten():
    assert "Guest score 8.6/10" in _score_line(8.6)


def test_a_missing_guest_score_is_not_rendered_at_all():
    assert "Guest score" not in _score_line(None)
