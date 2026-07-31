"""
Production-style benchmark: 12 representative scenarios, before vs. after this
session's three optimizations, run through the REAL process_message_agentic
loop (real booking gates, real self_improvement.dispatch_tool_with_retry call
sites — only the two mechanisms below are toggled).

WHAT "BEFORE" MEANS, PRECISELY
    "Before" = current code with exactly two functions reverted to their
    committed-HEAD behaviour via monkeypatch — nothing else:

      1. agents/prompt_builder._looks_like_offer_list reverted to
         `bool(_OFFER_LIST_RE.search(text or ""))` — the pre-fix version that
         called ANY numbered list an offer list, including the assistant's own
         numbered clarifying questions (see `git diff` on this function).
      2. agents/master_agent._round_trip_prefetch_mode reverted to always
         return None (the prefetch mechanism did not exist before this
         session).

    The third named optimization — "reduced the system prompt" — is already
    committed (HEAD), so it is present in BOTH before and after here; it is
    validated separately, statically, in the "prompt selection" note per
    scenario (all tools sent vs. tools actually selected), which needs no
    model at all and does not depend on this before/after toggle.

"Before" and "after" get the SAME user message, SAME history, SAME tool
fixtures. Where the scripted model's own actions must legitimately differ
(because the tools it's holding differ, e.g. prepare_booking not being
offered), that difference is called out per scenario and is itself part of
what's being measured, not an assumption smuggled in.

Every number below comes from actually running agents.master_agent
.process_message_agentic — nothing is hand-calculated.

Run: python tests/benchmark_production_scenarios.py
"""
import asyncio
import json
import os
import sys
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
_BACKEND = os.path.dirname(_HERE)
if _BACKEND not in sys.path:
    sys.path.insert(0, _BACKEND)

from agents import master_agent as ma  # noqa: E402
from agents import prompt_builder as pb  # noqa: E402
from services.llm_service import estimate_request_tokens, estimate_tokens  # noqa: E402

_SIMULATED_LLM_LATENCY_S = 1.2
_SIMULATED_TOOL_LATENCY_S = 0.15


def _old_looks_like_offer_list(text: str) -> bool:
    """The exact pre-fix body of prompt_builder._looks_like_offer_list."""
    return bool(pb._OFFER_LIST_RE.search(text or ""))


# ── Scripted model plumbing ───────────────────────────────────────────────────

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


def _make_model(turns, metrics):
    state = {"i": 0}

    async def _model(messages, tools=None, **kwargs):
        await asyncio.sleep(_SIMULATED_LLM_LATENCY_S)
        i = state["i"]
        state["i"] += 1
        msg = turns[i] if i < len(turns) else _Msg("(nothing more to say)")
        req_tokens = estimate_request_tokens(messages, tools)
        metrics["llm_calls"] += 1
        metrics["input_tokens"].append(req_tokens)
        out_text = msg.content or ""
        out_tokens = estimate_tokens(out_text) if out_text else 0
        if msg.tool_calls:
            calls_json = json.dumps([
                {"name": tc.function.name, "arguments": tc.function.arguments}
                for tc in msg.tool_calls
            ])
            out_tokens += estimate_tokens(calls_json, json_like=True)
        metrics["output_tokens"].append(out_tokens)
        return msg

    return _model


def _make_dispatch(handler, metrics):
    async def _dispatch(*, name, args, **kwargs):
        await asyncio.sleep(_SIMULATED_TOOL_LATENCY_S)
        result = handler(name, args)
        metrics["tool_calls"] += 1
        metrics["tool_payload_bytes"] += len(result.encode("utf-8"))
        return result

    return _dispatch


def _common_patches(patcher: _Patcher, history: list, reprice_ok: set):
    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return list(history)

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        pass

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    async def _reprice(bd):
        ident = bd.get("flight_number") or bd.get("train_name") or bd.get("hotel_name")
        if ident in reprice_ok:
            verified = dict(bd)
            verified["total_price_pkr"] = bd.get("total_price_pkr") or 1000
            return verified
        return None

    patcher.setattr(ma, "get_user_memory", _memory)
    patcher.setattr(ma, "get_user_profile", _profile)
    patcher.setattr(ma, "get_conversation_history", _history)
    patcher.setattr(ma, "save_turn", _save_turn)
    patcher.setattr(ma, "_log_task", _log_task)
    patcher.setattr(ma, "all_providers_exhausted", lambda: False)
    patcher.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    patcher.setattr(ma.self_improvement, "log_agent_failure", _log_failure)
    patcher.setattr(ma, "reprice_booking", _reprice)


