"""
A failed trip-planner turn must fail CLOSED, never fall through to the legacy
pipeline.

Found while running the interactive planner end to end. An unexpected exception
in the agentic loop lands in its `except Exception` handler, and the last branch
there returns `process_message(...)` — the legacy pipeline, which answers via
itinerary_agent. That path is bound by none of this file's gates: no
reprice_booking, no offer grounding, no "never invent a price". What it actually
produced for a Karachi->Hunza planning turn:

    | Bus ISB -> GIL   | 30,000 | 15,000 per person |
    | Taxi GIL -> Hunza| 10,000 |  5,000 per person |

Travello sells neither a bus nor a taxi, and neither figure came from a search.
The traveller is one tap from a payment screen at that point, so a fabricated
itinerary is not a cosmetic problem.

The fix is one `elif` ahead of that fallback. These tests pin both halves of it:
a planner turn refuses the legacy path, and everything else still gets it.
"""
import asyncio
import json
import re

import pytest

from agents import master_agent as ma


class _Fn:
    def __init__(self, name, arguments):
        self.name, self.arguments = name, arguments


class _Call:
    def __init__(self, cid, name, args):
        self.id, self.type = cid, "function"
        self.function = _Fn(name, json.dumps(args))


class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content, self.tool_calls = content, tool_calls or []


FLIGHTS = json.dumps({
    "search_date": "2026-09-10", "passengers": 2,
    "flights": [
        {"flight_number": "PA900", "airline": "Airblue", "from": "Karachi", "to": "Gilgit",
         "depart": "2026-09-10 07:00", "arrive": "09:05", "cabin": "ECONOMY",
         "total_price_pkr": 60000},
        {"flight_number": "ER628", "airline": "AirSial", "from": "Karachi", "to": "Gilgit",
         "depart": "2026-09-10 08:00", "arrive": "10:05", "cabin": "ECONOMY",
         "total_price_pkr": 48000},
    ],
})
HOTELS = json.dumps({
    "city": "Hunza", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "Old Hunza Inn", "stars": 4, "price_per_night_pkr": 9000,
         "total_stay_pkr": 36000},
        {"name": "Karimabad Inn", "stars": 4, "price_per_night_pkr": 12000,
         "total_stay_pkr": 48000},
    ],
})

PLANNER_MESSAGE = (
    "Karachi to Hunza 10 September 2026 to 14 September 2026 for 2 adults, "
    "budget 400,000, economy flight"
)


@pytest.fixture
def agent(monkeypatch):
    """The real loop, with every I/O edge stubbed and the legacy pipeline spied on."""
    spy = {"legacy_calls": 0, "bookings": 0, "payments": 0, "replies": []}

    async def _memory(_u):
        return {}

    async def _profile(_u):
        return {"display_name": "Sameed"}

    async def _history(_c, limit=20):
        return list(agent.history)

    async def _no_planner_state(_cid):
        return None

    async def _noop_save_planner_state(*a, **k):
        pass

    async def _save(cid, uid, msg, reply, **kw):
        spy["replies"].append(reply)

    async def _noop(*a, **k):
        return None

    async def _legacy(user_id, conversation_id, user_message):
        """Stands in for the legacy pipeline, and records that it was reached."""
        spy["legacy_calls"] += 1
        return {
            "response": (
                "Day 1: Flight Karachi -> Islamabad PKR 20,000 per person. "
                "Bus Islamabad -> Gilgit PKR 15,000 per person. "
                "Taxi Gilgit -> Karimabad PKR 5,000 per person."
            ),
            "conversation_id": conversation_id,
        }

    async def _dispatch(*, name, args, **kwargs):
        return {"search_flights": FLIGHTS, "search_hotels": HOTELS}.get(name, json.dumps({}))

    async def _create_booking(*a, **k):
        spy["bookings"] += 1
        raise AssertionError("a failed planner turn must never create a booking")

    async def _initiate_payment(*a, **k):
        spy["payments"] += 1
        raise AssertionError("a failed planner turn must never attempt a payment")

    async def _reprice(bd):
        out = dict(bd)
        out["total_price_pkr"] = bd.get("total_price_pkr") or 1000
        return out

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _noop)
    monkeypatch.setattr(ma, "process_message", _legacy)
    monkeypatch.setattr(ma, "reprice_booking", _reprice)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _noop)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    class _Agent:
        history: list = []
        spy: dict = {}       # populated below — a class body can't close over `spy`

        def crash(self, message, exc=None):
            """Drive a turn whose very first model call raises."""
            async def _boom(*a, **k):
                raise (exc or TypeError(
                    "_Msg.__init__() got an unexpected keyword argument 'tool_calls'"))

            monkeypatch.setattr(ma, "generate_with_tools", _boom)
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

        def succeed(self, message):
            async def _model(messages, tools=None, **kw):
                return _Msg(tool_calls=[
                    _Call("c1", "search_flights", {
                        "origin_city": "Karachi", "destination_city": "Gilgit",
                        "travel_date": "2026-09-10", "passengers": 2}),
                    _Call("c2", "search_hotels", {
                        "city": "Hunza", "check_in": "2026-09-10",
                        "check_out": "2026-09-14", "guests": 2}),
                ])

            monkeypatch.setattr(ma, "generate_with_tools", _model)
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    agent = _Agent()
    agent.spy = spy          # set here: a class body can't close over `spy`
    return agent


