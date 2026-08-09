"""
A round trip or a flight+hotel package is ONE checkout. It must never silently
degrade into a one-piece booking.

The failure this file exists to prevent: the user picks both legs, the return leg
can't be repriced against live availability, and the app shows a payment screen
for the outbound alone. They pay, fly out, and find on the day that there is no
way back. The only safe outcome when a piece fails is to commit NOTHING.

These drive the REAL process_message_agentic loop with a scripted model, so they
exercise the actual gate, not a reimplementation of it.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma


# ── Scripted model ────────────────────────────────────────────────────────────

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
    """A generate_with_tools stand-in that replays `turns` one per loop step."""
    state = {"i": 0}

    async def _fake(messages, tools=None, **kwargs):
        i = state["i"]
        state["i"] += 1
        return turns[i] if i < len(turns) else _Msg("(nothing more to say)")

    return _fake


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

OFFERS = {"role": "assistant", "content": (
    "**Outbound**\n1. Airblue PA401 · 08:00 — PKR 35,000\n"
    "2. PIA PK304 · 11:20 — PKR 38,000\n\n"
    "**Return**\n1. PIA PK305 · 09:00 — PKR 36,000\n"
    "2. AirSial ER198 · 16:10 — PKR 33,000\n"
)}


@pytest.fixture
def agent(monkeypatch):
    """
    Stub every I/O edge of process_message_agentic, leaving the loop and the
    booking gates real. Repricing is driven by `reprice_ok`, a set of flight
    numbers / hotel names that live availability is pretending to confirm.
    """
    saved = {"turns": [], "tasks": []}

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
        saved["tasks"].append(a)

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)

    async def _log_failure(**kwargs):
        return None

    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)

    async def _dispatch(**kwargs):
        return json.dumps({"flights": [], "note": "stubbed"})

    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

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
            return asyncio.run(
                ma.process_message_agentic("u1", "c1", message)
            )

    agent = _Agent()
    agent.saved = saved
    return agent


# ── Both legs succeed ─────────────────────────────────────────────────────────

def test_both_legs_succeed_becomes_one_package(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT),
        _Call("b", "prepare_booking", FLIGHT_BACK),
    ])))

    result = agent.run("1 for outbound and 2 for return")
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    # The total is a sum of SERVER-verified prices, never a model figure.
    assert result["booking_data"]["total_price_pkr"] == 35000 + 33000


# ── One leg fails ─────────────────────────────────────────────────────────────

def test_first_leg_succeeds_second_fails_offers_no_payment(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401"}          # the return can't be confirmed
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),
        ]),
        _Msg(tool_calls=[
            _Call("c", "prepare_booking", FLIGHT_OUT),
            _Call("d", "prepare_booking", FLIGHT_BACK),
        ]),
        _Msg(tool_calls=[
            _Call("e", "prepare_booking", FLIGHT_OUT),
            _Call("f", "prepare_booking", FLIGHT_BACK),
        ]),
    ))

    result = agent.run("1 for outbound and 2 for return")
    assert result.get("action") is None, "a half package must not reach payment"
    assert result.get("booking_data") is None
    assert "ER198" in result["response"]
    assert "no card was charged" in result["response"].lower()


def test_second_leg_succeeds_first_fails_offers_no_payment(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"ER198"}          # the OUTBOUND can't be confirmed
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),
        ]),
        _Msg(tool_calls=[
            _Call("c", "prepare_booking", FLIGHT_OUT),
            _Call("d", "prepare_booking", FLIGHT_BACK),
        ]),
        _Msg(tool_calls=[
            _Call("e", "prepare_booking", FLIGHT_OUT),
            _Call("f", "prepare_booking", FLIGHT_BACK),
        ]),
    ))

    result = agent.run("1 for outbound and 2 for return")
    assert result.get("action") is None
    assert result.get("booking_data") is None
    assert "PA401" in result["response"] or "couldn't confirm" in result["response"].lower()


def test_a_recovered_second_attempt_still_completes_the_package(agent, monkeypatch):
    """
    Failing atomically is not the same as giving up: the gate feeds the failure
    back and the model gets to fix it within the same turn.
    """
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "PK305"}
    replacement = {**FLIGHT_BACK, "flight_number": "PK305", "total_price_pkr": 36000}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", FLIGHT_BACK),     # ER198 -> fails
        ]),
        _Msg(tool_calls=[
            _Call("c", "prepare_booking", FLIGHT_OUT),
            _Call("d", "prepare_booking", replacement),     # PK305 -> succeeds
        ]),
    ))

    result = agent.run("1 for outbound and 2 for return")
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2


# ── The originally-reported bug ───────────────────────────────────────────────

def test_two_picks_but_the_model_only_prepares_one_leg(agent, monkeypatch):
    """
    The user picked two legs; the model prepared one. Previously that verified
    cleanly and went straight to a payment screen for half a round trip — the
    "the chat agent didn't even ask for the return flight" report.
    """
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT_OUT)]),
        _Msg(tool_calls=[_Call("b", "prepare_booking", FLIGHT_OUT)]),
        _Msg(tool_calls=[_Call("c", "prepare_booking", FLIGHT_OUT)]),
    ))

    result = agent.run("1 for outbound and 2 for return")
    assert result.get("action") is None
    assert result.get("booking_data") is None


def test_the_model_is_told_what_is_missing(agent, monkeypatch):
    """
    A leg the model never attempted produces no gate error, so without an
    explicit note it has nothing to react to — that silence is how the one-leg
    booking used to survive to the end of the turn.
    """
    seen: list[list[dict]] = []

    async def _capture(messages, tools=None, **kwargs):
        seen.append([dict(m) for m in messages])
        return _Msg(tool_calls=[_Call(f"x{len(seen)}", "prepare_booking", FLIGHT_OUT)])

    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401"}
    monkeypatch.setattr(ma, "generate_with_tools", _capture)

    agent.run("1 for outbound and 2 for return")
    assert len(seen) >= 2, "the loop should give the model another chance"
    second_call = seen[1]
    assert any("INCOMPLETE PACKAGE" in str(m.get("content") or "") for m in second_call)


# ── Unaffected paths ──────────────────────────────────────────────────────────

def test_one_way_booking_is_unchanged(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT_OUT)])))

    result = agent.run("book option 1")
    assert result["action"] == "payment_choice"
    assert result["booking_data"]["flight_number"] == "PA401"


def test_a_single_booking_that_fails_repricing_still_just_asks(agent, monkeypatch):
    """A one-piece failure is not a package failure — the old path is untouched."""
    agent.history = [OFFERS]
    agent.reprice_ok = set()
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[_Call("a", "prepare_booking", FLIGHT_OUT)]),
        _Msg("I couldn't confirm that flight — shall I search again?"),
    ))

    result = agent.run("book option 1")
    assert result.get("action") is None
    assert result.get("booking_data") is None


def test_flight_plus_hotel_package_commits_together(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "Pearl Continental"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT),
        _Call("b", "prepare_booking", HOTEL),
    ])))

    result = agent.run("book the flight and the hotel")
    assert result["action"] == "package_choice"
    assert {c["booking_type"] for c in result["booking_data"]["components"]} == {"flight", "hotel"}
    assert result["booking_data"]["total_price_pkr"] == 35000 + 60000


def test_flight_plus_hotel_with_a_failing_hotel_commits_nothing(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", FLIGHT_OUT),
            _Call("b", "prepare_booking", HOTEL),
        ]),
        _Msg(tool_calls=[
            _Call("c", "prepare_booking", FLIGHT_OUT),
            _Call("d", "prepare_booking", HOTEL),
        ]),
        _Msg(tool_calls=[
            _Call("e", "prepare_booking", FLIGHT_OUT),
            _Call("f", "prepare_booking", HOTEL),
        ]),
    ))

    result = agent.run("book the flight and the hotel")
    assert result.get("action") is None
    assert result.get("booking_data") is None
    assert "Pearl Continental" in result["response"]


# ── Leg-order parsing ─────────────────────────────────────────────────────────

@pytest.mark.parametrize("message", [
    "1 for outbound and 2 for return",
    "2 for return and 1 for outbound",
    "outbound 1, return 2",
    "return 2, outbound 1",
    "option 1, option 2",
])
def test_two_picks_are_recognised_in_either_textual_order(message):
    picks = ma._selected_indices(message)
    assert len(picks) == 2, message
    # Leg-aware phrasings must come back in LEG order, not typing order, so a
    # reversed sentence can't swap the two flights.
    if "outbound" in message or "return" in message:
        assert picks == [1, 2], message


@pytest.mark.parametrize("message", [
    "returning on 2 aug",
    "book me a flight",
    "2",
])
def test_non_multi_picks_are_not_treated_as_two_legs(message):
    assert ma._selected_indices(message) == []


def test_reversed_order_still_books_the_right_leg_each_way(agent, monkeypatch):
    agent.history = [OFFERS]
    agent.reprice_ok = {"PA401", "ER198"}
    monkeypatch.setattr(ma, "generate_with_tools", _script(_Msg(tool_calls=[
        _Call("a", "prepare_booking", FLIGHT_OUT),
        _Call("b", "prepare_booking", FLIGHT_BACK),
    ])))

    result = agent.run("2 for the return and 1 for outbound")
    assert result["action"] == "package_choice"
    components = result["booking_data"]["components"]
    assert components[0]["origin"] == "Lahore"       # outbound first
    assert components[1]["origin"] == "Karachi"      # return second


# ── Fewer provider calls on an ordinary search ────────────────────────────────

def test_a_simple_search_turn_costs_one_provider_call_not_two(agent, monkeypatch):
    """
    A search turn used to be two calls: one to choose the tool, one to reformat
    the results — and the second carried the whole tool payload back up, so it
    was the more expensive of the pair. On a free tier that halved the turns
    available per day.
    """
    calls = {"n": 0}
    flights = json.dumps({
        "passengers": 1,
        "flights": [{"flight_number": "PA401", "airline": "Airblue",
                     "depart": "2026-08-20 08:00", "arrive": "09:55",
                     "total_price_pkr": 17500, "price_per_seat_pkr": 17500}],
    })

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        return _Msg(tool_calls=[_Call("t1", "search_flights", {
            "origin_city": "Lahore", "destination_city": "Karachi",
            "travel_date": "2026-08-20", "passengers": 1})])

    async def _dispatch(**kwargs):
        return flights

    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    result = agent.run("flights from Lahore to Karachi on 2026-08-20 for 1")
    assert calls["n"] == 1, "the synthesis call should have been skipped"
    assert "PA401" in result["response"]
    assert "Airblue" in result["response"]
    assert result.get("action") is None


def test_a_turn_needing_judgement_still_uses_the_model(agent, monkeypatch):
    calls = {"n": 0}
    flights = json.dumps({"passengers": 1, "flights": [
        {"flight_number": "PA401", "airline": "Airblue", "depart": "2026-08-20 08:00",
         "arrive": "09:55", "total_price_pkr": 17500, "price_per_seat_pkr": 17500}]})

    async def _model(messages, tools=None, **kwargs):
        calls["n"] += 1
        if calls["n"] == 1:
            return _Msg(tool_calls=[_Call("t1", "search_flights", {
                "origin_city": "Lahore", "destination_city": "Karachi",
                "travel_date": "2026-08-20", "passengers": 1})])
        return _Msg("Here's how I'd plan those days…")

    async def _dispatch(**kwargs):
        return flights

    agent.history = []
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    result = agent.run("plan me a 3 day trip to Karachi")
    assert calls["n"] == 2
    assert "plan those days" in result["response"]


# ── The message itself ────────────────────────────────────────────────────────

def test_incomplete_message_names_both_sides_and_denies_a_booking():
    text = ma._package_incomplete_message(
        [{"booking_type": "flight", "origin": "Lahore", "destination": "Karachi",
          "flight_number": "PA401", "travel_date": "2026-08-20"}],
        [{"booking_type": "flight", "origin": "Karachi", "destination": "Lahore",
          "flight_number": "ER198", "travel_date": "2026-08-25"}],
        2,
    )
    assert "PA401" in text and "ER198" in text
    assert "no card was charged" in text.lower()
    assert "nothing was sent to payment" in text.lower()
    # Must never imitate the app's own payment card — that is the fabrication
    # signature _is_fabricated_booking exists to scrub.
    assert not ma._is_fabricated_booking(text)


def test_incomplete_message_when_a_piece_was_never_attempted():
    text = ma._package_incomplete_message(
        [{"booking_type": "flight", "flight_number": "PA401"}], [], 2)
    assert "1 of the 2 pieces" in text
    assert not ma._is_fabricated_booking(text)