async def _run(user_message, history, turns, dispatch_handler, reprice_ok, *, before: bool):
    """One process_message_agentic call, fully instrumented."""
    patcher = _Patcher()
    metrics = {"llm_calls": 0, "input_tokens": [], "output_tokens": [],
               "tool_calls": 0, "tool_payload_bytes": 0}
    _common_patches(patcher, history, reprice_ok)
    if before:
        patcher.setattr(pb, "_looks_like_offer_list", _old_looks_like_offer_list)
        patcher.setattr(ma, "_round_trip_prefetch_mode", lambda *_a, **_kw: None)
    patcher.setattr(ma, "generate_with_tools", _make_model(turns, metrics))
    patcher.setattr(ma.self_improvement, "dispatch_tool_with_retry",
                     _make_dispatch(dispatch_handler, metrics))
    start = time.monotonic()
    try:
        result = await ma.process_message_agentic("u1", "c1", user_message)
    finally:
        patcher.undo()
    elapsed = time.monotonic() - start
    return {
        "llm_calls": metrics["llm_calls"],
        "input_tokens_total": sum(metrics["input_tokens"]),
        "input_tokens_max": max(metrics["input_tokens"], default=0),
        "output_tokens_total": sum(metrics["output_tokens"]),
        "output_tokens_max": max(metrics["output_tokens"], default=0),
        "tool_calls": metrics["tool_calls"],
        "tool_payload_bytes": metrics["tool_payload_bytes"],
        "latency_s": elapsed,
        "response": result.get("response", ""),
        "action": result.get("action"),
    }


# ── Fixtures ───────────────────────────────────────────────────────────────────

FLIGHT_OUT = {
    "search_date": "2026-08-20", "passengers": 2, "total_found": 1,
    "flights": [{"flight_number": "PA401", "airline": "Airblue",
                 "depart": "2026-08-20 08:00", "arrive": "09:55",
                 "total_price_pkr": 35000, "price_per_seat_pkr": 17500}],
}
FLIGHT_RET = {
    "search_date": "2026-08-25", "passengers": 2, "total_found": 1,
    "flights": [{"flight_number": "ER198", "airline": "AirSial",
                 "depart": "2026-08-25 16:10", "arrive": "17:45",
                 "total_price_pkr": 33000, "price_per_seat_pkr": 16500}],
}
FLIGHT_ONEWAY = {
    "search_date": "2026-08-20", "passengers": 1, "total_found": 1,
    "flights": [{"flight_number": "PK100", "airline": "PIA",
                 "depart": "2026-08-20 10:00", "arrive": "11:00",
                 "total_price_pkr": 20000, "price_per_seat_pkr": 20000}],
}
TRAIN_OUT = {
    "search_date": "2026-08-20", "passengers": 2, "total_found": 1,
    "trains": [{"train_name": "Tezgam", "train_number": "1", "depart": "06:00", "arrive": "20:00",
                "classes": [{"class": "AC Standard", "total_price_pkr": 8000, "price_per_seat_pkr": 4000}]}],
}
TRAIN_RET = {
    "search_date": "2026-08-25", "passengers": 2, "total_found": 1,
    "trains": [{"train_name": "Khyber Mail", "train_number": "2", "depart": "07:00", "arrive": "21:00",
                "classes": [{"class": "AC Standard", "total_price_pkr": 8200, "price_per_seat_pkr": 4100}]}],
}
TRAIN_ONEWAY = {
    "search_date": "2026-08-20", "passengers": 1, "total_found": 1,
    "trains": [{"train_name": "Green Line", "train_number": "3", "depart": "09:00", "arrive": "22:00",
                "classes": [{"class": "Economy", "total_price_pkr": 3000, "price_per_seat_pkr": 3000}]}],
}
HOTEL_PAYLOAD = {
    "nights": 5, "hotels": [{"name": "Pearl Continental", "stars": 5,
                              "price_per_night_pkr": 12000, "total_stay_pkr": 60000}],
}
HEALTHCARE_PAYLOAD = {
    "location": "Gulberg, Lahore",
    "pharmacies": [{"name": "Servaid Pharmacy", "distance_km": 0.8, "phone": "042-111-778-724",
                     "address": "MM Alam Road, Gulberg"}],
    "emergency_numbers": "Rescue 1122 · Ambulance 115 · Police 15",
}

