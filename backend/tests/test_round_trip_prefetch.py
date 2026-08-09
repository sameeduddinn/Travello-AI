"""
Deterministic round-trip prefetch.

A round trip with BOTH dates already known ("round trip flight, Lahore to
Karachi, 2026-08-20 to 2026-08-25, 2 people") used to cost the model a step
just to search each leg before it could even look at a booking. Every fact
needed to run both searches (route, both dates, party size) is already
derivable from the conversation in code (agents/conversation_state.derive_state)
once _wants_round_trip is true, so agents/master_agent.process_message_agentic
now runs both searches itself, up front, and seeds the conversation with the
results exactly as if the model had already made that tool call.

These drive the REAL process_message_agentic loop with a scripted model (same
harness as test_package_atomicity.py), so they exercise the actual gate, not a
reimplementation of it. Where the LLM must never be called at all, the scripted
model raises if invoked.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma


# ── Scripted model (same shape as test_package_atomicity.py) ─────────────────

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


def _script(*turns):
    state = {"i": 0}

    async def _fake(messages, tools=None, **kwargs):
        i = state["i"]
        state["i"] += 1
        return turns[i] if i < len(turns) else _Msg("(nothing more to say)")

    return _fake


async def _never(messages, tools=None, **kwargs):
    raise AssertionError("the LLM must not be called for this turn")


# ── Fixtures: flight payloads keyed by (origin, destination) ─────────────────

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
TRAIN_OUT_PAYLOAD = {
    "search_date": "2026-08-20", "passengers": 2, "total_found": 1,
    "trains": [{"train_name": "Tezgam", "train_number": "1",
                "depart": "06:00", "arrive": "20:00",
                "classes": [{"class": "AC Standard", "total_price_pkr": 8000,
                             "price_per_seat_pkr": 4000}]}],
}
TRAIN_RET_PAYLOAD = {
    "search_date": "2026-08-25", "passengers": 2, "total_found": 1,
    "trains": [{"train_name": "Khyber Mail", "train_number": "2",
                "depart": "07:00", "arrive": "21:00",
                "classes": [{"class": "AC Standard", "total_price_pkr": 8200,
                             "price_per_seat_pkr": 4100}]}],
}
HOTEL_PAYLOAD = {
    "nights": 5, "hotels": [{"name": "Pearl Continental", "stars": 5,
                              "price_per_night_pkr": 12000, "total_stay_pkr": 60000}],
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
HOTEL = {
    "booking_type": "hotel", "destination": "Karachi", "hotel_name": "Pearl Continental",
    "check_in": "2026-08-20", "check_out": "2026-08-25", "guests": 2, "rooms": 1,
    "total_price_pkr": 60000,
}


class _RouteDispatcher:
    """
    A dispatch_tool_with_retry stand-in that answers from `payloads`, keyed by
    (origin_city, destination_city), and records every call it received.
    """
    def __init__(self, payloads: dict):
        self.payloads = payloads
        self.calls: list[dict] = []

    async def __call__(self, *, name, args, **kwargs):
        self.calls.append({"name": name, "args": dict(args)})
        key = (args.get("origin_city"), args.get("destination_city"))
        payload = self.payloads.get(key)
        if payload is None:
            return json.dumps({"error": "no_such_route_in_test_fixture", "key": key})
        return json.dumps(payload)


def _by_route(payloads: dict) -> _RouteDispatcher:
    return _RouteDispatcher(payloads)


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


# ── 1. One-way trips: prefetch must never fire ───────────────────────────────

def test_a_one_way_search_still_costs_exactly_one_llm_call(agent, monkeypatch):
    """No round-trip language at all — behaviour must be byte-identical to
    before this feature existed: one model call, deterministic render."""
    calls = {"n": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        return _Msg(tool_calls=[_Call("t1", "search_flights", {
            "origin_city": "Lahore", "destination_city": "Karachi",
            "travel_date": "2026-08-20", "passengers": 1})])

    dispatch = _by_route({("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD})
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    result = agent.run("flights from Lahore to Karachi on 2026-08-20 for 1")
    assert calls["n"] == 1
    assert len(dispatch.calls) == 1, "a one-way search must trigger exactly one search"
    assert "PA401" in result["response"]


def test_a_one_way_mention_of_return_word_alone_does_not_prefetch(agent, monkeypatch):
    """'return' can appear without meaning round-trip travel; only the
    dedicated round-trip phrasing should ever trigger this."""
    calls = {"n": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        return _Msg("Sure — can you tell me your travel date?")

    dispatch = _by_route({})
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    agent.run("please return my earlier answer, I meant Lahore not Karachi")
    assert len(dispatch.calls) == 0


# ── 2. Round trips: the core feature ─────────────────────────────────────────

def test_a_complete_round_trip_flight_request_costs_zero_llm_calls(agent, monkeypatch):
    dispatch = _by_route({
        ("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD,
        ("Karachi", "Lahore"): FLIGHT_RET_PAYLOAD,
    })
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _never)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    result = agent.run(
        "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
    )
    assert len(dispatch.calls) == 2
    assert dispatch.calls[0]["args"]["origin_city"] == "Lahore"
    assert dispatch.calls[1]["args"]["origin_city"] == "Karachi"
    assert "PA401" in result["response"] and "Outbound" in result["response"]
    assert "ER198" in result["response"] and "Return" in result["response"]
    assert result.get("action") is None, "a search must never carry a payment action"


def test_a_complete_round_trip_train_request_prefetches_trains_not_flights(agent, monkeypatch):
    dispatch = _by_route({
        ("Lahore", "Karachi"): TRAIN_OUT_PAYLOAD,
        ("Karachi", "Lahore"): TRAIN_RET_PAYLOAD,
    })
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _never)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    result = agent.run(
        "round trip train from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
    )
    assert all(c["name"] == "search_trains" for c in dispatch.calls)
    assert "Tezgam" in result["response"] and "Khyber Mail" in result["response"]


def test_an_ambiguous_mode_falls_back_to_the_model_unaffected(agent, monkeypatch):
    """Neither 'flight' nor 'train' was said — the prefetch must not guess."""
    calls = {"n": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        if calls["n"] == 1:
            return _Msg(tool_calls=[_Call("t1", "search_flights", {
                "origin_city": "Lahore", "destination_city": "Karachi",
                "travel_date": "2026-08-20", "passengers": 2})])
        return _Msg(tool_calls=[_Call("t2", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Lahore",
            "travel_date": "2026-08-25", "passengers": 2})])

    dispatch = _by_route({
        ("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD,
        ("Karachi", "Lahore"): FLIGHT_RET_PAYLOAD,
    })
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    result = agent.run("round trip Lahore to Karachi, 2026-08-20 to 2026-08-25 for 2 people")
    assert calls["n"] == 2, "unaffected: the model still drives an ambiguous-mode round trip"
    assert "PA401" in result["response"]


# ── 3. Packages: must still complete correctly, atomic gate untouched ────────

def test_a_flight_plus_hotel_round_trip_package_still_commits_atomically(agent, monkeypatch):
    """
    A hotel mentioned alongside a round trip means this is a package, not a
    plain search — the two prefetched legs are only PART of the answer, so the
    fast (zero-call) path must not fire; the model still drives the hotel
    search and the atomic prepare_booking gate, exactly as before.
    """
    dispatch = _by_route({
        ("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD,
        ("Karachi", "Lahore"): FLIGHT_RET_PAYLOAD,
    })
    seen_messages: list[list[dict]] = []

    async def _model(messages, tools=None, **kwargs):
        seen_messages.append(messages)
        if len(seen_messages) == 1:
            # The model still has to search the hotel itself — the fast path
            # must have declined given the hotel is also on the table.
            return _Msg(tool_calls=[_Call("h1", "search_hotels", {
                "destination_city": "Karachi", "check_in": "2026-08-20",
                "check_out": "2026-08-25", "guests": 2, "rooms": 1})])
        return _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),
            _Call("c", "prepare_booking", HOTEL),
        ])

    async def _hotel_dispatch(*, name, args, **kwargs):
        if name == "search_hotels":
            return json.dumps(HOTEL_PAYLOAD)
        return await dispatch(name=name, args=args, **kwargs)

    agent.history = []
    agent.reprice_ok = {"PA401", "ER198", "Pearl Continental"}
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _hotel_dispatch)

    result = agent.run(
        "book me a round trip flight from Lahore to Karachi and a hotel there, "
        "2026-08-20 to 2026-08-25, for 2 people"
    )
    # Both flight legs were prefetched in code before the model ran at all.
    assert len(dispatch.calls) == 2
    # The model was still invoked (hotel search, then the 3-way booking) —
    # the package fast path correctly declined.
    assert len(seen_messages) == 2
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 3
    assert result["booking_data"]["total_price_pkr"] == 35000 + 33000 + 60000


def test_a_plain_hotel_search_still_renders_once_the_hotel_is_found(agent, monkeypatch):
    """
    Guards the fix above from over-firing: _outstanding_other_components must
    stop treating 'stay' as outstanding once a search_hotels result is
    actually among this turn's gathered results — otherwise an ordinary,
    hotel-only search (which always mentions 'hotel') would never render
    again and would cost an LLM call for no reason.
    """
    calls = {"n": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        return _Msg(tool_calls=[_Call("t1", "search_hotels", {
            "destination_city": "Karachi", "check_in": "2026-08-20",
            "check_out": "2026-08-25", "guests": 2, "rooms": 1})])

    async def _dispatch(**kwargs):
        return json.dumps(HOTEL_PAYLOAD)

    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    result = agent.run("hotels in Karachi from 2026-08-20 to 2026-08-25 for 2 guests")
    assert calls["n"] == 1, "a plain hotel search must still render in one call"
    assert "Pearl Continental" in result["response"]
    assert result.get("action") is None


def test_two_separate_leg_searches_do_not_drop_the_hotel(agent, monkeypatch):
    """
    Found while benchmarking the prefetch feature: even with prefetch turned
    OFF entirely, the pre-existing in-loop renderer (agents/master_agent.py,
    the "Deterministic answer for a plain search" block) would render just
    the two flight legs and END THE TURN the moment a model happened to
    search both legs in two separate steps — before ever reaching the hotel
    search a package also needs. The reply read as a complete answer ("tell
    me which one for each leg... I'll set the booking up") while silently
    dropping the hotel entirely, with the loop never even attempting the
    hotel search. Same _components_in guard as the prefetch fast path now
    covers this pre-existing call site too.

    _MAX_TOOL_STEPS is 3, so this scripts exactly the failing shape (two
    SEPARATE same-tool searches, which is what used to trigger the premature
    render) and stops at the hotel search — proving the loop continues past
    the two flight legs, without also needing a 4th step to complete the
    booking (that full atomic-gate behaviour is already covered by
    test_a_flight_plus_hotel_round_trip_package_still_commits_atomically).
    """
    dispatch = _by_route({
        ("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD,
        ("Karachi", "Lahore"): FLIGHT_RET_PAYLOAD,
    })

    calls_seen: list[str] = []

    async def _hotel_or_route(*, name, args, **kwargs):
        calls_seen.append(name)
        if name == "search_hotels":
            return json.dumps(HOTEL_PAYLOAD)
        return await dispatch(name=name, args=args, **kwargs)

    agent.history = []
    monkeypatch.setattr(ma, "_round_trip_prefetch_mode", lambda *_a, **_kw: None)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _hotel_or_route)
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[_Call("t1", "search_flights", {
            "origin_city": "Lahore", "destination_city": "Karachi",
            "travel_date": "2026-08-20", "passengers": 2})]),
        _Msg(tool_calls=[_Call("t2", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Lahore",
            "travel_date": "2026-08-25", "passengers": 2})]),
        _Msg(tool_calls=[_Call("t3", "search_hotels", {
            "destination_city": "Karachi", "check_in": "2026-08-20",
            "check_out": "2026-08-25", "guests": 2, "rooms": 1})]),
    ))

    agent.run(
        "book me a round trip flight from Lahore to Karachi and a hotel there, "
        "2026-08-20 to 2026-08-25, for 2 people"
    )
    assert calls_seen == ["search_flights", "search_flights", "search_hotels"], (
        "the loop must reach the hotel search instead of rendering just the "
        "two flight legs and stopping — got: " + repr(calls_seen)
    )


# ── 4. Missing return date: existing "ask for the date" behaviour preserved ──

def test_a_round_trip_with_only_one_date_still_asks_for_the_return_date(agent, monkeypatch):
    calls = {"n": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        if calls["n"] == 1:
            return _Msg(tool_calls=[_Call("t1", "search_flights", {
                "origin_city": "Lahore", "destination_city": "Karachi",
                "travel_date": "2026-08-20", "passengers": 1})])
        return _Msg("Sure — what date would you like to return?")

    dispatch = _by_route({("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD})
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    result = agent.run("round trip flight from Lahore to Karachi on 2026-08-20 for 1")
    # No return date anywhere yet -> derive_state.return_date is empty ->
    # the prefetch precondition fails and the model handles the turn exactly
    # as it did before this feature existed.
    assert calls["n"] == 2
    assert "return" in result["response"].lower()
    assert result.get("action") is None


# ── 5. User changes itinerary after prefetch ─────────────────────────────────

def test_changing_the_destination_after_a_prefetch_prefetches_the_new_route(agent, monkeypatch):
    dispatch = _by_route({
        ("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD,
        ("Karachi", "Lahore"): FLIGHT_RET_PAYLOAD,
        ("Lahore", "Islamabad"): {
            "search_date": "2026-08-20", "passengers": 2, "total_found": 1,
            "flights": [{"flight_number": "PK100", "airline": "PIA",
                         "depart": "2026-08-20 10:00", "arrive": "11:00",
                         "total_price_pkr": 20000, "price_per_seat_pkr": 10000}],
        },
        ("Islamabad", "Lahore"): {
            "search_date": "2026-08-25", "passengers": 2, "total_found": 1,
            "flights": [{"flight_number": "PK101", "airline": "PIA",
                         "depart": "2026-08-25 18:00", "arrive": "19:00",
                         "total_price_pkr": 21000, "price_per_seat_pkr": 10500}],
        },
    })
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _never)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    first = agent.run(
        "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
    )
    assert "PA401" in first["response"]

    # Second turn: the user changes the destination. A fresh conversation
    # (derive_state re-reads the CURRENT message every turn), so this is
    # simply a new eligible turn with a different route — no special casing
    # needed, and no stale data from the first prefetch should leak in.
    agent.history = [
        {"role": "user", "content": (
            "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
        )},
        {"role": "assistant", "content": first["response"]},
    ]
    second = agent.run(
        "actually, round trip flight from Lahore to Islamabad, "
        "2026-08-20 to 2026-08-25, for 2 people"
    )
    assert "PK100" in second["response"] and "PK101" in second["response"]
    assert "PA401" not in second["response"]


# ── 6. Booking after prefetch ─────────────────────────────────────────────────

def test_booking_after_a_prefetched_list_still_uses_the_atomic_gate(agent, monkeypatch):
    """
    Turn 1: a plain round-trip search renders via the prefetch fast path.
    Turn 2: the user picks both legs. pick_hint must suppress the prefetch (a
    fresh search could reorder/re-price the list the user is pointing at by
    position), and the ordinary loop + atomic package gate — completely
    unmodified by this feature — must still commit both legs as one package.
    """
    two_option_out = dict(FLIGHT_OUT_PAYLOAD, flights=FLIGHT_OUT_PAYLOAD["flights"] + [{
        "flight_number": "PK304", "airline": "PIA", "depart": "2026-08-20 11:20",
        "arrive": "13:00", "total_price_pkr": 38000, "price_per_seat_pkr": 19000,
    }])
    two_option_ret = dict(FLIGHT_RET_PAYLOAD, flights=FLIGHT_RET_PAYLOAD["flights"] + [{
        "flight_number": "PK305", "airline": "PIA", "depart": "2026-08-25 09:00",
        "arrive": "10:35", "total_price_pkr": 36000, "price_per_seat_pkr": 18000,
    }])
    dispatch = _by_route({
        ("Lahore", "Karachi"): two_option_out,
        ("Karachi", "Lahore"): two_option_ret,
    })
    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _never)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    first = agent.run(
        "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
    )
    assert len(dispatch.calls) == 2

    agent.history = [
        {"role": "user", "content": (
            "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
        )},
        {"role": "assistant", "content": first["response"]},
    ]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT),
        _Call("b", "prepare_booking", FLIGHT_BACK),
    ])))

    result = agent.run("1 for outbound and 2 for return")
    # pick_hint suppressed the prefetch entirely for this turn — no new search.
    assert len(dispatch.calls) == 2
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    assert result["booking_data"]["total_price_pkr"] == 35000 + 33000


def test_a_transport_already_booked_this_conversation_is_not_re_prefetched(agent, monkeypatch):
    """Once a leg is genuinely booked, re-searching the same mode again is
    pointless and risks double work — state.prepared gates it off."""
    dispatch = _by_route({
        ("Lahore", "Karachi"): FLIGHT_OUT_PAYLOAD,
        ("Karachi", "Lahore"): FLIGHT_RET_PAYLOAD,
    })
    agent.history = [
        {"role": "assistant", "content": (
            "**Booking Summary**\n\n✈️  **Flight:** Lahore → Karachi\n"
            "Travel date: 2026-08-20"
        )},
    ]
    calls = {"n": 0}

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        return _Msg("Got it — anything else for the trip?")

    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", dispatch)

    agent.run(
        "round trip flight from Lahore to Karachi, 2026-08-20 to 2026-08-25, for 2 people"
    )
    assert len(dispatch.calls) == 0, "a mode already booked this conversation must not be re-prefetched"
    assert calls["n"] == 1
