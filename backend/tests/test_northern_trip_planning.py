"""
Multi-modal northern-destination itinerary (Islamabad flight + Naran hotel,
with the hub->destination car leg riding along as a route-aware transfer on
the flight's OWN prepare_booking call) is ONE package, ONE payment — this
locks in that shape end to end.

Same harness as test_car_alongside_package.py / test_package_atomicity.py:
drives the REAL process_message_agentic loop with a scripted model, so the
response is what the real loop actually produces, not a hand-written
expectation.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma


class _Fn:
    def __init__(self, name, arguments):
        self.name = name
        self.arguments = arguments


class _Call:
    def __init__(self, call_id, name, args):
        self.id = call_id
        self.type = "function"
        self.function = _Fn(name, json.dumps(args))


class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content = content
        self.tool_calls = tool_calls or []


def _script(*turns):
    """A generate_with_tools stand-in that replays `turns` one per loop step."""
    state = {"i": 0}

    async def _fake(messages, tools=None, **kwargs):
        i = state["i"]
        state["i"] += 1
        return turns[i] if i < len(turns) else _Msg("(nothing more to say)")

    return _fake


@pytest.fixture
def agent(monkeypatch):
    """Stub every I/O edge of process_message_agentic; loop + gates stay real."""
    saved = {"turns": []}

    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return list(agent.history)

    async def _no_planner_state(_cid):
        return None

    async def _noop_save_planner_state(*a, **k):
        pass

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        saved["turns"].append(reply)

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)

    async def _reprice(bd):
        ident = bd.get("flight_number") or bd.get("train_name") or bd.get("hotel_name")
        if ident in agent.reprice_ok:
            verified = dict(bd)
            verified["total_price_pkr"] = bd.get("total_price_pkr") or 1000
            return verified
        return None

    monkeypatch.setattr(ma, "reprice_booking", _reprice)

    class _Agent:
        history: list = []
        reprice_ok: set = set()
        saved: dict = {}

        def run(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    agent = _Agent()
    agent.saved = saved
    return agent


FLIGHT_TO_HUB_WITH_TRANSFER = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Islamabad",
    "travel_date": "2026-09-01", "flight_number": "PK304", "adults": 2,
    "cabin_class": "ECONOMY", "total_price_pkr": 32000,
    "transfer_vehicle_type": "Sedan",
    "transfer_pickup_location": "Islamabad International Airport",
    "transfer_dropoff_location": "Naran",
}
# Adversarial: the transfer is set up but the dropoff was forgotten — must
# never silently fall back to the flat in-city rate for a real 190km route.
FLIGHT_TO_HUB_NO_DROPOFF = {
    k: v for k, v in FLIGHT_TO_HUB_WITH_TRANSFER.items() if k != "transfer_dropoff_location"
}
NARAN_HOTEL = {
    "booking_type": "hotel", "hotel_name": "PTDC Motel Naran",
    "check_in": "2026-09-01", "check_out": "2026-09-04", "rooms": 1, "guests": 2,
}

OFFERS = {"role": "assistant", "content": (
    "**Flights to Islamabad**\n1. PIA PK304 · 07:00 — PKR 32,000\n\n"
    "**Hotels in Naran**\n1. PTDC Motel Naran · PKR 12,000/night\n"
)}

USER_MESSAGE = (
    "book flight option 1 and the hotel, and get me a sedan from Islamabad "
    "airport to Naran at 2pm on 1 sept"
)


# ── Happy path: flight(+transfer)+hotel is ONE package, ONE payment ──────────

def test_islamabad_flight_and_naran_hotel_package_includes_the_routed_car_fare(agent, monkeypatch):
    """
    The exact shape this feature adds: Karachi -> flight -> Islamabad (the real
    nearest hub, since Naran has no airport) -> Car -> Naran, plus a hotel in
    Naran itself — ALL as one package, one payment. (The routed-fare math
    itself — that this same pickup/dropoff pair prices at PKR 18,000 instead
    of the flat in-city rate — is covered precisely by
    test_transfer_route_pricing.py; this test's fixture mocks reprice_booking
    itself, so it only exercises the orchestration shape, same as this file
    always has.)
    """
    agent.history = [OFFERS]
    agent.reprice_ok = {"PK304", "PTDC Motel Naran"}
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_TO_HUB_WITH_TRANSFER),
            _Call("b", "prepare_booking", NARAN_HOTEL),
        ]))
    ))

    result = agent.run(USER_MESSAGE)

    # The flight+hotel package books as one checkout, same contract as any package.
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    # No separate book_car confirm anymore — the car leg is INSIDE this package.
    assert "cab request ready" not in result["response"]
    # The transfer fields survived gating and rode along on the flight piece.
    flight_component = next(
        c for c in result["booking_data"]["components"] if c.get("booking_type") == "flight"
    )
    assert flight_component["transfer_vehicle_type"] == "Sedan"
    assert flight_component["transfer_dropoff_location"] == "Naran"


# ── Adversarial: missing dropoff must block the package, never undercharge ───

def test_missing_dropoff_blocks_the_whole_package_instead_of_undercharging(agent, monkeypatch):
    """
    If the model sets up the transfer but forgets transfer_dropoff_location,
    get_transfer_error must reject that WHOLE prepare_booking call — the
    package must never reach payment priced at the flat in-city rate for
    what is actually a real ~190km route.
    """
    agent.history = [OFFERS]
    agent.reprice_ok = {"PK304", "PTDC Motel Naran"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_TO_HUB_NO_DROPOFF),
            _Call("b", "prepare_booking", NARAN_HOTEL),
        ]),
        _Msg(tool_calls=[
            _Call("c", "prepare_booking", FLIGHT_TO_HUB_NO_DROPOFF),
            _Call("d", "prepare_booking", NARAN_HOTEL),
        ]),
        _Msg(tool_calls=[
            _Call("e", "prepare_booking", FLIGHT_TO_HUB_NO_DROPOFF),
            _Call("f", "prepare_booking", NARAN_HOTEL),
        ]),
    ))

    result = agent.run(USER_MESSAGE)

    assert result.get("action") is None, "an undercharged package must never reach payment"
    assert result.get("booking_data") is None
    assert "no card has been charged" in result["response"].lower()


# ── Trip Planner mode: a single leg must never finalize on its own ───────────

HUNZA_FLIGHT_OFFERS = {"role": "assistant", "content": (
    "1. Pakistan International Airlines PK107 · 07:00 → 08:11 — PKR 11,033\n"
    "2. Pakistan International Airlines PK379 · 07:30 → 10:10 — PKR 64,995\n"
)}

FLIGHT_TO_GILGIT_ONLY = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Gilgit",
    "travel_date": "2026-08-14", "flight_number": "PK379", "adults": 4,
    "cabin_class": "ECONOMY", "total_price_pkr": 259980,
}


def test_a_single_leg_pick_never_becomes_its_own_payment_in_trip_planner_mode(agent, monkeypatch):
    """
    Real bug reproduction: the user asked to plan a Hunza trip, only flight
    options were ever searched/shown (no hotel), and picking one used to turn
    that single flight into its own "Booking Summary" + Pay button, with the
    hotel and car transfer deferred to "next" — three separate charges for
    one trip. A Hunza/Naran/Skardu/Swat trip must never finalize a single
    piece on its own; nothing may reach payment until transport, hotel, and
    (for a hub-less destination like Hunza) the car transfer are ALL prepared
    together in one reply.
    """
    agent.history = [
        {"role": "user", "content": "Plan a trip to Hunza Valley"},
        {"role": "assistant", "content": (
            "Sure thing! Could you share your travel dates, number of "
            "travelers, and budget?"
        )},
        {"role": "user", "content": (
            "Outbound date 14 Aug 2026, return date 25 August 2026. "
            "2 adults and 2 children. 1 lac budget."
        )},
        HUNZA_FLIGHT_OFFERS,
    ]
    agent.reprice_ok = {"PK379"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT_TO_GILGIT_ONLY)]),
        _Msg(tool_calls=[_Call("b", "prepare_booking", FLIGHT_TO_GILGIT_ONLY)]),
        _Msg(tool_calls=[_Call("c", "prepare_booking", FLIGHT_TO_GILGIT_ONLY)]),
    ))

    result = agent.run("2")

    assert result.get("action") is None, "a single leg must never become its own payment in Trip Planner mode"
    assert result.get("booking_data") is None
    assert "no card has been charged" in result["response"].lower()
    # The fallback names exactly what's missing instead of a vague "half a
    # trip" — both required-but-never-searched pieces, by their friendly labels.
    assert "Missing:" in result["response"]
    assert "- Hotel" in result["response"]
    assert "- Car Transfer (Gilgit → Hunza)" in result["response"]
