"""
A standalone book_car ride between two cities that name no known
hub<->northern-destination route (northern_routes.price_for_route) used to
fall straight through to the flat in-city rate (Sedan 3,000 / SUV 6,000 /
Van 9,000) — so a genuine long-distance trip like Karachi -> Skardu
(~1,900km) priced the same as a ride across town. car_service.estimate_fare
now tries a per-km distance estimate (reusing weather_service.CITY_COORDS)
before falling back to the flat rate, closing that gap for any pair of
addresses that actually name two different known cities.
"""
from services.car_service import estimate_fare


def test_a_long_haul_ride_between_two_known_cities_prices_by_distance():
    fare = estimate_fare("SUV", "R 130 Sector 11C/2, Karachi", "Shangrila Resort Skardu")
    assert fare > 6000
    # Karachi -> Skardu is roughly 1,900km as the crow flies; a PKR 40/km SUV
    # rate should land somewhere in the tens of thousands, nowhere near the
    # flat in-city rate.
    assert fare > 50000


def test_an_ordinary_in_city_ride_still_uses_the_flat_rate():
    assert estimate_fare("Sedan", "DHA Phase 5, Karachi", "Jinnah International Airport, Karachi") == 3000


def test_a_ride_within_the_same_named_city_stays_flat():
    assert estimate_fare("Sedan", "Karachi", "Karachi") == 3000


def test_an_unrecognised_address_stays_flat():
    assert estimate_fare("SUV", "some street", "another street") == 6000


def test_a_northern_hub_route_still_wins_over_the_distance_fallback():
    """price_for_route is checked first — a sourced/estimated hub fare must
    never be shadowed by the generic per-km estimate."""
    assert estimate_fare("Sedan", "Gilgit", "Hunza") == 10000


def test_bigger_vehicles_cost_more_per_km():
    sedan = estimate_fare("Sedan", "Karachi", "Skardu")
    suv = estimate_fare("SUV", "Karachi", "Skardu")
    van = estimate_fare("Van", "Karachi", "Skardu")
    assert sedan < suv < van


def test_called_with_no_addresses_is_unaffected():
    assert estimate_fare("SUV") == 6000
