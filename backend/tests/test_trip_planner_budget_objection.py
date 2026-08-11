"""
Free-text budget pushback right after the Trip Plan card ("its not in my
budget", "but my budget is lower") named no pick and wasn't a recognized
confirmation, so it fell straight through to the final fallback that just
re-renders the exact same Trip Plan card, verbatim, with no acknowledgement
and no path forward — a silent dead end (real user report, reproduced here
with the same phrasing).

Same harness as test_trip_planner_followup_answer.py: the pure trip_selection
functions build a real options/plan pair via history, and the turn drives the
REAL process_message_agentic loop with a SCRIPTED model that must never be
called, since this is a deterministic, in-code reply.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma
from agents import trip_selection as ts


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

    class _Agent:
        history: list = []
        saved: dict = {}

    agent = _Agent()
    agent.saved = saved
    return agent


def _run(agent, message):
    return asyncio.run(ma.process_message_agentic("u1", "c1", message))


# ── A real Swat trip plan, built the same way the app builds one ─────────────

FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 1,
    "flights": [
        {"flight_number": "PK948", "airline": "PIA", "from": "Karachi", "to": "Islamabad",
         "depart": "2026-08-14 07:00", "arrive": "09:03", "cabin": "ECONOMY",
         "total_price_pkr": 45150},
        {"flight_number": "PA911", "airline": "Airblue", "from": "Karachi", "to": "Islamabad",
         "depart": "2026-08-14 07:00", "arrive": "08:50", "cabin": "ECONOMY",
         "total_price_pkr": 60000},
    ],
})
HOTELS = json.dumps({
    "city": "Swat", "nights": 5, "rooms": 1, "guests": 1,
    "hotels": [
        {"name": "Burj Al Swat Hotel", "stars": 4.4, "price_per_night_pkr": 25008,
         "total_stay_pkr": 125040},
        {"name": "Hotel Intercon", "stars": 3.6, "price_per_night_pkr": 15941,
         "total_stay_pkr": 79705},
    ],
})


def _history_with_plan_shown(prior_user_texts=()):
    """History ending on the plan card itself, optionally preceded by extra
    user turns (e.g. a stated budget) that derive_state() will still see."""
    options = ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)],
        "Swat", passengers=1, preferred_mode="flight")
    options = ts.parse_options(ts.render_options(options))
    picks = ts.merge_picks(options, "Flight 1, Hotel 2, Transfer 1", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    options_block = ts.render_options(options)
    plan_card = ts.render_plan(plan, options, picks, "Swat")
    history = [{"role": "user", "content": t} for t in prior_user_texts]
    history += [
        {"role": "user", "content": "I want to book a trip to Swat"},
        {"role": "assistant", "content": options_block},
        {"role": "user", "content": "Flight 1, Hotel 2, Transfer 1"},
        {"role": "assistant", "content": plan_card},
    ]
    return options, picks, plan, history


def _never_called_model(monkeypatch):
    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)
    return calls


# ── 1. A budget objection with no stated number asks for one ─────────────────

def test_a_budget_objection_with_no_known_budget_asks_for_the_number(agent, monkeypatch):
    _options, _picks, plan, history = _history_with_plan_shown()
    agent.history = history
    calls = _never_called_model(monkeypatch)

    result = _run(agent, "its not in my budget")

    assert calls["n"] == 0
    reply = result.get("response") or ""
    assert "YOUR TRIP PLAN" not in reply
    assert "what's your budget" in reply.lower()
    assert f"{plan.total_pkr:,}" in reply


def test_a_differently_worded_budget_objection_is_also_caught(agent, monkeypatch):
    _options, _picks, _plan, history = _history_with_plan_shown()
    agent.history = history
    calls = _never_called_model(monkeypatch)

    result = _run(agent, "but my budget is lower")

    assert calls["n"] == 0
    assert "YOUR TRIP PLAN" not in (result.get("response") or "")


# ── 2. A budget objection with a known, exceeded budget names the gap ────────

def test_a_budget_objection_with_a_known_lower_budget_states_the_gap(agent, monkeypatch):
    _options, _picks, plan, history = _history_with_plan_shown(
        prior_user_texts=["my budget is 50k"])
    agent.history = history
    calls = _never_called_model(monkeypatch)

    result = _run(agent, "its not in my budget")

    assert calls["n"] == 0
    reply = result.get("response") or ""
    assert "YOUR TRIP PLAN" not in reply
    assert "50,000" in reply
    assert f"{plan.total_pkr:,}" in reply
    assert "swap" in reply.lower()


# ── 3. Nothing else on this path is affected ──────────────────────────────────

def test_a_pick_change_still_works_and_is_not_treated_as_an_objection(agent, monkeypatch):
    _options, _picks, _plan, history = _history_with_plan_shown()
    agent.history = history
    calls = _never_called_model(monkeypatch)

    result = _run(agent, "Flight 2, Hotel 1, Transfer 1")

    assert calls["n"] == 0
    reply = result.get("response") or ""
    assert "YOUR TRIP PLAN" in reply
    assert "Flight #2" in reply


def test_a_plain_yes_still_confirms_and_is_not_treated_as_an_objection(agent, monkeypatch):
    _options, picks, plan, history = _history_with_plan_shown()
    agent.history = history

    async def _reprice(bd):
        verified = dict(bd)
        verified["total_price_pkr"] = bd.get("total_price_pkr") or 1000
        return verified

    monkeypatch.setattr(ma, "reprice_booking", _reprice)
    calls = _never_called_model(monkeypatch)

    result = _run(agent, "yes")

    # A plain "yes" with a transfer still pending asks for the pickup address
    # deterministically — it must NOT be answered with the budget-objection
    # reply, and the model must still never be called.
    assert calls["n"] == 0
    reply = result.get("response") or ""
    assert "budget" not in reply.lower()
    assert "pickup address" in reply.lower()


def test_an_unrelated_free_text_reply_still_falls_back_to_re_rendering(agent, monkeypatch):
    """Regression guard: only a genuine budget objection is intercepted —
    anything else that isn't a pick/confirmation still gets the pre-existing
    fallback (re-render the plan), unchanged from before this fix."""
    _options, _picks, _plan, history = _history_with_plan_shown()
    agent.history = history
    calls = _never_called_model(monkeypatch)

    result = _run(agent, "what facilities does the hotel have")

    assert calls["n"] == 0
    assert "YOUR TRIP PLAN" in (result.get("response") or "")