FLIGHT_OUT_BOOKING = {
    "booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
    "travel_date": "2026-08-20", "flight_number": "PA401", "adults": 2,
    "cabin_class": "ECONOMY", "total_price_pkr": 35000,
}
FLIGHT_BACK_BOOKING = {
    "booking_type": "flight", "origin": "Karachi", "destination": "Lahore",
    "travel_date": "2026-08-25", "flight_number": "ER198", "adults": 2,
    "cabin_class": "ECONOMY", "total_price_pkr": 33000,
}
HOTEL_BOOKING = {
    "booking_type": "hotel", "destination": "Karachi", "hotel_name": "Pearl Continental",
    "check_in": "2026-08-20", "check_out": "2026-08-25", "guests": 2, "rooms": 1,
    "total_price_pkr": 60000,
}
FLIGHT_ONEWAY_BOOKING = {
    "booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
    "travel_date": "2026-08-20", "flight_number": "PK100", "adults": 1,
    "cabin_class": "ECONOMY", "total_price_pkr": 20000,
}

RENDERED_ONEWAY_LIST = (
    "1. **PIA PK100** · 10:00 → 11:00 — **PKR 20,000**\n\n"
    "Just tell me the number of the one you want and I'll set it up."
)
RENDERED_ROUNDTRIP_LIST = (
    "**Outbound**\n1. **Airblue PA401** · 08:00 → 09:55 — PKR 17,500 per person × 2 = **PKR 35,000 total**\n"
    "2. **PIA PK304** · 11:20 → 13:00 — PKR 19,000 per person × 2 = **PKR 38,000 total**\n\n"
    "**Return**\n1. **AirSial ER198** · 16:10 → 17:45 — PKR 16,500 per person × 2 = **PKR 33,000 total**\n"
    "2. **PIA PK305** · 09:00 → 10:35 — PKR 18,000 per person × 2 = **PKR 36,000 total**\n\n"
    "Tell me which one you'd like for each leg (for example \"1 for outbound and 2 for return\") "
    "and I'll set the booking up — both legs together, one payment."
)
CLARIFYING_QUESTION = (
    "Sure, Hunza sounds lovely! A few quick things:\n"
    "1. What dates are you thinking?\n"
    "2. How many travellers?\n"
    "3. Would you like a flight to Gilgit, or are you driving up?"
)


def _route_handler(payloads_by_key):
    def handler(name, args):
        key = (args.get("origin_city"), args.get("destination_city"))
        payload = payloads_by_key.get(key)
        if payload is None:
            return json.dumps({"error": "no_fixture_for_route", "key": key})
        return json.dumps(payload)
    return handler


def _single_payload_handler(payload):
    def handler(name, args):
        return json.dumps(payload)
    return handler


# ── Scenario definitions ───────────────────────────────────────────────────────
# Each entry: (name, user_message, history, before_turns, after_turns,
#              dispatch_handler, reprice_ok, note)

SCENARIOS = []


def scenario(name, user_message, history, before_turns, after_turns, handler,
             reprice_ok: "set[str] | frozenset[str]" = frozenset(), note=""):
    SCENARIOS.append({
        "name": name, "user_message": user_message, "history": history,
        "before_turns": before_turns, "after_turns": after_turns,
        "handler": handler, "reprice_ok": reprice_ok, "note": note,
    })


# 1. One-way flight search — control (unaffected by either fix)
scenario(
    "One-way flight search",
    "flights from Lahore to Karachi on 2026-08-20 for 1", [],
    before_turns=[_Msg(tool_calls=[_Call("t1", "search_flights", {
        "origin_city": "Lahore", "destination_city": "Karachi",
        "travel_date": "2026-08-20", "passengers": 1})])],
    after_turns=[_Msg(tool_calls=[_Call("t1", "search_flights", {
        "origin_city": "Lahore", "destination_city": "Karachi",
        "travel_date": "2026-08-20", "passengers": 1})])],
    handler=_route_handler({("Lahore", "Karachi"): FLIGHT_ONEWAY}),
    note="Control — no round-trip/exposure signal; deterministic renderer already handled this before this session.",
)

