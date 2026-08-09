"""
AGENTIC_TRIP_PLANNER_BLOCK tells the model to "search the HUB" for Naran,
Hunza and Swat (no airport/station of their own), and to search Skardu
directly (it has its own airport) — but that's advisory prompt text only.
Observed live: asked to plan a Naran trip, the model's own first reply
correctly named Islamabad as the hub, but its NEXT turn (after the traveller
gave dates/budget/mode/hotel) searched flights and a hotel for Karachi ->
Lahore instead — a city pair the traveller never named. hub_mismatch_error
(agent_tools.py) + dispatch_tool_with_retry's new trip_destination param
close this the same deterministic way transport_mode_missing_error already
closes the "never asked flight or train" gap: block, don't hope the model
self-corrects.
"""
import asyncio
import json

import pytest

from agents import agent_tools as at
from agents import master_agent as ma
from agents import self_improvement as si


# ── Pure gate logic ───────────────────────────────────────────────────────

def test_blocks_a_flight_search_to_the_wrong_city():
    gate = at.hub_mismatch_error(
        "search_flights", {"destination_city": "Lahore"},
        is_trip_planner=True, trip_destination="Naran",
    )
    assert gate is not None
    assert gate["error"] == "wrong_hub_city"
    assert "Islamabad" in gate["instruction"]


def test_blocks_a_hotel_search_in_the_wrong_city():
    gate = at.hub_mismatch_error(
        "search_hotels", {"city": "Lahore"},
        is_trip_planner=True, trip_destination="Naran",
    )
    assert gate is not None
    assert gate["error"] == "wrong_hotel_city"
    assert "Naran" in gate["instruction"]


def test_passes_a_flight_search_to_the_real_hub():
    assert at.hub_mismatch_error(
        "search_flights", {"destination_city": "Islamabad"},
        is_trip_planner=True, trip_destination="Naran",
    ) is None


def test_passes_a_train_search_to_the_real_train_hub():
    # Naran's train hub is Rawalpindi, not Islamabad (flight-only hub).
    assert at.hub_mismatch_error(
        "search_trains", {"destination_city": "Rawalpindi"},
        is_trip_planner=True, trip_destination="Naran",
    ) is None


def test_a_flight_to_the_train_only_hub_is_still_blocked():
    gate = at.hub_mismatch_error(
        "search_flights", {"destination_city": "Rawalpindi"},
        is_trip_planner=True, trip_destination="Naran",
    )
    assert gate is not None
    assert "Islamabad" in gate["instruction"]


def test_a_hotel_search_in_the_real_destination_passes():
    assert at.hub_mismatch_error(
        "search_hotels", {"city": "Naran"},
        is_trip_planner=True, trip_destination="Naran",
    ) is None


def test_skardu_must_be_searched_directly_not_a_hub():
    # Skardu has its own airport — hub_options_for returns [], no substitution.
    assert at.hub_mismatch_error(
        "search_flights", {"destination_city": "Skardu"},
        is_trip_planner=True, trip_destination="Skardu",
    ) is None
    gate = at.hub_mismatch_error(
        "search_flights", {"destination_city": "Lahore"},
        is_trip_planner=True, trip_destination="Skardu",
    )
    assert gate is not None
    assert gate["error"] == "wrong_destination_city"
    assert "Skardu" in gate["instruction"]


def test_passes_outside_trip_planner_turns():
    assert at.hub_mismatch_error(
        "search_flights", {"destination_city": "Lahore"},
        is_trip_planner=False, trip_destination="Naran",
    ) is None


def test_passes_when_no_destination_is_known_yet():
    assert at.hub_mismatch_error(
        "search_flights", {"destination_city": "Lahore"},
        is_trip_planner=True, trip_destination="",
    ) is None


def test_passes_for_a_destination_that_is_not_one_of_the_four():
    # e.g. an ordinary Lahore/Karachi search reusing the Trip Planner flag
    # by coincidence — hub_options_for returns None, gate is a no-op.
    assert at.hub_mismatch_error(
        "search_flights", {"destination_city": "Multan"},
        is_trip_planner=True, trip_destination="Lahore",
    ) is None


