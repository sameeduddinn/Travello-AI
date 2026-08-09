"""
The Trip Planner prompt (AGENTIC_TRIP_PLANNER_BLOCK) already instructs the
model to gather "flight or train, cabin/class" in its one clarifying
question — but a free-tier model doesn't reliably comply. Observed live: a
message naming a northern destination, party size, dates and budget, but
never a transport mode, went straight to a rendered train options list
without the model ever asking flight-or-train. transport_mode_missing_error
(agent_tools.py) + dispatch_tool_with_retry's new is_trip_planner/
has_transport_mode params close this the same way date_provenance_error
already closes the equivalent gap for dates: deterministically, not by
hoping the model asks.
"""
import asyncio
import json

import pytest

from agents import agent_tools as at
from agents import master_agent as ma
from agents import self_improvement as si


# ── Pure gate logic ───────────────────────────────────────────────────────

def test_blocks_a_search_when_trip_planner_and_mode_unchosen():
    for name in ("search_flights", "search_trains"):
        gate = at.transport_mode_missing_error(
            name, is_trip_planner=True, has_transport_mode=False,
        )
        assert gate is not None
        assert gate["error"] == "transport_mode_not_chosen"
        assert "flight" in gate["instruction"].lower()
        assert "train" in gate["instruction"].lower()


def test_passes_once_a_mode_is_chosen():
    gate = at.transport_mode_missing_error(
        "search_trains", is_trip_planner=True, has_transport_mode=True,
    )
    assert gate is None


def test_passes_outside_trip_planner_turns():
    # An ordinary standalone flight/train search (no recognised northern
    # destination this turn) must never be blocked by this gate.
    gate = at.transport_mode_missing_error(
        "search_trains", is_trip_planner=False, has_transport_mode=False,
    )
    assert gate is None


def test_never_blocks_unrelated_tools():
    gate = at.transport_mode_missing_error(
        "search_hotels", is_trip_planner=True, has_transport_mode=False,
    )
    assert gate is None


# ── dispatch_tool_with_retry wiring ────────────────────────────────────────

def test_dispatch_blocks_before_ever_calling_execute_tool(monkeypatch):
    called = {"n": 0}

    async def _execute_tool(name, args):
        called["n"] += 1
        return json.dumps({"trains": ["should never be reached"]})
    monkeypatch.setattr(si, "execute_tool", _execute_tool)

    raw = asyncio.run(si.dispatch_tool_with_retry(
        user_id="u1", conversation_id="c1", user_message="Naran, 2 adults, 14 Aug 2026",
        name="search_trains", args={"origin_city": "Karachi", "destination_city": "Rawalpindi"},
        has_user_date=True, is_trip_planner=True, has_transport_mode=False,
    ))
    result = json.loads(raw)

    assert called["n"] == 0, "execute_tool must never run once the mode gate blocks"
    assert result["error"] == "transport_mode_not_chosen"


def test_dispatch_runs_normally_by_default(monkeypatch):
    """Every pre-existing call site (round-trip prefetch, the package
    fill-call) never passes is_trip_planner/has_transport_mode — the new
    params must default to fully permissive so none of them are affected."""
    called = {"n": 0}

    async def _execute_tool(name, args):
        called["n"] += 1
        return json.dumps({"trains": ["ok"]})
    monkeypatch.setattr(si, "execute_tool", _execute_tool)

    raw = asyncio.run(si.dispatch_tool_with_retry(
        user_id="u1", conversation_id="c1", user_message="Naran, 2 adults, 14 Aug 2026",
        name="search_trains", args={}, has_user_date=True,
    ))
    result = json.loads(raw)

    assert called["n"] == 1
    assert result == {"trains": ["ok"]}


# ── Full end-to-end reproduction ───────────────────────────────────────────

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
        pass

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    async def _no_execute_tool(name, args):
        raise AssertionError(
            f"execute_tool({name!r}) was called -- the transport-mode gate "
            "should have blocked this before any real search ran."
        )

    async def _fake_generate(messages, tools=None, **kwargs):
        i = agent._i
        agent._i += 1
        return agent.script[i] if i < len(agent.script) else _Msg("(nothing more)")

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma, "generate_with_tools", _fake_generate)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)
    monkeypatch.setattr(si, "execute_tool", _no_execute_tool)

    class _Agent:
        history: list = []
        script: list = []
        _i = 0

        def run(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    agent = _Agent()
    return agent


def test_model_calling_search_trains_without_a_chosen_mode_is_blocked_end_to_end(agent):
    """
    Reproduces the exact reported scenario: the traveller names a
    destination, party size, dates and budget for a northern trip, but
    never says "flight" or "train". The model (scripted here to behave like
    the one observed live) tries search_trains directly anyway. The real
    search must never execute; the model must receive the deterministic
    ask-first instruction instead.
    """
    agent.history = [
        {"role": "user", "content": "I want to make a trip plan"},
        {"role": "assistant", "content": (
            "To make a trip plan, I need to know a few details. Can you please "
            "tell me where you'd like to go, how many people are traveling, and "
            "what are your travel dates? Additionally, do you have a budget in "
            "mind for this trip?"
        )},
    ]
    agent.script = [
        _Msg(tool_calls=[_Call("1", "search_trains", {
            "origin_city": "Karachi", "destination_city": "Rawalpindi",
            "travel_date": "2026-08-14", "passengers": 4,
        })]),
        _Msg(content="Would you like to fly or take the train, and which class?"),
    ]

    result = agent.run(
        "Naran Kaghan, 2 adults 2 children, 14 August 2026 to 25 August 2026, 150,000"
    )

    # No AssertionError from _no_execute_tool means the real search never ran.
    assert "fly or take the train" in result["response"]