# 2. Round-trip flight search (no budget) — the core prefetch scenario
scenario(
    "Round-trip flight search",
    "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people", [],
    before_turns=[
        _Msg(tool_calls=[_Call("t1", "search_flights", {
            "origin_city": "Lahore", "destination_city": "Karachi",
            "travel_date": "2026-08-20", "passengers": 2})]),
        _Msg(tool_calls=[_Call("t2", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Lahore",
            "travel_date": "2026-08-25", "passengers": 2})]),
    ],
    after_turns=[],
    handler=_route_handler({("Lahore", "Karachi"): FLIGHT_OUT, ("Karachi", "Lahore"): FLIGHT_RET}),
    note="Prefetch fires — both legs fetched in code before any LLM call.",
)

# 3. Round-trip flight search with budget
BUDGET_FLIGHT_OUT = dict(FLIGHT_OUT, budget_note="1 of 1 within your PKR 150,000 budget.")
BUDGET_FLIGHT_RET = dict(FLIGHT_RET, budget_note="1 of 1 within your PKR 150,000 budget.")
BUDGET_PROSE = (
    "Both legs fit your PKR 150,000 budget for 2 travellers: Airblue PA401 outbound "
    "(PKR 35,000) and AirSial ER198 return (PKR 33,000), PKR 68,000 total — well under budget."
)
scenario(
    "Round-trip flight search with budget",
    "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, budget 150000, for 2 people", [],
    before_turns=[
        _Msg(tool_calls=[_Call("t1", "search_flights", {
            "origin_city": "Lahore", "destination_city": "Karachi", "travel_date": "2026-08-20",
            "passengers": 2, "max_budget_pkr": 150000})]),
        _Msg(tool_calls=[_Call("t2", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Lahore", "travel_date": "2026-08-25",
            "passengers": 2, "max_budget_pkr": 150000})]),
        _Msg(BUDGET_PROSE),
    ],
    after_turns=[_Msg(BUDGET_PROSE)],
    handler=_route_handler({("Lahore", "Karachi"): BUDGET_FLIGHT_OUT, ("Karachi", "Lahore"): BUDGET_FLIGHT_RET}),
    note="'budget' keyword blocks the deterministic render either way (should_render's own "
         "_NEEDS_PROSE_RE) — prefetch still removes the two search calls, leaving one prose call.",
)

# 4. Round-trip booking (pick after an already-shown list) — control
scenario(
    "Round-trip booking",
    "1 for outbound and 2 for return",
    [{"role": "user", "content": "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"},
     {"role": "assistant", "content": RENDERED_ROUNDTRIP_LIST}],
    before_turns=[_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT_BOOKING),
        _Call("b", "prepare_booking", FLIGHT_BACK_BOOKING),
    ])],
    after_turns=[_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT_BOOKING),
        _Call("b", "prepare_booking", FLIGHT_BACK_BOOKING),
    ])],
    handler=_route_handler({}),
    reprice_ok={"PA401", "ER198"},
    note="Control — a REAL priced list is correctly recognised as offers both before and after; "
         "pick_hint suppresses prefetch either way (no re-search).",
)

# 5. Flight + hotel package (round trip + hotel)
def _package_handler(name, args):
    if name == "search_hotels":
        return json.dumps(HOTEL_PAYLOAD)
    key = (args.get("origin_city"), args.get("destination_city"))
    payload = {("Lahore", "Karachi"): FLIGHT_OUT, ("Karachi", "Lahore"): FLIGHT_RET}.get(key)
    return json.dumps(payload) if payload else json.dumps({"error": "no_fixture"})