# ── The failure must not reach the legacy pipeline ───────────────────────────

def test_a_crashing_planner_turn_never_reaches_the_legacy_pipeline(agent):
    agent.crash(PLANNER_MESSAGE)
    assert agent.spy["legacy_calls"] == 0


def test_a_crashing_planner_turn_returns_the_safe_message(agent):
    out = agent.crash(PLANNER_MESSAGE)
    assert out["response"] == ma._TRIP_PLANNER_FAILED_MESSAGE
    assert "No booking was created" in out["response"]
    assert "no payment was taken" in out["response"]


def test_the_failure_reply_contains_no_fabricated_travel_content(agent):
    """
    The exact shapes the legacy path invented: a mode of transport this app
    doesn't sell, and a price nothing returned.
    """
    reply = agent.crash(PLANNER_MESSAGE)["response"]
    assert not re.search(r"\b(?:PKR|Rs\.?)\s*[\d,]+", reply, re.I)   # no price at all
    assert not re.search(r"\b\d{3,}\b", reply)                       # no bare figure
    for invented in ("bus", "taxi", "flight", "train", "hotel", "transfer",
                     "day 1", "itinerary"):
        assert invented not in reply.lower(), invented


def test_a_crashing_planner_turn_creates_no_booking_and_no_payment(agent):
    out = agent.crash(PLANNER_MESSAGE)
    assert agent.spy["bookings"] == 0
    assert agent.spy["payments"] == 0
    assert "action" not in out                 # no payment button
    assert "booking_data" not in out


def test_the_failure_is_what_gets_persisted(agent):
    """The saved turn must be the honest message, not a half-formed answer."""
    agent.crash(PLANNER_MESSAGE)
    assert agent.spy["replies"] == [ma._TRIP_PLANNER_FAILED_MESSAGE]


@pytest.mark.parametrize("exc", [
    TypeError("unexpected keyword argument"),
    AttributeError("'NoneType' object has no attribute 'get'"),
    KeyError("transport"),
    ValueError("bad payload"),
    RuntimeError("boom"),
])
def test_any_unexpected_exception_type_fails_closed(agent, exc):
    """Programming errors are exactly the class that used to reach the legacy path."""
    out = agent.crash(PLANNER_MESSAGE, exc=exc)
    assert out["response"] == ma._TRIP_PLANNER_FAILED_MESSAGE
    assert agent.spy["legacy_calls"] == 0


def test_a_crash_during_a_live_selection_session_fails_closed(agent):
    """
    A live option block is the least ambiguous planner signal there is — the
    traveller has already been shown real prices. A message that ISN'T a pick
    ("anything cheaper?") still reaches the model, so it can still crash; it
    must not be answered by the legacy itinerary generator.
    """
    from agents import trip_selection as ts

    options = ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)], "Hunza")
    agent.history = [{"role": "assistant", "content": ts.render_options(options)}]
    try:
        out = agent.crash("anything cheaper?")
        assert out["response"] == ma._TRIP_PLANNER_FAILED_MESSAGE
        assert agent.spy["legacy_calls"] == 0
    finally:
        agent.history = []


