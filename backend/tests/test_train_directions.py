"""
Trains run both ways.

Every route in _TRAINS is written once, south-to-north, and _trains_for_route
used to require route.index(origin) < route.index(dest). That made the entire
southbound network invisible:

    Karachi -> Lahore      11 trains
    Lahore  -> Karachi      0 trains
    Islamabad -> Lahore     0 trains

The user hit it by asking for a train from Islamabad to Lahore — an entirely
ordinary request — and got "NO AVAILABILITY". It also meant no return journey
was bookable anywhere, which matters because Pakistan Railways sells a return
as a second one-way ticket; there is no round-trip product to fall back on.

The train numbers say both directions exist: "7-Up/8-Dn" is Pakistan Railways'
notation for the two directions of one service.

No network: the train service is synthetic data with deterministic seeds.
"""
from datetime import date

import pytest

from services import train_service as ts

WHEN = date(2026, 8, 2)

# Stations on the main corridor, in the stored (south-to-north) order.
CORRIDOR = ["Karachi", "Multan", "Lahore", "Rawalpindi", "Islamabad", "Peshawar"]


def _count(origin, dest):
    return len(ts.search_trains(origin, dest, WHEN, 2).trains)


@pytest.mark.parametrize("origin,dest", [
    ("Islamabad", "Lahore"),      # the reported case
    ("Lahore", "Karachi"),
    ("Peshawar", "Lahore"),
    ("Rawalpindi", "Multan"),
    ("Multan", "Karachi"),
])
def test_southbound_journeys_return_trains(origin, dest):
    assert _count(origin, dest) > 0


@pytest.mark.parametrize("origin,dest", [
    ("Karachi", "Lahore"),
    ("Lahore", "Islamabad"),
    ("Lahore", "Peshawar"),
    ("Multan", "Rawalpindi"),
])
def test_northbound_journeys_are_unchanged(origin, dest):
    """The fix may only ADD results — it must not disturb what already worked."""
    assert _count(origin, dest) > 0


def test_every_pair_on_the_corridor_works_both_ways():
    missing = [
        (a, b)
        for i, a in enumerate(CORRIDOR)
        for b in CORRIDOR[i + 1:]
        if not (_count(a, b) and _count(b, a))
    ]
    assert not missing, f"no service in at least one direction for: {missing}"


def test_a_direction_returns_the_same_trains_as_its_reverse():
    out = {t.train_name for t in ts.search_trains("Karachi", "Lahore", WHEN, 2).trains}
    back = {t.train_name for t in ts.search_trains("Lahore", "Karachi", WHEN, 2).trains}
    assert out == back


@pytest.mark.parametrize("origin,dest", [
    ("Lahore", "Islamabad"),
    ("Karachi", "Lahore"),
    ("Multan", "Rawalpindi"),
])
def test_the_same_leg_takes_the_same_time_in_both_directions(origin, dest):
    """
    The Up timetable is the Dn one mirrored end to end, so a leg's duration is
    identical either way. Getting this wrong produced a departure at hour 30
    arriving at hour 0 — a negative journey.
    """
    there = ts.search_trains(origin, dest, WHEN, 2).trains
    back = {t.train_name: t for t in ts.search_trains(dest, origin, WHEN, 2).trains}
    for t in there:
        assert t.duration == back[t.train_name].duration


@pytest.mark.parametrize("origin,dest", [
    ("Lahore", "Islamabad"),
    ("Karachi", "Lahore"),
])
def test_the_same_rails_cost_the_same_either_way(origin, dest):
    """
    Fares are distance-based, so direction cannot change them. Only the ±5%
    deterministic jitter differs, because it is seeded on origin/destination.
    """
    there = ts.search_trains(origin, dest, WHEN, 2).trains
    back = {t.train_name: t for t in ts.search_trains(dest, origin, WHEN, 2).trains}
    for t in there:
        mirrored = {c.class_name: c.price_pkr for c in back[t.train_name].classes}
        for c in t.classes:
            assert c.price_pkr > 0
            assert abs(c.price_pkr - mirrored[c.class_name]) / c.price_pkr < 0.11


def test_no_journey_arrives_before_it_departs():
    for origin in CORRIDOR:
        for dest in CORRIDOR:
            if origin == dest:
                continue
            for t in ts.search_trains(origin, dest, WHEN, 1).trains:
                assert t.arrival_at > t.departure_at, f"{origin}->{dest} {t.train_name}"


def test_a_station_cannot_travel_to_itself():
    assert _count("Lahore", "Lahore") == 0


def test_a_route_that_genuinely_has_no_rail_service_still_returns_nothing():
    """
    The fix widens which ROUTES match, not which places have rail. Skardu is
    bus-only, and saying so honestly is the whole point of the empty result.
    """
    assert _count("Lahore", "Skardu") == 0
    assert _count("Skardu", "Lahore") == 0
