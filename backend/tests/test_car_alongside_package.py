"""
A standalone car booking must never be silently discarded just because a
package or single booking is ALSO completing (or failing to complete) in the
same model reply.

The bug this file guards against: `car_booking_data` is gated and set before
the ATOMIC PACKAGE GATE runs (see process_message_agentic), but the response
contract returns only one action per turn, and the post-loop return cascade
(package_incomplete -> package_components -> booking_data -> car_booking_data)
picks the package/booking every time a package is also present that turn —
discarding a fully valid, driver-ready car booking with no trace, and no
acknowledgement to the user that anything was asked for.

Fix: `_car_booking_note(car_booking_data)` appends a plain, honest sentence to
whichever summary IS returned, so the user knows their cab request was
received and needs one more ask to get its own confirm button — instead of
it vanishing without a word. The action/booking_data contract for the
package/booking themselves is untouched.

These drive the REAL process_message_agentic loop with a scripted model (same
harness as test_package_atomicity.py / test_car_booking_synthesis_guard.py),
so the response text is what the real loop actually produced.
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


CAR_ARGS = {
    "pickup_location": "Karachi airport",
    "dropoff_location": "Clifton",
    "vehicle_type": "Sedan",
    "pickup_datetime": "2026-08-20 09:00",
}
CAR_MESSAGE = "also book me a sedan from Karachi airport to Clifton at 9am"

FLIGHT_OUT = {
    "booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
    "travel_date": "2026-08-20", "flight_number": "PA401", "adults": 1,
    "cabin_class": "ECONOMY", "total_price_pkr": 20000,
}
FLIGHT_BACK = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Lahore",
    "travel_date": "2026-08-25", "flight_number": "ER198", "adults": 1,
    "cabin_class": "ECONOMY", "total_price_pkr": 18000,
}
FLIGHT = {
    "booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
    "travel_date": "2026-08-20", "flight_number": "PA401", "adults": 1,
    "cabin_class": "ECONOMY", "total_price_pkr": 20000,
}

OFFERS = {"role": "assistant", "content": (
    "**Outbound**\n1. Airblue PA401 · 08:00 — PKR 20,000\n\n"
    "**Return**\n1. AirSial ER198 · 16:10 — PKR 18,000\n"
)}
SINGLE_OFFER = {"role": "assistant", "content": (
    "1. **Airblue PA401** · 08:00 → 09:00 — **PKR 20,000**\n\n"
    "Just tell me the number of the one you want and I'll set it up."
)}


# ── A completing package must still mention the car, not just book the flights ──

def test_a_completing_package_still_mentions_the_car_request(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),
            _Call("c", "book_car", CAR_ARGS),
        ]))
    ))

    result = agent.run(f"1 for outbound and 2 for return, and {CAR_MESSAGE}")

    # The package itself must be completely unaffected — same contract as before.
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    # But the car request must be acknowledged, not silently dropped.
    assert "cab request ready" in result["response"]


# ── A completing single booking must still mention the car ──────────────────

def test_a_completing_single_booking_still_mentions_the_car_request(agent, monkeypatch):
    agent.history = [SINGLE_OFFER]
    agent.reprice_ok = {"PA401"}
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT),
            _Call("c", "book_car", CAR_ARGS),
        ]))
    ))

    result = agent.run(f"book option 1, and {CAR_MESSAGE}")

    assert result["action"] == "payment_choice"
    assert "cab request ready" in result["response"]


# ── An incomplete package must still mention the car ─────────────────────────

def test_an_incomplete_package_still_mentions_the_car_request(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401"}  # the return can't be confirmed -> incomplete
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),
            _Call("c", "book_car", CAR_ARGS),
        ]))
    ))

    result = agent.run(f"1 for outbound and 2 for return, and {CAR_MESSAGE}")

    assert result.get("action") is None  # no payment action for a half-verified package
    assert "cab request ready" in result["response"]


# ── Control: no car call in the turn -> no note, no change to existing behaviour ─

def test_a_package_with_no_car_request_gets_no_car_note(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", lambda messages, tools=None, **kw: (
        asyncio.sleep(0, result=_Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),
        ]))
    ))

    result = agent.run("1 for outbound and 2 for return")

    assert result["action"] == "package_choice"
    assert "cab request ready" not in result["response"]
