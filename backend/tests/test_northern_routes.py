"""
Unit tests for the northern-destination hub data (services/northern_routes.py)
and the route-aware car fare it feeds (services/car_service.py).
"""
from services.northern_routes import (
    hub_options_for,
    price_for_route,
    estimate_hub_car_fare,
)
from services.car_service import estimate_fare


# ── hub_options_for ───────────────────────────────────────────────────────────

def test_naran_has_two_hub_options():
    hubs = hub_options_for("Naran")
    assert hubs is not None
    assert {h.hub_city for h in hubs} == {"Islamabad", "Rawalpindi"}
    assert {h.mode for h in hubs} == {"flight", "train"}


def test_hunza_has_one_hub_option():
    hubs = hub_options_for("Hunza")
    assert hubs is not None
    assert len(hubs) == 1
    assert hubs[0].hub_city == "Gilgit"
    assert hubs[0].mode == "flight"


def test_swat_has_two_hub_options():
    hubs = hub_options_for("Swat")
    assert hubs is not None
    assert {h.hub_city for h in hubs} == {"Islamabad", "Rawalpindi"}


def test_skardu_has_no_hub_substitution_but_is_known():
    """Skardu already has its own airport — [] means 'known, no substitution',
    distinct from None ('not one of these four destinations at all')."""
    assert hub_options_for("Skardu") == []


def test_unrelated_city_is_not_a_northern_destination():
    assert hub_options_for("Karachi") is None
    assert hub_options_for("") is None


def test_hub_lookup_is_case_and_whitespace_insensitive():
    assert hub_options_for("  naran ") == hub_options_for("Naran")
    assert hub_options_for("HUNZA") == hub_options_for("Hunza")


# ── price_for_route ────────────────────────────────────────────────────────────

def test_price_for_route_matches_free_text_addresses():
    assert price_for_route("Islamabad International Airport", "Naran Bazar, KPK", "Sedan") == 18000
    assert price_for_route("Gilgit Airport", "Karimabad, Hunza", "SUV") == 9500


def test_price_for_route_returns_none_for_unrelated_addresses():
    assert price_for_route("DHA Phase 5, Karachi", "Jinnah International Airport", "Sedan") is None


def test_price_for_route_ordering_is_sedan_suv_van():
    fares = {v: price_for_route("Islamabad", "Naran", v) for v in ("Sedan", "SUV", "Van")}
    assert all(fare is not None for fare in fares.values())
    assert fares["Sedan"] is not None and fares["SUV"] is not None and fares["Van"] is not None
    assert fares["Sedan"] < fares["SUV"] < fares["Van"]


# ── estimate_hub_car_fare ──────────────────────────────────────────────────────

def test_estimate_hub_car_fare_picks_the_cheapest_hub():
    result = estimate_hub_car_fare("Naran")
    assert result is not None
    fare, label = result
    assert fare is not None
    assert fare == 18000  # Islamabad and Rawalpindi routes are priced the same here
    assert "Naran" in label


def test_estimate_hub_car_fare_none_for_skardu_and_unknown_cities():
    assert estimate_hub_car_fare("Skardu") is None
    assert estimate_hub_car_fare("Karachi") is None
    assert estimate_hub_car_fare("") is None


# ── car_service.estimate_fare (route-aware, backward compatible) ─────────────

def test_estimate_fare_uses_the_routed_price_for_a_known_hub_route():
    assert estimate_fare("Sedan", "Islamabad Airport", "Naran") == 18000
    assert estimate_fare("Van", "Gilgit Airport", "Hunza") == 12000


def test_estimate_fare_falls_back_to_the_flat_rate_for_ordinary_rides():
    assert estimate_fare("Sedan", "DHA Phase 5", "Jinnah International Airport") == 800
    assert estimate_fare("SUV") == 1200          # no addresses at all — old call shape
    assert estimate_fare("Van", "", "") == 1500  # empty addresses behave the same