def test_never_blocks_unrelated_tools():
    assert at.hub_mismatch_error(
        "get_weather", {"city": "Lahore"},
        is_trip_planner=True, trip_destination="Naran",
    ) is None


def test_accepts_an_alias_form_of_the_destination():
    # "Kaghan" is a recognised alias of Naran (canonical_destination).
    assert at.hub_mismatch_error(
        "search_hotels", {"city": "Kaghan"},
        is_trip_planner=True, trip_destination="Naran",
    ) is None


# ── dispatch_tool_with_retry wiring ────────────────────────────────────────

def test_dispatch_blocks_before_ever_calling_execute_tool(monkeypatch):
    called = {"n": 0}

    async def _execute_tool(name, args):
        called["n"] += 1
        return json.dumps({"flights": ["should never be reached"]})
    monkeypatch.setattr(si, "execute_tool", _execute_tool)

    raw = asyncio.run(si.dispatch_tool_with_retry(
        user_id="u1", conversation_id="c1", user_message="Naran, 2 adults",
        name="search_flights", args={"destination_city": "Lahore"},
        has_user_date=True, is_trip_planner=True, has_transport_mode=True,
        trip_destination="Naran",
    ))
    result = json.loads(raw)

    assert called["n"] == 0, "execute_tool must never run once the hub gate blocks"
    assert result["error"] == "wrong_hub_city"


def test_dispatch_runs_normally_by_default(monkeypatch):
    """Every pre-existing call site never passes trip_destination — it must
    default to "" so the gate is a no-op and nothing else is affected."""
    called = {"n": 0}

    async def _execute_tool(name, args):
        called["n"] += 1
        return json.dumps({"flights": ["ok"]})
    monkeypatch.setattr(si, "execute_tool", _execute_tool)

    raw = asyncio.run(si.dispatch_tool_with_retry(
        user_id="u1", conversation_id="c1", user_message="Karachi to Lahore",
        name="search_flights", args={"destination_city": "Lahore"},
        has_user_date=True,
    ))
    result = json.loads(raw)

    assert called["n"] == 1
    assert result == {"flights": ["ok"]}


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
            f"execute_tool({name!r}, {args!r}) was called -- the hub-mismatch "
            "gate should have blocked this before any real search ran."
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


def test_model_hallucinating_the_wrong_city_pair_is_blocked_end_to_end(agent):
    """
    Reproduces the exact reported scenario: the traveller asks to plan a
    Naran trip, the assistant's own first reply correctly names Islamabad as
    the hub, then the traveller gives dates/party/budget/mode/hotel. The
    model (scripted here to behave like the one observed live) tries
    search_flights + search_hotels for Karachi -> Lahore instead — a city
    pair the traveller never named. The real search must never execute for
    either call; the model must receive the deterministic hub-correction
    instead.
    """
    agent.history = [
        {"role": "user", "content": "I want to book trip to Naran"},
        {"role": "assistant", "content": (
            "Naran is a beautiful destination. To plan your trip, I'll need "
            "a few more details — dates, party size, budget, flight or "
            "train, and hotel preference. Since Naran has no airport of its "
            "own, we'll route through Islamabad, the nearest hub."
        )},
    ]
    agent.script = [
        _Msg(tool_calls=[
            _Call("1", "search_flights", {
                "origin_city": "Karachi", "destination_city": "Lahore",
                "travel_date": "2026-09-02", "passengers": 1, "cabin_class": "BUSINESS",
            }),
            _Call("2", "search_hotels", {
                "city": "Lahore", "check_in": "2026-09-02", "check_out": "2026-09-08",
            }),
        ]),
        _Msg(content="Let me search flights and hotels to Islamabad/Naran instead."),
    ]

    result = agent.run(
        "2 September 2026 to 8 September 2026, 1 adult, 100,000, flight business, hotel"
    )

    # No AssertionError from _no_execute_tool means neither real search ran.
    assert "response" in result
