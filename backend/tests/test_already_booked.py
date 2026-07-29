"""
A booking that has already been PAID FOR must never be proposed again.

The transcript this file exists to prevent, observed on-device:

    ... flight Karachi -> Lahore, 7 Aug, booked, PNR 78C78D, PKR 45,783 paid
    user:  "now i want driver at lahore airport"
    agent: Booking Summary
           Flight: Karachi -> Lahore  Date: 2026-08-07  Airline: AirSial
           Car transfer: Sedan (PKR 800) - Lahore Airport
           Total: PKR 46,583
           Next, tap Add Passenger Details ...

That total contains the fare the traveller had just paid. Tapping through would
have booked the same flight twice and charged for it twice. The correct answer
was a standalone car booking: one confirm tap, no passenger form, no payment.

Two independent defences are tested here, because the first is a routing
heuristic and the second is the one that has to hold when routing is wrong:

  A. a confirmation retires the offer list it came from, so the follow-up is
     routed to book_car instead of prepare_booking;
  B. prepare_booking refuses a component this conversation already paid for,
     whatever put it there.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma
from agents.agent_tools import confirmed_components, get_already_booked_error
from agents.prompt_builder import select_tool_names


# ── The transcript, as the backend actually stores it ────────────────────────
# The summary and the confirmation are both produced by our own writers -
# format_booking_summary here, and the Flutter client's milestone message,
# which is written back into the conversation by ApiClient.saveAgentNote.

SUMMARY = (
    "**Booking Summary**\n\n"
    "✈️  **Flight:** Karachi → Lahore\n"
    "\U0001f4c5  **Date:** 2026-08-07\n"
    "\U0001f6eb  **Airline:** AirSial\n"
    "\U0001f4ba  **Class:** Business\n"
    "\U0001f465  **Passengers:** 1 adult(s)\n\n"
    "\U0001f4b0  **Total:** PKR 45,783\n\n"
    "Next, tap **Add Passenger Details** to fill in traveler information."
)
CONFIRMED = (
    "✅ **Booking Confirmed!**\n\n"
    "**PNR:** 78C78D\n**Amount Paid:** PKR 45783\n\n"
    "A confirmation email has been sent to you."
)
OFFER_LIST = (
    "1. **Airblue PA733** · 06:00 → 07:25 — **PKR 37,761**\n"
    "2. **Pakistan International Airlines PK160** · 06:00 → 07:25 — **PKR 51,212**\n"
    "6. **AirSial ER204** · 09:30 → 10:55 — **PKR 45,783**\n\n"
    "Just tell me the number of the one you want and I'll set it up."
)

PAID_FLIGHT_HISTORY = [
    {"role": "user", "content": "I want to book flight for Lahore"},
    {"role": "assistant", "content": "You're flying from Karachi to Lahore. For how many people?"},
    {"role": "user", "content": "for 1 people and on 7 august no budget but i want business class flight"},
    {"role": "assistant", "content": "Here are some Business class flight options..."},
    {"role": "user", "content": "ER204"},
    {"role": "assistant", "content": OFFER_LIST},
    {"role": "user", "content": "6"},
    {"role": "assistant", "content": SUMMARY},
    {"role": "assistant", "content": "✅ Passenger details saved for 1 traveler(s). Seats: E13"},
    {"role": "assistant", "content": CONFIRMED},
]

PAID_FLIGHT = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Lahore",
    "travel_date": "2026-08-07", "flight_number": "ER204", "adults": 1,
    "cabin_class": "BUSINESS", "total_price_pkr": 45783,
}


# ── A · a confirmation retires the offers it came from ───────────────────────

def test_the_car_follow_up_is_routed_to_a_standalone_ride():
    """
    The bug, at the routing layer. The numbered list was still inside the
    six-message lookback, so prepare_booking shipped AND the standalone-car
    rule that would have removed it was suppressed.
    """
    tools = select_tool_names("now i want driver at lahore airport", PAID_FLIGHT_HISTORY)
    assert sorted(tools) == ["book_car"], tools


@pytest.mark.parametrize("message", [
    "now i want a hotel in lahore for 2 nights",
    "add a return flight for 10 august",
    "i also need a train to islamabad after this",
])
def test_no_follow_up_reopens_the_paid_booking_for_checkout(message):
    """
    The same defect reached every "and now also..." follow-up, not just the car
    one - and the hotel variant is the dangerous one, because the package
    builder is designed to combine components into a single charge.
    """
    assert "prepare_booking" not in select_tool_names(message, PAID_FLIGHT_HISTORY)


def test_offers_are_still_live_before_payment():
    """
    The guard must not fire early. Between the summary and the payment there is
    no confirmation yet, so the pick is still a pick and prepare_booking must
    still ship - otherwise the normal booking flow breaks.
    """
    pending = PAID_FLIGHT_HISTORY[:8]          # ...offer list, "6", summary
    assert "prepare_booking" in select_tool_names("yes go ahead", pending)


# ── B · the gate: never re-prepare something already paid for ────────────────

def test_the_paid_flight_is_parsed_out_of_the_confirmed_summary():
    assert confirmed_components(PAID_FLIGHT_HISTORY) == [{
        "booking_type": "flight", "origin": "Karachi",
        "destination": "Lahore", "travel_date": "2026-08-07",
    }]


def test_re_preparing_the_paid_flight_is_refused():
    err = get_already_booked_error(PAID_FLIGHT, PAID_FLIGHT_HISTORY)
    assert err and err["error"] == "already_booked"
    assert "book_car" in err["instruction"]


def test_a_summary_that_was_never_paid_does_not_block():
    """A booking abandoned at the payment screen is still bookable."""
    unpaid = [m for m in PAID_FLIGHT_HISTORY if m["content"] != CONFIRMED]
    assert get_already_booked_error(PAID_FLIGHT, unpaid) is None


@pytest.mark.parametrize("changed", [
    {"travel_date": "2026-08-10"},                          # different day
    {"origin": "Lahore", "destination": "Karachi"},         # the return leg
    {"destination": "Islamabad"},                           # different city
    {"booking_type": "train"},                              # different mode
])
def test_a_genuinely_new_booking_is_allowed(changed):
    """
    The gate is a refusal, so a false positive costs the user a booking they
    are entitled to make. Anything that differs must pass straight through.
    """
    assert get_already_booked_error({**PAID_FLIGHT, **changed}, PAID_FLIGHT_HISTORY) is None


def test_an_incomplete_match_is_not_a_match():
    """Missing either side of the key means "not the same", never "close enough"."""
    assert get_already_booked_error(
        {k: v for k, v in PAID_FLIGHT.items() if k != "travel_date"},
        PAID_FLIGHT_HISTORY,
    ) is None


def test_no_history_and_no_confirmation_are_safe():
    assert get_already_booked_error(PAID_FLIGHT, None) is None
    assert get_already_booked_error(PAID_FLIGHT, [{"role": "user", "content": "hi"}]) is None
    assert confirmed_components([{"role": "assistant", "content": CONFIRMED}]) == []


def test_a_paid_hotel_is_recognised():
    history = [
        {"role": "assistant", "content": (
            "**Booking Summary**\n\n"
            "\U0001f3e8  **Hotel:** Pearl Continental\n"
            "\U0001f4c5  **Check-in:** 2026-08-07\n"
            "\U0001f4c5  **Check-out:** 2026-08-09\n")},
        {"role": "assistant", "content": CONFIRMED},
    ]
    same = {"booking_type": "hotel", "hotel_name": "Pearl Continental",
            "check_in": "2026-08-07", "check_out": "2026-08-09"}
    assert get_already_booked_error(same, history)
    assert get_already_booked_error({**same, "check_in": "2026-08-20"}, history) is None


def test_both_legs_of_a_paid_package_are_recognised():
    """
    A package summary puts the date on the same line as the route. Each leg
    must keep its OWN date - borrowing the other's would refuse a leg the user
    never booked.
    """
    history = [
        {"role": "assistant", "content": (
            "**Your Package**\n\n"
            "1. ✈️  **Flight:** Lahore → Karachi, 2026-08-20 — **PKR 21,210**\n"
            "2. ✈️  **Flight:** Karachi → Lahore, 2026-08-25 — **PKR 29,052**\n\n"
            "\U0001f4b0  **Package total: PKR 50,262**\n")},
        {"role": "assistant", "content": "✅ **Package Confirmed!**\n\n**PNR:** AB12CD"},
    ]
    legs = confirmed_components(history)
    assert [(c["origin"], c["destination"], c["travel_date"]) for c in legs] == [
        ("Lahore", "Karachi", "2026-08-20"),
        ("Karachi", "Lahore", "2026-08-25"),
    ]
    out = {"booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
           "travel_date": "2026-08-20"}
    assert get_already_booked_error(out, history)
    # ...but not a third leg on a date neither of them covers.
    assert get_already_booked_error({**out, "travel_date": "2026-09-01"}, history) is None


# ── B, end to end through the real loop ──────────────────────────────────────

class _Fn:
    def __init__(self, name, arguments):
        self.name, self.arguments = name, arguments


class _Call:
    def __init__(self, call_id, name, args):
        self.id, self.type = call_id, "function"
        self.function = _Fn(name, json.dumps(args))


class _Reply:
    def __init__(self, content=None, tool_calls=None):
        self.content, self.tool_calls = content, tool_calls or []


def _script(*turns):
    state = {"i": 0}

    async def _fake(messages, tools=None, **kwargs):
        i = state["i"]
        state["i"] += 1
        return turns[i] if i < len(turns) else _Reply("(nothing more to say)")

    return _fake


@pytest.fixture
def agent(monkeypatch):
    """Stub every I/O edge, leave the loop and the booking gates real."""
    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return list(agent.history)

    async def _save_turn(*a, **k):
        return None

    async def _noop(*a, **k):
        return None

    async def _log_failure(**kwargs):
        return None

    async def _dispatch(**kwargs):
        return json.dumps({"flights": [], "note": "stubbed"})

    async def _reprice(bd):
        ident = bd.get("flight_number") or bd.get("hotel_name")
        if ident in agent.reprice_ok:
            verified = dict(bd)
            verified["total_price_pkr"] = bd.get("total_price_pkr") or 1000
            return verified
        return None

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "_log_task", _noop)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)
    monkeypatch.setattr(ma, "reprice_booking", _reprice)

    class _Agent:
        history: list = []
        reprice_ok: set = set()

        def run(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    agent = _Agent()
    return agent


def test_the_paid_flight_never_reaches_a_second_payment_screen(agent, monkeypatch):
    """
    The exact on-device failure, driven through the real loop: the model
    re-proposes the flight the traveller just paid for, with a car attached.
    Nothing may go to payment.
    """
    agent.history = list(PAID_FLIGHT_HISTORY)
    agent.reprice_ok = {"ER204"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Reply(tool_calls=[_Call("c1", "prepare_booking", {
            **PAID_FLIGHT,
            "transfer_vehicle_type": "Sedan",
            "transfer_pickup_location": "Lahore Airport",
        })]),
        _Reply("Your flight is already booked — shall I arrange the ride on its own?"),
    ))

    result = agent.run("now i want driver at lahore airport")

    assert result.get("action") != "payment_choice"
    assert result.get("action") != "package_choice"
    assert not result.get("booking_data")
    assert "46,583" not in (result.get("response") or "")


def test_a_new_piece_still_books_when_a_paid_one_is_re_proposed(agent, monkeypatch):
    """
    The refusal must not take the genuinely-new booking down with it.

    A paid component is not a FAILED component - it simply isn't part of this
    checkout. Counting it as a shortfall would make the package look incomplete
    and withhold the hotel the user actually asked for.
    """
    agent.history = list(PAID_FLIGHT_HISTORY)
    agent.reprice_ok = {"ER204", "Pearl Continental"}
    new_hotel = {
        "booking_type": "hotel", "destination": "Lahore",
        "hotel_name": "Pearl Continental", "check_in": "2026-08-07",
        "check_out": "2026-08-09", "guests": 1, "rooms": 1,
        "total_price_pkr": 24000,
    }
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Reply(tool_calls=[
            _Call("c1", "prepare_booking", PAID_FLIGHT),   # already paid - refused
            _Call("c2", "prepare_booking", new_hotel),     # genuinely new
        ]),
        _Reply("Here's your hotel."),
    ))

    result = agent.run("book me the pearl continental too")

    assert result.get("action") == "payment_choice"
    booking = result.get("booking_data") or {}
    assert booking.get("booking_type") == "hotel"
    assert booking.get("total_price_pkr") == 24000      # the fare is NOT re-charged
