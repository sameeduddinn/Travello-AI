"""
A traveller confirms a Trip Planner package ("yes"), and the exact hotel
they picked can no longer be re-confirmed against a fresh search
(reprice_booking -> offer_not_found) — the real bug this closes, traced to a
genuine cause: an external hotel provider (RapidAPI) hit its monthly quota
mid-session and the backend fell back to a different provider (Google
Places) whose result set for the same city didn't include the previously
shown hotel.

Before this fix, the deterministic confirmation simply bailed out to the
model-driven fallback path, which produced a dead-end "still missing: Hotel"
message with no real next step (confirmed against a live agent_failure_log
row: reprice failed with `offer_not_found` for the exact hotel, then the
model's own retry failed AGAIN with `missing_required_fields`).

Now: complete_trip_planner_confirmation distinguishes this specific failure
(offer_not_found) from every other gate rejection and hands the caller
enough to recover from it. In chat, process_message_agentic's
_recover_stale_pick re-runs the SAME search deterministically and re-renders
fresh options — reusing trip_selection.merge_fresh_search exactly as the
"switched to business class mid-conversation" fix earlier this session does.

This file drives the REAL process_message_agentic loop end to end, mocking
only the true I/O edges (memory, history, persistence, reprice, the search
dispatcher) — never the orchestration/gates themselves. generate_with_tools
is mocked to raise if called at all, which is the strongest possible proof
that recovery happens deterministically, with zero model involvement.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma
from agents import trip_selection as ts


@pytest.fixture
def agent(monkeypatch):
    """Same shape as test_trip_planner_followup_answer.py's `agent` fixture,
    plus a mockable search dispatcher for the recovery path."""
    saved = {"turns": [], "planner_states": []}

    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return list(agent.history)

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        saved["turns"].append(reply)

    async def _save_planner_state(cid, uid, state):
        saved["planner_states"].append(state)

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    async def _no_model_call(*a, **k):
        raise AssertionError(
            "generate_with_tools was called -- stale-pick recovery must be "
            "fully deterministic and never reach the model."
        )

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "save_planner_state", _save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma, "generate_with_tools", _no_model_call)
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

    async def _dispatch(*, user_id, conversation_id, user_message, name, args, has_user_date):
        agent.dispatched.append((name, args))
        return agent.dispatch_results.get(name, json.dumps({"error": "not_stubbed"}))
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    async def _no_planner_state(_cid):
        return agent.planner_state

    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)

    class _Agent:
        history: list = []
        reprice_ok: set = set()
        dispatched: list = []
        dispatch_results: dict = {}
        planner_state = None
        saved: dict = {}

        def run(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    agent = _Agent()
    agent.saved = saved
    return agent


SKARDU_FLIGHTS = json.dumps({
    "search_date": "2027-06-10", "passengers": 2,
    "flights": [
        {"flight_number": "PK451", "airline": "PIA", "from": "Islamabad", "to": "Skardu",
         "depart": "2027-06-10 06:00", "arrive": "07:15", "cabin": "ECONOMY",
         "total_price_pkr": 42000},
    ],
})
SKARDU_HOTELS_INITIAL = json.dumps({
    "city": "Skardu", "nights": 2, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "Shangrila Resort", "stars": 4, "price_per_night_pkr": 15000,
         "total_stay_pkr": 30000},
    ],
})
# The provider fell back mid-session (RapidAPI quota exhausted -> Google
# Places) -- a completely different hotel set for the same city, matching
# the real, reproduced failure exactly.
SKARDU_HOTELS_FRESH = json.dumps({
    "city": "Skardu", "nights": 2, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "K2 Motel", "stars": 3.5, "price_per_night_pkr": 12000,
         "total_stay_pkr": 24000},
        {"name": "Concordia Guest House", "stars": 4.1, "price_per_night_pkr": 16000,
         "total_stay_pkr": 32000},
    ],
})


def _skardu_plan_shown_history():
    """History ending on the rendered Trip Plan card for a real
    Flight 1 / Hotel 1 pick -- Skardu has its own airport, so this plan
    carries no transfer, isolating the hotel-goes-stale case cleanly."""
    options = ts.build_options(
        [("search_flights", SKARDU_FLIGHTS), ("search_hotels", SKARDU_HOTELS_INITIAL)],
        "Skardu", passengers=2, preferred_mode="flight")
    picks = ts.merge_picks(options, "Flight 1, Hotel 1", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    assert plan.transfer is None
    options_block = ts.render_options(options)
    plan_card = ts.render_plan(plan, options, picks, "Skardu")
    history = [
        {"role": "user", "content": "Plan a trip to Skardu, 2 adults, 10 June 2027"},
        {"role": "assistant", "content": options_block},
        {"role": "user", "content": "Flight 1, Hotel 1"},
        {"role": "assistant", "content": plan_card},
    ]
    return options, picks, plan, history


def test_a_stale_hotel_pick_recovers_with_fresh_options_not_a_dead_end(agent):
    _, _, plan, history = _skardu_plan_shown_history()
    agent.history = history
    # Flight reprices fine; the hotel does NOT -- reprice_booking returns
    # None for it, exactly like a real offer_not_found.
    agent.reprice_ok = {plan.transport.get("flight_number")}
    agent.dispatch_results = {"search_hotels": SKARDU_HOTELS_FRESH}

    result = agent.run("yes")
    reply = result["response"]

    # The old broken behavior (confirmed via a live agent_failure_log row)
    # was a generic dead end naming "Missing: Hotel" with no real next step.
    assert "still missing" not in reply.lower()
    assert "missing:" not in reply.lower()
    # The new behavior: say plainly what happened, confirm nothing was
    # charged, and show the traveller something they can actually act on.
    assert "no longer available" in reply.lower()
    assert "nothing has been booked or charged" in reply.lower()
    assert "K2 Motel" in reply
    assert "Concordia Guest House" in reply
    # The stale hotel is named ONCE, in the explanation of what happened —
    # it must not also silently reappear as if it were still a selectable
    # option in the refreshed list below.
    assert reply.count("Shangrila Resort") == 1
    # No booking/payment action attached -- this is a re-offer, not a checkout.
    assert "action" not in result or result.get("action") is None

    # Deterministic: the fresh search actually ran, exactly once, for hotels.
    assert agent.dispatched == [("search_hotels", agent.dispatched[0][1])]
    assert agent.dispatched[0][1]["city"] == "Skardu"

    # The refreshed options were persisted so the traveller's next pick
    # resolves against the NEW list, not the stale one.
    assert agent.saved["planner_states"], "expected the merged options to be saved"
    saved_state = agent.saved["planner_states"][-1]
    assert saved_state["picks"] == {}   # cleared -- old indices no longer apply
    assert any(h["name"] == "K2 Motel" for h in saved_state["hotels"])

    # The reply was persisted as this turn's assistant message too.
    assert agent.saved["turns"] and agent.saved["turns"][-1] == reply


def test_a_stale_flight_pick_also_recovers(agent):
    """Symmetric with the hotel case -- the same recovery must apply to the
    transport leg, not just hotels."""
    _, _, plan, history = _skardu_plan_shown_history()
    agent.history = history
    # Hotel reprices fine; the FLIGHT does not.
    agent.reprice_ok = {plan.hotel.get("name")}
    fresh_flights = json.dumps({
        "search_date": "2027-06-10", "passengers": 2,
        "flights": [
            {"flight_number": "PK999", "airline": "PIA", "from": "Islamabad", "to": "Skardu",
             "depart": "2027-06-10 09:00", "arrive": "10:15", "cabin": "ECONOMY",
             "total_price_pkr": 45000},
        ],
    })
    agent.dispatch_results = {"search_flights": fresh_flights}

    result = agent.run("yes")
    reply = result["response"]

    assert "missing:" not in reply.lower()
    assert "no longer available" in reply.lower()
    assert "PK999" in reply
    assert agent.dispatched == [("search_flights", agent.dispatched[0][1])]
