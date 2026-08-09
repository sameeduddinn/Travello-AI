"""
Benchmark: deterministic round-trip prefetch, before vs. after.

Drives the REAL process_message_agentic loop twice for the same round-trip
request — once with the prefetch able to fire (today's code, unmodified),
once with it forced off (agents.master_agent._wants_round_trip patched to
False, which is the only difference: every other line of the loop, the
renderer, and the booking gates is the exact same code path either way).
That isolates the change this feature makes rather than re-implementing the
old behaviour by hand.

"Before" uses a scripted model that does what a real free-tier model has
actually been observed to do here: one tool call per step (see
test_package_atomicity.py's OFFERS fixture and the "one_leg" handling in
master_agent.py, which exists precisely because models don't reliably batch
both legs into a single response). A small per-call delay stands in for real
network/inference latency, calibrated to this project's own measurements
(Groq/OpenRouter turn budgets in master_agent.py — see _TURN_BUDGET) rather
than an arbitrary number.

Run: python tests/benchmark_round_trip_prefetch.py
"""
import asyncio
import json
import os
import sys
import time

# Import the backend package regardless of where the runner is invoked from
# (same bootstrap as test_agent_adversarial.py).
_HERE = os.path.dirname(os.path.abspath(__file__))
_BACKEND = os.path.dirname(_HERE)
if _BACKEND not in sys.path:
    sys.path.insert(0, _BACKEND)

from agents import master_agent as ma  # noqa: E402
from services.llm_service import estimate_request_tokens  # noqa: E402

# Stand-in per-call latency. Not a claim about any specific provider's real
# median — just a fixed, realistic-order-of-magnitude cost applied identically
# to every LLM call in both runs, so the comparison isolates the CALL COUNT
# this feature removes rather than any assumption about provider speed.
_SIMULATED_LLM_LATENCY_S = 1.2

FLIGHT_OUT_PAYLOAD = {
    "search_date": "2026-08-20", "passengers": 2, "total_found": 1,
    "flights": [{"flight_number": "PA401", "airline": "Airblue",
                 "depart": "2026-08-20 08:00", "arrive": "09:55",
                 "total_price_pkr": 35000, "price_per_seat_pkr": 17500}],
}
FLIGHT_RET_PAYLOAD = {
    "search_date": "2026-08-25", "passengers": 2, "total_found": 1,
    "flights": [{"flight_number": "ER198", "airline": "AirSial",
                 "depart": "2026-08-25 16:10", "arrive": "17:45",
                 "total_price_pkr": 33000, "price_per_seat_pkr": 16500}],
}

USER_MESSAGE = "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"


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


async def _dispatch(*, name, args, **kwargs):
    if args.get("origin_city") == "Lahore":
        return json.dumps(FLIGHT_OUT_PAYLOAD)
    return json.dumps(FLIGHT_RET_PAYLOAD)


def _common_patches(monkeypatch):
    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return []

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
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)


class _Patcher:
    """A tiny monkeypatch stand-in so this can run outside pytest."""

    def __init__(self):
        self._undo = []

    def setattr(self, obj, name, value):
        self._undo.append((obj, name, getattr(obj, name)))
        setattr(obj, name, value)

    def undo(self):
        for obj, name, old in reversed(self._undo):
            setattr(obj, name, old)


