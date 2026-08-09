"""
What the traveller reads has to add up, and has to be readable.

Two presentation defects, both found by reading real output rather than by a
failing test. Neither ever affected a charge — total_price_pkr, the package
total and the payment amount are untouched by everything here.

1. A component line showed its TRANSFER-INCLUSIVE total beside a per-person
   breakdown that (correctly) excluded the transfer:

       Flight: Karachi -> Gilgit — PKR 396,348  (PKR 96,712 per person x 4)

   96,712 x 4 = 386,848, not 396,348. The missing 9,500 was the car transfer,
   listed on its own line below — so the figures were individually right and
   visibly contradictory, on the screen immediately before a payment button.

2. Flight rows showed AIRPORT codes, because that is what the search API
   returns: "KHI -> GIL". Reading your own itinerary shouldn't require knowing
   IATA.
"""
import json

import pytest

from agents import trip_selection as ts
from agents.booking_agent import (
    _component_amount,
    _price_breakdown,
    format_booking_summary,
    format_package_summary,
)

FLIGHT_WITH_TRANSFER = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Gilgit",
    "travel_date": "2026-08-14", "adults": 4,
    "total_price_pkr": 396348,          # 386,848 fare + 9,500 transfer
    "transfer_pkr": 9500, "transfer_vehicle_type": "SUV",
    "transfer_pickup_location": "Gilgit Airport", "transfer_dropoff_location": "Hunza",
}
HOTEL = {
    "booking_type": "hotel", "hotel_name": "Tourist Cottage Hunza",
    "destination": "Hunza", "check_in": "2026-08-14", "check_out": "2026-08-25",
    "rooms": 1, "total_price_pkr": 201509,
}
PACKAGE = {
    "booking_type": "package", "total_price_pkr": 597857,
    "components": [FLIGHT_WITH_TRANSFER, HOTEL],
}


# ── The component amount matches its own breakdown ───────────────────────────

def test_a_flight_component_shows_the_fare_its_breakdown_multiplies_out_to():
    assert _component_amount(FLIGHT_WITH_TRANSFER) == 386848
    assert 96712 * 4 == 386848
    line = [l for l in format_package_summary(PACKAGE).splitlines()
            if "**Flight:**" in l][0]
    assert "PKR 386,848" in line
    assert "PKR 96,712 per person × 4 passengers" in line
    assert "396,348" not in line


def test_the_transfer_is_shown_separately_with_its_own_fare():
    line = [l for l in format_package_summary(PACKAGE).splitlines()
            if "Car transfer" in l][0]
    assert "SUV" in line and "PKR 9,500" in line
    assert "Gilgit Airport → Hunza" in line


def test_the_displayed_component_amounts_sum_to_the_displayed_package_total():
    """The whole point: what's on screen adds up."""
    text = format_package_summary(PACKAGE)
    flight = _component_amount(FLIGHT_WITH_TRANSFER)
    transfer = FLIGHT_WITH_TRANSFER["transfer_pkr"]
    hotel = HOTEL["total_price_pkr"]
    assert flight + transfer + hotel == PACKAGE["total_price_pkr"]
    for shown in (flight, transfer, hotel, PACKAGE["total_price_pkr"]):
        assert f"PKR {shown:,}" in text


def test_a_component_without_a_transfer_is_displayed_exactly_as_before():
    assert _component_amount(HOTEL) == HOTEL["total_price_pkr"]
    line = [l for l in format_package_summary(PACKAGE).splitlines()
            if "**Hotel:**" in l][0]
    assert "PKR 201,509" in line


# ── A single booking's "Total" DOES include the transfer, and says so ────────

def test_a_single_booking_total_names_the_transfer_inside_it():
    line = [l for l in format_booking_summary(FLIGHT_WITH_TRANSFER).splitlines()
            if "Total" in l][0]
    assert "PKR 396,348" in line
    assert "PKR 96,712 per person × 4 passengers + PKR 9,500 transfer" in line


def test_the_breakdown_omits_the_transfer_clause_when_there_isnt_one():
    plain = {k: v for k, v in FLIGHT_WITH_TRANSFER.items()
             if not k.startswith("transfer")}
    plain["total_price_pkr"] = 386848
    assert _price_breakdown(plain, transfer_in_total=True) == (
        "PKR 96,712 per person × 4 passengers")