def test_a_pick_never_calls_the_model_so_it_cannot_crash_into_the_legacy_path(agent):
    """
    Why the case above needed a non-pick message: resolving "Flight 2" is pure
    code. That turn never reaches generate_with_tools at all, which is its own
    (stronger) guarantee against this failure mode.
    """
    from agents import trip_selection as ts

    options = ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)], "Hunza")
    agent.history = [{"role": "assistant", "content": ts.render_options(options)}]
    try:
        out = agent.crash("Flight 2")          # generate_with_tools raises if called
        assert "AVAILABLE FLIGHTS" in out["response"]
        assert agent.spy["legacy_calls"] == 0
    finally:
        agent.history = []


# ── Everything else keeps its existing fallback ──────────────────────────────

@pytest.mark.parametrize("message", [
    "I want to fly Lahore to Karachi on 20 August 2026 for 2",
    "find me a hotel in Islamabad for 3 nights from 2026-09-10 to 2026-09-13",
    "book me a sedan from DHA phase 5 to the airport tomorrow 9am",
    "what can you do?",
])
def test_non_planner_requests_still_use_the_legacy_fallback(agent, message):
    """Scoped fix: only northern trip PLANNING changes behaviour here."""
    agent.crash(message)
    assert agent.spy["legacy_calls"] == 1


def test_a_standalone_car_to_a_northern_destination_is_not_a_planner_turn(agent):
    """
    "book me a sedan to Naran" mentions a northern destination but selects
    book_car alone — it's a standalone booking, and its fallback is unchanged.
    """
    agent.crash("book me a sedan to Naran for tomorrow 9am")
    assert agent.spy["legacy_calls"] == 1


# ── The detector itself ──────────────────────────────────────────────────────

class _State:
    def __init__(self, destination=""):
        self.destination = destination


@pytest.mark.parametrize("message,dest,tools,expected", [
    # Planning a northern trip — fail closed.
    ("plan a trip to Hunza", "Hunza", ["search_flights", "search_hotels"], True),
    ("plan a trip to Naran", "Naran", ["search_flights"], True),
    ("a hotel in Swat", "Swat", ["search_hotels"], True),
    ("trip to Skardu", "Skardu", ["search_flights", "search_hotels"], True),
    # Not planning — keep the existing fallback.
    ("book me a sedan to Naran", "Naran", ["book_car"], False),
    ("what's the weather in Skardu?", "Skardu", ["get_weather"], False),
    ("nearest hospital in Hunza", "Hunza", ["find_healthcare"], False),
    ("fly Lahore to Karachi", "Karachi", ["search_flights"], False),
    ("a hotel in Lahore", "Lahore", ["search_hotels"], False),
    ("hello", "", [], False),
])
def test_the_planner_detector_is_narrow(message, dest, tools, expected):
    assert ma._is_trip_planner_turn(message, [], _State(dest), tools) is expected


def test_a_live_option_block_settles_it_regardless_of_this_turns_tools(agent):
    from agents import trip_selection as ts

    options = ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)], "Hunza")
    history = [{"role": "assistant", "content": ts.render_options(options)}]
    assert ma._is_trip_planner_turn("yes", history, _State(""), []) is True


# ── The successful path is untouched ─────────────────────────────────────────

def test_a_successful_planner_turn_still_renders_the_options(agent):
    out = agent.succeed(PLANNER_MESSAGE)
    assert "AVAILABLE FLIGHTS" in out["response"]
    assert "AVAILABLE HOTELS" in out["response"]
    assert "AVAILABLE TRANSFERS" in out["response"]
    assert agent.spy["legacy_calls"] == 0
    assert out["response"] != ma._TRIP_PLANNER_FAILED_MESSAGE


def test_the_safe_message_is_exempt_from_the_fabrication_scanner(agent):
    """
    Scripted fallbacks are code-authored, never model output — scanning them
    would let a wording tweak silently replace an honest failure with the
    unrelated "booking not done" text.
    """
    assert ma._TRIP_PLANNER_FAILED_MESSAGE in ma._SCRIPTED_FALLBACK_MESSAGES


def test_the_legacy_fallback_itself_was_not_removed(agent):
    """The scope of the fix: intercept ahead of it, don't delete it."""
    import inspect

    source = inspect.getsource(ma.process_message_agentic)
    assert "return await process_message(user_id, conversation_id, user_message)" in source
