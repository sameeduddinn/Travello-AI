"""
A northern destination named by an ALIAS must behave exactly as its canonical
name does — everywhere.

The bug this pins: "Plan trip for Naran and Kaghan" derives a trip destination
of "Kaghan", but NORTHERN_DESTINATIONS is keyed by canonical name only, so
hub_options_for("Kaghan") returned None. Both Trip Planner safety gates bail
out early on exactly that None — so a partial itinerary could reach payment
again, and a hub->destination car leg could fall back to the flat in-city rate
(PKR 3,000 instead of PKR 18,000). Neither failed loudly; both simply stopped
applying.

Affected aliases are the app's own vocabulary (CITY_ALIASES, which already
drives hotel search): kaghan, naran kaghan, karimabad, aliabad, mingora,
skardo.
"""
import pytest

from agents.agent_tools import (
    _add_transfer_fare,
    get_transfer_error,
    get_trip_planner_incomplete_error,
)
from agents.conversation_state import derive_state
from services.northern_routes import (
    canonical_destination,
    estimate_hub_car_fare,
    hub_options_for,
    names_destination,
    price_for_route,
)

FLIGHT_TO_ISLAMABAD = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Islamabad",
    "travel_date": "2026-08-14", "flight_number": "PK948", "total_price_pkr": 69256,
}


# ── Canonicalisation ─────────────────────────────────────────────────────────

@pytest.mark.parametrize("alias,canonical", [
    ("Kaghan", "Naran"),
    ("naran kaghan", "Naran"),
    ("Karimabad", "Hunza"),
    ("Aliabad", "Hunza"),
    ("Mingora", "Swat"),
    ("Skardo", "Skardu"),
    ("Naran", "Naran"),          # already canonical
])
def test_aliases_resolve_to_their_canonical_destination(alias, canonical):
    assert canonical_destination(alias) == canonical


def test_an_ordinary_city_is_left_alone_and_has_no_hubs():
    assert canonical_destination("Lahore") == "Lahore"
    assert hub_options_for("Lahore") is None


def test_hub_lookup_works_through_an_alias():
    assert hub_options_for("Kaghan") == hub_options_for("Naran")
    assert hub_options_for("Karimabad") == hub_options_for("Hunza")


# ── The two gates stay armed ─────────────────────────────────────────────────

@pytest.mark.parametrize("destination", ["Naran", "Kaghan", "naran kaghan", "Karimabad", "Mingora"])
def test_the_completeness_gate_still_fires_for_an_alias(destination):
    """A flight alone is never a complete northern package, whichever form
    of the destination name the traveller happened to use."""
    err = get_trip_planner_incomplete_error([FLIGHT_TO_ISLAMABAD], None, destination)
    assert err is not None, f"gate silently disabled for {destination!r}"


@pytest.mark.parametrize("trip_destination,dropoff", [
    ("Naran", "Naran"),
    ("Kaghan", "Naran"),      # derived as alias, dropoff canonical
    ("Naran", "Kaghan"),      # derived canonical, dropoff as alias
    ("Kaghan", "Kaghan"),
])
def test_the_transfer_gate_accepts_either_form_of_the_same_place(trip_destination, dropoff):
    err = get_transfer_error(
        {"transfer_vehicle_type": "Sedan",
         "transfer_pickup_location": "Islamabad International Airport",
         "transfer_dropoff_location": dropoff},
        user_texts=[f"plan a trip to {trip_destination}, drop me at {dropoff}"],
        trip_destination=trip_destination,
    )
    assert err is None, f"correct booking wrongly blocked: {trip_destination} / {dropoff}"


def test_the_transfer_gate_still_blocks_a_genuinely_different_dropoff():
    """Alias-awareness must not become "accept anything" — a real mismatch
    still has to block, or the flat-rate undercharge returns."""
    err = get_transfer_error(
        {"transfer_vehicle_type": "Sedan",
         "transfer_pickup_location": "Islamabad International Airport",
         "transfer_dropoff_location": "Murree"},
        user_texts=["plan a trip to Kaghan", "actually drop me at Murree"],
        trip_destination="Kaghan",
    )
    assert err is not None


def test_names_destination_does_not_match_an_unrelated_place():
    assert names_destination("Kaghan", "Naran")
    assert names_destination("Karimabad", "Hunza")
    assert not names_destination("Murree", "Naran")
    assert not names_destination("Hunza", "Naran")


# ── The fare itself ──────────────────────────────────────────────────────────

@pytest.mark.parametrize("pickup,dropoff,expected", [
    ("Islamabad International Airport", "Naran", 18000),
    ("Islamabad International Airport", "Kaghan", 18000),
    ("Islamabad International Airport", "Mingora", 15000),   # Swat
    ("Gilgit Airport", "Karimabad", 10000),                   # Hunza
])
def test_route_fares_price_through_an_alias(pickup, dropoff, expected):
    assert price_for_route(pickup, dropoff, "Sedan") == expected


def test_an_alias_dropoff_is_charged_the_route_fare_inside_the_package():
    """End to end: the flat in-city rate is PKR 3,000 — an alias dropoff must
    not quietly fall back to it on a real ~190km hub leg."""
    out = _add_transfer_fare({
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "Kaghan",
        "total_price_pkr": 69256,
    })
    assert out["transfer_pkr"] == 18000
    assert out["total_price_pkr"] == 69256 + 18000


def test_the_budget_estimate_works_through_an_alias():
    assert estimate_hub_car_fare("Kaghan") == estimate_hub_car_fare("Naran")


def test_an_ordinary_transfer_is_untouched_by_alias_handling():
    """Regression guard: a normal in-city airport transfer still flat-rates."""
    out = _add_transfer_fare({
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "House 12, Block A, DHA Phase 5, Karachi",
        "total_price_pkr": 20000,
    })
    assert out["transfer_pkr"] == 3000


# ── Derived trip state: two names for one place is not a route ───────────────

def test_naming_a_place_twice_by_alias_is_not_read_as_a_route():
    """
    "Plan trip for Naran and Kaghan" used to set origin=Naran,
    destination=Kaghan — both ends of the same valley, from a message that
    named no origin at all.
    """
    state = derive_state([], "Plan trip for Naran and Kaghan")
    assert state.origin == ""
    assert state.destination == "Naran"


@pytest.mark.parametrize("message,expected", [
    ("Plan a trip to Kaghan", "Naran"),
    ("Plan trip for Naran and Kaghan", "Naran"),
    ("trip to Karimabad", "Hunza"),
    ("a hotel in Mingora", "Swat"),
])
def test_the_derived_destination_is_canonical(message, expected):
    """So the gates receive the same name whichever form was typed."""
    assert derive_state([], message).destination == expected


def test_a_genuine_two_city_route_is_still_read_correctly():
    """Regression guard — collapsing aliases must not collapse real routes."""
    state = derive_state([], "I want to go from Lahore to Karachi")
    assert (state.origin, state.destination) == ("Lahore", "Karachi")


def test_a_preposition_route_into_a_northern_destination_still_works():
    state = derive_state([], "trip to Naran from Karachi")
    assert (state.origin, state.destination) == ("Karachi", "Naran")