def test_a_component_breakdown_never_appends_the_transfer_clause():
    """It sits beside a transfer-EXCLUSIVE amount, so naming it would re-break it."""
    assert "transfer" not in (_price_breakdown(FLIGHT_WITH_TRANSFER) or "")


# ── Nothing that is charged, stored or summed changed ────────────────────────

def test_the_underlying_totals_are_untouched_by_rendering():
    before = json.dumps(PACKAGE, sort_keys=True)
    format_package_summary(PACKAGE)
    format_booking_summary(FLIGHT_WITH_TRANSFER)
    assert json.dumps(PACKAGE, sort_keys=True) == before


def test_the_payment_amount_still_comes_from_the_component_totals():
    """What gets charged is the sum of total_price_pkr — transfer included."""
    charged = sum(c["total_price_pkr"] for c in PACKAGE["components"])
    assert charged == 597857 == PACKAGE["total_price_pkr"]
    assert FLIGHT_WITH_TRANSFER["total_price_pkr"] == 396348   # still fare + transfer


def test_the_package_total_line_is_unchanged():
    assert "**Package total: PKR 597,857**" in format_package_summary(PACKAGE)


# ── Route labels ─────────────────────────────────────────────────────────────

FLIGHTS_IATA = json.dumps({
    "passengers": 2,
    "flights": [{"flight_number": "PK605", "airline": "PIA", "from": "KHI",
                 "to": "GIL", "depart": "2026-09-10 07:00", "arrive": "08:46",
                 "cabin": "ECONOMY", "total_price_pkr": 85120}],
})
HOTELS = json.dumps({
    "city": "Hunza", "nights": 3, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Old Hunza Inn", "stars": 4, "price_per_night_pkr": 9000,
                "total_stay_pkr": 27000}],
})


def _options():
    return ts.build_options(
        [("search_flights", FLIGHTS_IATA), ("search_hotels", HOTELS)], "Hunza")


def test_a_flight_row_shows_city_names_not_airport_codes():
    row = [l for l in ts.render_options(_options()).splitlines() if l.startswith("1. ")][0]
    assert "Karachi → Gilgit" in row
    assert "KHI" not in row and "GIL" not in row


def test_the_trip_plan_shows_city_names_too():
    options = ts.parse_options(ts.render_options(_options()))
    picks = {"transport": 1, "hotel": 1, "transfer": 1}
    plan = ts.build_plan(options, picks)
    assert plan is not None
    text = ts.render_plan(plan, options, picks, "Hunza")
    assert "Karachi → Gilgit" in text
    assert "KHI" not in text


def test_the_raw_search_payload_keeps_its_airport_codes():
    """Display-only: nothing booked, priced or emailed reads the rendered text."""
    raw = _options()["transport"][0]["row"]
    assert raw["from"] == "KHI" and raw["to"] == "GIL"


def test_city_names_survive_the_render_parse_round_trip():
    back = ts.parse_options(ts.render_options(_options()))
    assert back["transport"][0]["origin"] == "Karachi"
    assert back["transport"][0]["destination"] == "Gilgit"


def test_an_unmapped_place_is_shown_as_given_rather_than_dropped():
    """A code we don't know must not become blank — show whatever came back."""
    unknown = json.dumps({"passengers": 2, "flights": [
        {"flight_number": "XY1", "airline": "Test", "from": "ZZZ", "to": "GIL",
         "depart": "2026-09-10 07:00", "arrive": "08:46", "cabin": "ECONOMY",
         "total_price_pkr": 50000}]})
    options = ts.build_options(
        [("search_flights", unknown), ("search_hotels", HOTELS)], "Hunza")
    assert options["transport"][0]["origin"] == "ZZZ"
    assert options["transport"][0]["destination"] == "Gilgit"


@pytest.mark.parametrize("code,city", [
    ("KHI", "Karachi"), ("LHE", "Lahore"), ("ISB", "Islamabad"),
    ("GIL", "Gilgit"), ("SKD", "Skardu"),
])
def test_every_airport_the_app_serves_maps_to_its_city(code, city):
    assert ts._place(code) == city


def test_a_city_name_that_is_already_a_city_name_is_left_alone():
    assert ts._place("Karachi") == "Karachi"
    assert ts._place("") == ""
