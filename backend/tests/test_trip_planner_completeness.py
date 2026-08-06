"""
Unit tests for get_trip_planner_incomplete_error — the deterministic gate that
stops a Trip Planner session (a recognised northern destination) from
finalizing or charging a partial itinerary. Transport, hotel, and — for a
hub-less destination — the car transfer must ALL be prepared together; a
single verified leg must never reach payment on its own just because it
happened to satisfy the ordinary "how many pieces did the user pick" count.

The orchestration-level regression (the exact bug: a single flight pick for a
Hunza trip becoming its own Booking Summary and Pay button) lives in
test_northern_trip_planning.py, which already drives the real
process_message_agentic loop with a scripted model.
"""
from agents.agent_tools import get_trip_planner_incomplete_error

FLIGHT_TO_GILGIT = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Gilgit",
    "travel_date": "2026-08-14", "flight_number": "PK379", "total_price_pkr": 64995,
}
FLIGHT_TO_GILGIT_WITH_TRANSFER = {
    **FLIGHT_TO_GILGIT,
    "transfer_vehicle_type": "Sedan",
    "transfer_pickup_location": "Gilgit Airport",
    "transfer_dropoff_location": "Hunza",
}
HUNZA_HOTEL = {
    "booking_type": "hotel", "hotel_name": "Hunza Serena Inn",
    "check_in": "2026-08-14", "check_out": "2026-08-28",
}
FLIGHT_TO_SKARDU = {
    "booking_type": "flight", "origin": "Islamabad", "destination": "Skardu",
    "travel_date": "2026-08-14", "flight_number": "PK451", "total_price_pkr": 30000,
}
SKARDU_HOTEL = {
    "booking_type": "hotel", "hotel_name": "Shangrila Resort",
    "check_in": "2026-08-14", "check_out": "2026-08-17",
}
FLIGHT_TO_LAHORE = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Lahore",
    "travel_date": "2026-08-14", "flight_number": "PK301", "total_price_pkr": 21000,
}


def test_no_error_outside_trip_planner_mode():
    """An ordinary (non-northern) destination is never gated by this rule."""
    assert get_trip_planner_incomplete_error([FLIGHT_TO_LAHORE], None, "Lahore") is None


def test_no_error_when_nothing_was_verified_this_turn():
    assert get_trip_planner_incomplete_error([], None, "Hunza") is None


def test_single_flight_only_is_incomplete_for_a_hub_less_destination():
    """The exact bug: a Hunza flight alone, no hotel, no transfer even attempted."""
    err = get_trip_planner_incomplete_error([FLIGHT_TO_GILGIT], None, "Hunza")
    assert err is not None
    assert "a hotel" in err["missing"]
    assert "the car transfer to the destination" in err["missing"]


def test_flight_and_hotel_without_a_transfer_is_incomplete_for_hunza():
    """Naran/Hunza/Swat have no airport of their own — the car leg is how the
    traveller actually completes the trip, not an optional extra."""
    err = get_trip_planner_incomplete_error(
        [FLIGHT_TO_GILGIT, HUNZA_HOTEL], None, "Hunza",
    )
    assert err is not None
    assert err["missing"] == ["the car transfer to the destination"]


def test_flight_hotel_and_transfer_together_is_complete_for_hunza():
    err = get_trip_planner_incomplete_error(
        [FLIGHT_TO_GILGIT_WITH_TRANSFER, HUNZA_HOTEL], None, "Hunza",
    )
    assert err is None


def test_skardu_does_not_require_a_transfer():
    """Skardu already has its own airport — hub_options_for returns [], so the
    car-transfer requirement never applies, only transport + hotel."""
    err = get_trip_planner_incomplete_error(
        [FLIGHT_TO_SKARDU, SKARDU_HOTEL], None, "Skardu",
    )
    assert err is None


def test_skardu_flight_alone_is_still_incomplete_without_a_hotel():
    err = get_trip_planner_incomplete_error([FLIGHT_TO_SKARDU], None, "Skardu")
    assert err is not None
    assert err["missing"] == ["a hotel"]


def test_a_component_already_paid_for_earlier_counts_toward_completeness():
    """
    A flight confirmed and paid for earlier in this SAME conversation must not
    be demanded again — only the still-missing piece(s) matter. Reuses
    confirmed_components' own summary+confirmation markers, so this test
    doubles as a check that get_trip_planner_incomplete_error is actually
    reading them, not just step_components.
    """
    history = [
        {"role": "assistant", "content": (
            "**Booking Summary**\n✈️ **Flight:** Islamabad → Skardu 📅 **Date:** "
            "2026-08-14\n💰 **Total:** PKR 30,000"
        )},
        {"role": "user", "content": "2"},
        {"role": "assistant", "content": "Booking confirmed! **PNR:** ABC123"},
    ]
    err = get_trip_planner_incomplete_error([SKARDU_HOTEL], history, "Skardu")
    assert err is None