scenario(
    "Flight + hotel package",
    "book me a round trip flight from Lahore to Karachi and a hotel there, 2026-08-20 to 2026-08-25, for 2 people",
    [],
    before_turns=[
        # _MAX_TOOL_STEPS is 3, so the return-leg search and the hotel search
        # are batched into one step (two tool_calls in one reply) — this is
        # also the exact shape that needed the master_agent.py fix above (two
        # SAME-tool flight results must not render early and strand the hotel
        # search); this scenario now exercises that fixed path for real.
        _Msg(tool_calls=[_Call("t1", "search_flights", {
            "origin_city": "Lahore", "destination_city": "Karachi",
            "travel_date": "2026-08-20", "passengers": 2})]),
        _Msg(tool_calls=[
            _Call("t2", "search_flights", {
                "origin_city": "Karachi", "destination_city": "Lahore",
                "travel_date": "2026-08-25", "passengers": 2}),
            _Call("t3", "search_hotels", {
                "destination_city": "Karachi", "check_in": "2026-08-20",
                "check_out": "2026-08-25", "guests": 2, "rooms": 1}),
        ]),
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT_BOOKING),
            _Call("b", "prepare_booking", FLIGHT_BACK_BOOKING),
            _Call("c", "prepare_booking", HOTEL_BOOKING),
        ]),
    ],
    after_turns=[
        _Msg(tool_calls=[_Call("t1", "search_hotels", {
            "destination_city": "Karachi", "check_in": "2026-08-20",
            "check_out": "2026-08-25", "guests": 2, "rooms": 1})]),
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT_BOOKING),
            _Call("b", "prepare_booking", FLIGHT_BACK_BOOKING),
            _Call("c", "prepare_booking", HOTEL_BOOKING),
        ]),
    ],
    handler=_package_handler,
    reprice_ok={"PA401", "ER198", "Pearl Continental"},
    note="Prefetch removes the two flight-search calls; the model still drives the hotel search "
         "and the 3-way atomic booking gate itself — package logic untouched.",
)

# 6. One-way train search — control
scenario(
    "One-way train search",
    "train from Lahore to Karachi on 2026-08-20 for 1", [],
    before_turns=[_Msg(tool_calls=[_Call("t1", "search_trains", {
        "origin_city": "Lahore", "destination_city": "Karachi",
        "travel_date": "2026-08-20", "passengers": 1})])],
    after_turns=[_Msg(tool_calls=[_Call("t1", "search_trains", {
        "origin_city": "Lahore", "destination_city": "Karachi",
        "travel_date": "2026-08-20", "passengers": 1})])],
    handler=_route_handler({("Lahore", "Karachi"): TRAIN_ONEWAY}),
    note="Control — no round-trip/exposure signal.",
)

# 7. Round-trip train search
scenario(
    "Round-trip train search",
    "round trip train from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people", [],
    before_turns=[
        _Msg(tool_calls=[_Call("t1", "search_trains", {
            "origin_city": "Lahore", "destination_city": "Karachi",
            "travel_date": "2026-08-20", "passengers": 2})]),
        _Msg(tool_calls=[_Call("t2", "search_trains", {
            "origin_city": "Karachi", "destination_city": "Lahore",
            "travel_date": "2026-08-25", "passengers": 2})]),
    ],
    after_turns=[],
    handler=_route_handler({("Lahore", "Karachi"): TRAIN_OUT, ("Karachi", "Lahore"): TRAIN_RET}),
    note="Prefetch fires with mode=search_trains (mode detection correctly avoids the "
         "'round trip' / _FLIGHT_RE collision).",
)

# 8. Hotel search — control
scenario(
    "Hotel search",
    "hotels in Karachi from 2026-08-20 to 2026-08-25 for 2 guests", [],
    before_turns=[_Msg(tool_calls=[_Call("t1", "search_hotels", {
        "destination_city": "Karachi", "check_in": "2026-08-20",
        "check_out": "2026-08-25", "guests": 2, "rooms": 1})])],
    after_turns=[_Msg(tool_calls=[_Call("t1", "search_hotels", {
        "destination_city": "Karachi", "check_in": "2026-08-20",
        "check_out": "2026-08-25", "guests": 2, "rooms": 1})])],
    handler=_single_payload_handler(HOTEL_PAYLOAD),
    note="Control — hotels are outside the prefetch mechanism's scope (no round-trip concept).",
)

