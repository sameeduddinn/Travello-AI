"""
Multi-modal northern-destination itinerary (Islamabad flight + Naran hotel,
via book_car for the hub->destination road leg) rides entirely on the
existing package/car machinery — this locks in that shape end to end.

Same harness as test_car_alongside_package.py: drives the REAL
process_message_agentic loop with a scripted model, so the response is what
the real loop actually produces, not a hand-written expectation.
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


FLIGHT_TO_HUB = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Islamabad",
    "travel_date": "2026-09-01", "flight_number": "PK304", "adults": 2,
    "cabin_class": "ECONOMY", "total_price_pkr": 32000,
}
NARAN_HOTEL = {
    "booking_type": "hotel", "hotel_name": "PTDC Motel Naran",
    "check_in": "2026-09-01", "check_out": "2026-09-04", "rooms": 1, "guests": 2,
}
HUB_CAR_ARGS = {
    "pickup_location": "Islamabad Airport",
    "dropoff_location": "Naran",
    "vehicle_type": "Sedan",
    "pickup_datetime": "2026-09-01 14:00",
}

OFFERS = {"role": "assistant", "content": (
    "**Flights to Islamabad**\n1. PIA PK304 · 07:00 — PKR 32,000\n\n"
    "**Hotels in Naran**\n1. PTDC Motel Naran · PKR 12,000/night\n"
)}


# ── Happy path: flight+hotel package, with the hub->Naran car leg alongside ──

def test_islamabad_flight_and_naran_hotel_package_with_hub_car_leg(agent, monkeypatch):
    """
    The exact shape this feature adds: Karachi -> flight -> Islamabad (the real
    nearest hub, since Naran has no airport) -> Car -> Naran, plus a hotel in
    Naran itself, in one turn.
    """
    agent.history = [OFFERS]
    agent.reprice_ok = {"PK304", "PTDC Motel Naran"}
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_TO_HUB),
            _Call("b", "prepare_booking", NARAN_HOTEL),
            _Call("c", "book_car", HUB_CAR_ARGS),
        ]))
    ))

    result = agent.run(
        "book flight option 1 and the hotel, and get me a sedan from Islamabad "
        "airport to Naran at 2pm on 1 sept"
    )

    # The flight+hotel package books as one checkout, same contract as any package.
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    # The hub->destination car leg is a separate book_car confirm — acknowledged,
    # not silently dropped, exactly like every other car-alongside-a-package case.
    assert "cab request ready" in result["response"]


# ── Adversarial: the user never named a vehicle -> book_car must be withheld ──

def test_car_leg_is_withheld_when_the_user_never_named_a_vehicle(agent, monkeypatch):
    """
    The provenance gate (get_car_provenance_error) must still block a car the
    model tries to construct without the user ever having said Sedan/SUV/Van —
    a real driver is dispatched to whatever's confirmed, so this must never be
    guessed just because it's part of a northern-trip itinerary.
    """
    agent.history = [OFFERS]
    agent.reprice_ok = {"PK304", "PTDC Motel Naran"}
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_TO_HUB),
            _Call("b", "prepare_booking", NARAN_HOTEL),
            _Call("c", "book_car", HUB_CAR_ARGS),
        ]))
    ))

    # No vehicle word anywhere in the user's own turn.
    result = agent.run("book flight option 1 and the hotel, and arrange transport to Naran too")

    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    # The car request must NOT be confirmed — the model never got the user's
    # own confirmation of the vehicle type, so book_car stays withheld.
    assert "cab request ready" not in result["response"]
