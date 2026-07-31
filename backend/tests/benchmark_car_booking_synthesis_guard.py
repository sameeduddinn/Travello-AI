"""
Benchmark: the standalone car-booking synthesis-guard fix, before vs. after.

Drives the REAL process_message_agentic loop for the same standalone
car-booking request twice — once against a copy of agents/master_agent.py
with the guard reverted to its pre-fix form
(`if not final_text and not booking_data:`), once against today's code.
The "before" copy is produced by patching the one guard line in the module's
own source and exec'ing it into a separate module object — not a
reimplementation, the literal same file otherwise. Everything else (the loop,
the car-booking gates, dispatch_tool_with_retry) is the same real code path
both times; only the one guard line differs.

Run: python tests/benchmark_car_booking_synthesis_guard.py
"""
import asyncio
import json
import os
import sys
import time
import types

_HERE = os.path.dirname(os.path.abspath(__file__))
_BACKEND = os.path.dirname(_HERE)
if _BACKEND not in sys.path:
    sys.path.insert(0, _BACKEND)

from agents import master_agent as ma  # noqa: E402
from services.llm_service import estimate_request_tokens  # noqa: E402

_SIMULATED_LLM_LATENCY_S = 1.2

CAR_ARGS = {
    "pickup_location": "Lahore airport",
    "dropoff_location": "DHA phase 5",
    "vehicle_type": "Sedan",
    "pickup_datetime": "2026-08-20 09:00",
}
USER_MESSAGE = "book me a sedan from Lahore airport to DHA phase 5 tomorrow at 9am"


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


class _Patcher:
    def __init__(self):
        self._undo = []

    def setattr(self, obj, name, value):
        self._undo.append((obj, name, getattr(obj, name)))
        setattr(obj, name, value)

    def undo(self):
        for obj, name, old in reversed(self._undo):
            setattr(obj, name, old)


def _load_reverted_module() -> types.ModuleType:
    """A separate module object running master_agent.py with only the one
    guard line patched back to its pre-fix form."""
    with open(os.path.join(_BACKEND, "agents", "master_agent.py"), encoding="utf-8") as f:
        src = f.read()
    old = "if not final_text and not booking_data and not car_booking_data:"
    new = "if not final_text and not booking_data:"
    assert src.count(old) == 1, "guard line not found — has it moved?"
    reverted_src = src.replace(old, new, 1)

    mod = types.ModuleType("agents._master_agent_before_fix")
    mod.__file__ = os.path.join(_BACKEND, "agents", "master_agent.py")
    sys.modules["agents._master_agent_before_fix"] = mod
    exec(compile(reverted_src, "master_agent_before_fix.py", "exec"), mod.__dict__)
    return mod


def _common_patches(module, patcher: _Patcher) -> None:
    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return []

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        pass

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    patcher.setattr(module, "get_user_memory", _memory)
    patcher.setattr(module, "get_user_profile", _profile)
    patcher.setattr(module, "get_conversation_history", _history)
    patcher.setattr(module, "save_turn", _save_turn)
    patcher.setattr(module, "_log_task", _log_task)
    patcher.setattr(module, "all_providers_exhausted", lambda: False)
    patcher.setattr(module.self_improvement, "detect_user_correction", lambda _m: False)
    patcher.setattr(module.self_improvement, "log_agent_failure", _log_failure)


async def _run_against(module) -> dict:
    patcher = _Patcher()
    _common_patches(module, patcher)
    metrics = {"n": 0, "tokens": 0}

    async def _model(messages, tools=None, **kwargs):
        metrics["n"] += 1
        metrics["tokens"] += estimate_request_tokens(messages, tools)
        await asyncio.sleep(_SIMULATED_LLM_LATENCY_S)
        if metrics["n"] == 1:
            return _Msg(tool_calls=[_Call("t1", "book_car", CAR_ARGS)])
        # Only reached at all against the reverted ("before") module.
        return _Msg("Your ride is booked!")

    patcher.setattr(module, "generate_with_tools", _model)
    start = time.monotonic()
    try:
        result = await module.process_message_agentic("u1", "c1", USER_MESSAGE)
    finally:
        patcher.undo()
    elapsed = time.monotonic() - start
    return {"llm_calls": metrics["n"], "input_tokens": metrics["tokens"],
             "seconds": elapsed, "result": result}


async def main() -> None:
    reverted_mod = _load_reverted_module()

    before = await _run_against(reverted_mod)
    after = await _run_against(ma)

    assert before["result"]["action"] == "car_booking_choice"
    assert after["result"]["action"] == "car_booking_choice"
    assert before["result"]["response"] == after["result"]["response"], \
        "the fix must not change the booking response itself"

    def pct(b, a):
        return "n/a" if b == 0 else f"{(1 - a / b) * 100:.0f}% fewer"

    print("Scenario: \"%s\"" % USER_MESSAGE)
    print()
    print(f"{'metric':<22}{'before':>12}{'after':>12}{'change':>18}")
    print(f"{'LLM calls':<22}{before['llm_calls']:>12}{after['llm_calls']:>12}"
          f"{pct(before['llm_calls'], after['llm_calls']):>18}")
    print(f"{'input tokens (sum)':<22}{before['input_tokens']:>12}{after['input_tokens']:>12}"
          f"{pct(before['input_tokens'], after['input_tokens']):>18}")
    print(f"{'latency (s, sim.)':<22}{before['seconds']:>12.2f}{after['seconds']:>12.2f}"
          f"{pct(before['seconds'], after['seconds']):>18}")
    print()
    print("Booking response identical before/after:",
          before["result"]["response"] == after["result"]["response"])


if __name__ == "__main__":
    asyncio.run(main())