# 9. Healthcare search — control
scenario(
    "Healthcare search",
    "are there any pharmacies open near Gulberg, Lahore right now", [],
    before_turns=[_Msg(tool_calls=[_Call("t1", "find_healthcare", {
        "location": "Gulberg, Lahore"})])],
    after_turns=[_Msg(tool_calls=[_Call("t1", "find_healthcare", {
        "location": "Gulberg, Lahore"})])],
    handler=_single_payload_handler(HEALTHCARE_PAYLOAD),
    note="Control — not a medical emergency (checked separately below), so it takes the "
         "ordinary find_healthcare tool path, unaffected by either fix.",
)

# 10. Airport transportation (standalone car) — control
CAR_ARGS = {
    "pickup_location": "Lahore airport",
    "dropoff_location": "DHA phase 5", "vehicle_type": "Sedan",
    "pickup_datetime": "2026-08-20 09:00",
}
scenario(
    "Airport transportation",
    "book me a sedan from Lahore airport to DHA phase 5 tomorrow at 9am", [],
    before_turns=[_Msg(tool_calls=[_Call("t1", "book_car", CAR_ARGS)])],
    after_turns=[_Msg(tool_calls=[_Call("t1", "book_car", CAR_ARGS)])],
    handler=_single_payload_handler({}),  # book_car never reaches dispatch_tool_with_retry
    note="Control — book_car is gated deterministically in the orchestrator itself, never "
         "via dispatch_tool_with_retry, so neither fix touches it (0 tool dispatches expected).",
)

# 11. Ambiguous travel request — the real prepare_booking-exposure bug
scenario(
    "Ambiguous travel request",
    "2 people",
    [{"role": "user", "content": "I want to go to Hunza"},
     {"role": "assistant", "content": CLARIFYING_QUESTION}],
    # BEFORE: prepare_booking is wrongly offered (the clarifying question's
    # numbering is mistaken for an offer list), so a plausible bad model
    # reply is a premature, field-incomplete prepare_booking attempt — it
    # fails the missing-fields gate, costing a second call to actually ask.
    before_turns=[
        _Msg(tool_calls=[_Call("t1", "prepare_booking", {"booking_type": "flight"})]),
        _Msg("Got it, 2 travellers! And what dates did you have in mind for Hunza?"),
    ],
    # AFTER: prepare_booking correctly isn't offered, so the model's only
    # sane move is to continue gathering details directly.
    after_turns=[_Msg("Got it, 2 travellers! And what dates did you have in mind for Hunza?")],
    handler=_single_payload_handler({}),
    note="THE prepare_booking-exposure bug this scenario exists to catch: a numbered "
         "CLARIFYING QUESTION, not a priced offer list. Before: _looks_like_offer_list "
         "(pre-fix) treats it as offers -> prepare_booking shipped -> model attempts it "
         "-> missing-fields gate rejects -> a second call to actually ask. After: correctly "
         "not offered, one call.",
)

# 12. Follow-up booking after a previous one-way search — control
scenario(
    "Follow-up booking after previous search",
    "book option 1",
    [{"role": "user", "content": "flights from Lahore to Karachi on 2026-08-20 for 1"},
     {"role": "assistant", "content": RENDERED_ONEWAY_LIST}],
    before_turns=[_Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT_ONEWAY_BOOKING)])],
    after_turns=[_Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT_ONEWAY_BOOKING)])],
    handler=_route_handler({}),
    reprice_ok={"PK100"},
    note="Control — a real one-way priced list is correctly recognised as offers both "
         "before and after.",
)


# ── Runner ──────────────────────────────────────────────────────────────────────

async def main() -> None:
    rows = []
    for sc in SCENARIOS:
        before = await _run(sc["user_message"], sc["history"], sc["before_turns"],
                             sc["handler"], sc["reprice_ok"], before=True)
        after = await _run(sc["user_message"], sc["history"], sc["after_turns"],
                            sc["handler"], sc["reprice_ok"], before=False)
        rows.append({"name": sc["name"], "note": sc["note"], "before": before, "after": after})

    # Sanity: both runs must have produced a real, non-empty answer.
    for r in rows:
        assert r["before"]["response"], f"{r['name']}: before produced no response"
        assert r["after"]["response"], f"{r['name']}: after produced no response"

    print(json.dumps(rows, indent=2, default=str))


if __name__ == "__main__":
    asyncio.run(main())
