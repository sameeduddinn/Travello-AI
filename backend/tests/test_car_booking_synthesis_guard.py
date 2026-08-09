"""
The post-loop synthesis guard, and the one-line fix to it.

Found while benchmarking (see tests/benchmark_production_scenarios.py): a
successful STANDALONE car booking sets `car_booking_data` and breaks the
tool-calling loop immediately ("if car_booking_data: break" in
process_message_agentic) — but the guard right after the loop only checked

    if not final_text and not booking_data:

which doesn't know about car_booking_data at all, being a separate variable.
So every standalone car booking paid for one more generate_with_tools() call
(tools=None) whose output was then thrown away unread — format_car_booking_
summary(car_booking_data) builds the actual reply further down, not final_text.

Fix: `if not final_text and not booking_data and not car_booking_data:`.

These drive the REAL process_message_agentic loop with a scripted model (same
harness as test_package_atomicity.py / test_round_trip_prefetch.py), so the
call count is the actual number of times the real loop invoked the model —
not a description of what it should do.
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

    # Structured planner-state persistence — unmocked, this hits a real
    # Supabase client and either times out or errors, adding real latency to
    # every test even though it fails safely either way. Stubbed the same as
    # every other I/O edge here for a fast, deterministic run.
    async def _no_planner_state(_cid):
        return None

    async def _noop_save_planner_state(*a, **k):
        pass

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
    "pickup_location": "Lahore airport",
    "dropoff_location": "DHA phase 5",
    "vehicle_type": "Sedan",
    "pickup_datetime": "2026-08-20 09:00",
}

FLIGHT = {
    "booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
    "travel_date": "2026-08-20", "flight_number": "PA401", "adults": 1,
    "cabin_class": "ECONOMY", "total_price_pkr": 20000,
}
FLIGHT_WITH_TRANSFER = {
    **FLIGHT,
    "transfer_vehicle_type": "Sedan",
    "transfer_pickup_location": "Lahore airport",
}
HOTEL = {
    "booking_type": "hotel", "destination": "Karachi", "hotel_name": "Pearl Continental",
    "check_in": "2026-08-20", "check_out": "2026-08-25", "guests": 2, "rooms": 1,
    "total_price_pkr": 60000,
}
FLIGHT_OUT = {
    "booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
    "travel_date": "2026-08-20", "flight_number": "PA401", "adults": 2,
    "cabin_class": "ECONOMY", "total_price_pkr": 35000,
}
FLIGHT_BACK = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Lahore",
    "travel_date": "2026-08-25", "flight_number": "ER198", "adults": 2,
    "cabin_class": "ECONOMY", "total_price_pkr": 33000,
}


class _CountingModel:
    def __init__(self, turns):
        self.turns = turns
        self.calls = {"n": 0}

    async def __call__(self, messages, tools=None, **kwargs):
        self.calls["n"] += 1
        i = self.calls["n"] - 1
        return self.turns[i] if i < len(self.turns) else _Msg("(nothing more to say)")


def _counting_model(turns):
    return _CountingModel(turns)


# ── 1 & 2. Standalone car booking: one call, response unaffected ────────────

def test_standalone_car_booking_costs_one_llm_call_not_two(agent, monkeypatch):
    model = _counting_model([_Msg(tool_calls=[_Call("t1", "book_car", CAR_ARGS)])])
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("book me a sedan from Lahore airport to DHA phase 5 tomorrow at 9am")

    assert model.calls["n"] == 1, "the wasted second synthesis call must be gone"
    assert result["action"] == "car_booking_choice"


def test_the_car_booking_response_is_exactly_the_formatted_summary(agent, monkeypatch):
    """
    Not just 'fewer calls' — the reply the user sees must be byte-identical to
    what format_car_booking_summary produces from car_booking_data, proving
    the removed call was never contributing to the answer in the first place.
    """
    from agents.booking_agent import format_car_booking_summary
    from agents.agent_tools import build_car_booking_data

    model = _counting_model([_Msg(tool_calls=[_Call("t1", "book_car", CAR_ARGS)])])
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("book me a sedan from Lahore airport to DHA phase 5 tomorrow at 9am")

    expected_data = build_car_booking_data(CAR_ARGS)
    assert result["booking_data"] == expected_data
    assert result["response"] == format_car_booking_summary(expected_data)


# ── 3-5. Other booking types: unaffected (control) ──────────────────────────

def test_flight_booking_still_costs_one_call(agent, monkeypatch):
    model = _counting_model([_Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT)])])
    agent.history = [{"role": "assistant", "content": (
        "1. **Airblue PA401** · 08:00 → 09:00 — **PKR 20,000**\n\n"
        "Just tell me the number of the one you want and I'll set it up."
    )}]
    agent.reprice_ok = {"PA401"}
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("book option 1")

    assert model.calls["n"] == 1
    assert result["action"] == "payment_choice"


def test_hotel_booking_still_costs_one_call(agent, monkeypatch):
    model = _counting_model([_Msg(tool_calls=[_Call("a", "prepare_booking", HOTEL)])])
    agent.history = [{"role": "assistant", "content": (
        "1. **Pearl Continental** 5★ — **PKR 60,000**\n\n"
        "Just tell me the number of the one you want and I'll set it up."
    )}]
    agent.reprice_ok = {"Pearl Continental"}
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("book option 1")

    assert model.calls["n"] == 1
    assert result["action"] == "payment_choice"


def test_package_booking_still_costs_one_call(agent, monkeypatch):
    model = _counting_model([_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT),
        _Call("b", "prepare_booking", FLIGHT_BACK),
    ])])
    agent.history = [{"role": "assistant", "content": (
        "**Outbound**\n1. **Airblue PA401** · 08:00 → 09:55 — **PKR 35,000**\n\n"
        "**Return**\n1. **AirSial ER198** · 16:10 → 17:45 — **PKR 33,000**\n\n"
        "Tell me which one you'd like for each leg."
    )}]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("1 for outbound and 2 for return")

    assert model.calls["n"] == 1
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2


# ── 6. Mixed booking: a car TRANSFER riding along with a flight ─────────────
# (the other "car" concept in this codebase — transfer_vehicle_type on
# prepare_booking, not a standalone book_car call — sets booking_data, never
# car_booking_data, so it must be completely unaffected by this fix.)

def test_a_flight_with_a_car_transfer_riding_along_still_costs_one_call(agent, monkeypatch):
    model = _counting_model([_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_WITH_TRANSFER),
    ])])
    agent.history = [{"role": "assistant", "content": (
        "1. **Airblue PA401** · 08:00 → 09:00 — **PKR 20,000**\n\n"
        "Just tell me the number of the one you want and I'll set it up."
    )}]
    agent.reprice_ok = {"PA401"}
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("book option 1, with a sedan transfer from the airport")

    assert model.calls["n"] == 1
    assert result["action"] == "payment_choice"
    assert "Car transfer" in result["response"]


# ── Safety net: a car booking that FAILS its gate must still get a real turn ─

def test_a_car_booking_missing_details_still_gets_a_real_answer(agent, monkeypatch):
    """
    car_booking_data stays None when the gate rejects the attempt (e.g. no
    drop-off given) — the new `and not car_booking_data` check must not
    accidentally suppress synthesis in that case; the model still needs its
    normal turn(s) to ask for what's missing.
    """
    incomplete_args = {"pickup_location": "Lahore airport"}  # no dropoff/vehicle/time
    model = _counting_model([
        _Msg(tool_calls=[_Call("t1", "book_car", incomplete_args)]),
        _Msg("Sure — where would you like to be dropped off, and what time?"),
    ])
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", model)

    result = agent.run("book me a car from Lahore airport")

    assert result.get("action") is None
    assert result["response"]