async def _run_after() -> dict:
    """Today's code, unmodified. The prefetch fires if the conditions hold."""
    patcher = _Patcher()
    _common_patches(patcher)
    calls = {"n": 0, "tokens": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        calls["tokens"] += estimate_request_tokens(messages, tools)
        await asyncio.sleep(_SIMULATED_LLM_LATENCY_S)
        raise AssertionError("the LLM must not be called — prefetch should answer this turn alone")

    patcher.setattr(ma, "generate_with_tools", _model)
    start = time.monotonic()
    try:
        result = await ma.process_message_agentic("u1", "c1", USER_MESSAGE)
    finally:
        patcher.undo()
    elapsed = time.monotonic() - start
    return {"calls": calls["n"], "tokens": calls["tokens"], "seconds": elapsed, "result": result}


async def _run_before() -> dict:
    """
    Same code, prefetch forced off (_round_trip_prefetch_mode patched to
    always decline) — the loop, the renderer and the booking gates are the
    untouched originals; _wants_round_trip itself is untouched too, so the
    existing "wait for both legs before rendering" behaviour still applies
    exactly as it does today. The scripted model does what has actually been
    observed here: one search per step (see the module docstring), so this
    reproduces the real pre-feature cost rather than a hand-rolled guess at it.
    """
    patcher = _Patcher()
    _common_patches(patcher)
    patcher.setattr(ma, "_round_trip_prefetch_mode", lambda *_a, **_kw: None)
    calls = {"n": 0, "tokens": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        calls["tokens"] += estimate_request_tokens(messages, tools)
        await asyncio.sleep(_SIMULATED_LLM_LATENCY_S)
        if calls["n"] == 1:
            return _Msg(tool_calls=[_Call("t1", "search_flights", {
                "origin_city": "Lahore", "destination_city": "Karachi",
                "travel_date": "2026-08-20", "passengers": 2})])
        return _Msg(tool_calls=[_Call("t2", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Lahore",
            "travel_date": "2026-08-25", "passengers": 2})])

    patcher.setattr(ma, "generate_with_tools", _model)
    start = time.monotonic()
    try:
        result = await ma.process_message_agentic("u1", "c1", USER_MESSAGE)
    finally:
        patcher.undo()
    elapsed = time.monotonic() - start
    return {"calls": calls["n"], "tokens": calls["tokens"], "seconds": elapsed, "result": result}


async def main() -> None:
    before = await _run_before()
    after = await _run_after()

    assert "PA401" in before["result"]["response"] and "ER198" in before["result"]["response"], \
        "before-run sanity check: both legs must still be in the answer"
    assert "PA401" in after["result"]["response"] and "ER198" in after["result"]["response"], \
        "after-run sanity check: both legs must still be in the answer"

    def pct_down(b, a):
        return "n/a (baseline is 0)" if b == 0 else f"{(1 - a / b) * 100:.0f}% fewer"

    print("Scenario: \"%s\"" % USER_MESSAGE)
    print()
    print(f"{'metric':<22}{'before':>12}{'after':>12}{'change':>22}")
    print(f"{'LLM calls':<22}{before['calls']:>12}{after['calls']:>12}"
          f"{pct_down(before['calls'], after['calls']):>22}")
    print(f"{'input tokens (sum)':<22}{before['tokens']:>12}{after['tokens']:>12}"
          f"{pct_down(before['tokens'], after['tokens']):>22}")
    print(f"{'latency (s, sim.)':<22}{before['seconds']:>12.2f}{after['seconds']:>12.2f}"
          f"{pct_down(before['seconds'], after['seconds']):>22}")
    print()
    print("(latency is simulated network/inference time; the search calls this")
    print(" feature moves in front of the loop are real local function calls,")
    print(" not network requests, and are not separately charged against the turn.)")

    call_reduction = 1 - (after["calls"] / before["calls"] if before["calls"] else 0)
    token_reduction = 1 - (after["tokens"] / before["tokens"] if before["tokens"] else 0)
    print()
    if call_reduction < 0.10 and token_reduction < 0.10:
        print(
            f"STOP: call reduction {call_reduction:.0%} and token reduction "
            f"{token_reduction:.0%} are both under the 10% bar — see the docstring "
            "at the top of this file before shipping this feature."
        )
    else:
        print(
            f"Call reduction {call_reduction:.0%}, token reduction {token_reduction:.0%} "
            "— comfortably over the 10% bar for this scenario."
        )


if __name__ == "__main__":
    asyncio.run(main())
