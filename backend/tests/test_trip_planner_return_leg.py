"""
The interactive Trip Planner only ever booked the OUTBOUND leg — flight/train
to the hub, hotel, and (for Naran/Hunza/Swat) the hub->destination transfer.
Nothing brought the traveller home. Reported live: asked for Naran 14-25
August (a real date RANGE), the confirmed package never mentioned a return
flight/train at all.

Fix, deliberately kept SEPARATE from the outbound options/picks machinery
(trip_selection.build_options/render_options/parse_picks) rather than woven
into it — that machinery works by rendering its own output and re-parsing it
back on the next turn, and a return-leg answer ("2", "no thanks") has a
completely different shape than an outbound pick. Once the outbound plan is
confirmed, IF the traveller gave a real second (return) date anywhere in the
conversation, the return leg is searched deterministically server-side (see
master_agent.py's use of trip_selection.build_return_options) and offered as
its own one-shot pick — never left to the model, same reasoning as every
other deterministic gate this session added. A traveller who never gives a
return date sees no change at all.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma
from agents import trip_selection as ts
from agents.trip_package import TripPackage

FLIGHTS_OUT = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [
        {"flight_number": "PA900", "airline": "Airblue", "from": "Karachi", "to": "Islamabad",
         "depart": "2026-08-14 07:00", "arrive": "09:05", "cabin": "ECONOMY",
         "total_price_pkr": 30000},
    ],
})
FLIGHTS_RETURN = json.dumps({
    "search_date": "2026-08-25", "passengers": 2,
    "flights": [
        {"flight_number": "PA911", "airline": "Airblue", "from": "Islamabad", "to": "Karachi",
         "depart": "2026-08-25 18:00", "arrive": "20:10", "cabin": "ECONOMY",
         "total_price_pkr": 32000},
        {"flight_number": "ER420", "airline": "AirSial", "from": "Islamabad", "to": "Karachi",
         "depart": "2026-08-25 09:00", "arrive": "11:10", "cabin": "ECONOMY",
         "total_price_pkr": 28000},
    ],
})
HOTELS = json.dumps({
    "city": "Naran", "nights": 11, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Hotel Pameer Swat", "stars": 4, "price_per_night_pkr": 17482,
                "total_stay_pkr": 192302}],
})


def _naran_options():
    return ts.build_options(
        [("search_flights", FLIGHTS_OUT), ("search_hotels", HOTELS)],
        "Naran", passengers=2, preferred_mode="flight",
    )


# ── Pure unit tests: the new trip_selection functions ──────────────────────

def test_build_return_options_reads_a_single_search_result():
    rows, kind = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    assert kind == "flight"
    assert len(rows) == 2
    assert {r["flight_number"] for r in rows} == {"PA911", "ER420"}


def test_build_return_options_is_empty_when_nothing_was_found():
    empty = json.dumps({"flights": [], "note": "nothing found"})
    rows, kind = ts.build_return_options([("search_flights", empty)])
    assert rows == [] and kind == ""


def test_render_return_options_shows_every_row_priced():
    rows, _ = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    text = ts.render_return_options(rows, "Karachi", "2026-08-25")
    assert "RETURN TRIP OPTIONS" in text
    assert "Karachi" in text and "2026-08-25" in text
    assert "PKR 32,000" in text and "PKR 28,000" in text


def test_return_was_offered_reads_the_last_assistant_message():
    text = ts.render_return_options([], "Karachi", "2026-08-25")
    assert ts.return_was_offered([{"role": "assistant", "content": text}])
    assert not ts.return_was_offered([{"role": "assistant", "content": "hello"}])
    assert not ts.return_was_offered([])


def test_parse_return_pick_resolves_a_number():
    rows, _ = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    assert ts.parse_return_pick("2", rows) == 2
    assert ts.parse_return_pick("I'll take flight 1", rows) == 1


def test_parse_return_pick_resolves_a_decline():
    rows, _ = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    for text in ("no thanks", "one-way please", "nah, skip it", "no"):
        assert ts.parse_return_pick(text, rows) == 0


def test_parse_return_pick_is_none_for_gibberish_or_out_of_range():
    rows, _ = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    assert ts.parse_return_pick("123 Street North Gilgit", rows) is None
    assert ts.parse_return_pick("9", rows) is None
    assert ts.parse_return_pick("", rows) is None


def test_apply_return_pick_sets_the_plan_fields():
    options = _naran_options()
    plan = ts.build_plan(options, {"transport": 1, "hotel": 1, "transfer": 1})
    assert plan is not None
    before_total = plan.total_pkr
    rows, kind = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    ts.apply_return_pick(plan, rows, kind, 1)
    assert plan.return_transport is not None
    assert plan.return_transport_pkr == 32000
    assert plan.return_transport_kind == "flight"
    assert plan.total_pkr == before_total + 32000
    assert "PA911" in plan.return_transport_label


def test_apply_return_pick_with_a_decline_leaves_the_plan_untouched():
    options = _naran_options()
    plan = ts.build_plan(options, {"transport": 1, "hotel": 1, "transfer": 1})
    assert plan is not None
    before_total = plan.total_pkr
    rows, kind = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    ts.apply_return_pick(plan, rows, kind, 0)   # decline
    assert plan.return_transport is None
    assert plan.total_pkr == before_total


def test_a_plan_with_no_return_leg_prices_exactly_as_before():
    """TripPackage.total_pkr must be byte-for-byte unchanged for every plan
    that never touches the return-leg fields — the whole existing one-way
    flow depends on this."""
    plan = TripPackage(
        tier="", transport={"flight_number": "X"}, transport_kind="flight",
        transport_pkr=30000, hotel={}, hotel_pkr=192302, nights=11,
        transfer={"vehicle": "SUV", "hub": "Islamabad", "destination": "Naran", "fare_pkr": 24000},
    )
    assert plan.total_pkr == 30000 + 192302 + 24000


# ── confirmation_booking_payloads gains a third payload ────────────────────

def test_confirmation_booking_payloads_adds_a_return_leg_when_present():
    options = _naran_options()
    picks = {"transport": 1, "hotel": 1, "transfer": 1}
    plan = ts.build_plan(options, picks)
    assert plan is not None
    rows, kind = ts.build_return_options([("search_flights", FLIGHTS_RETURN)])
    ts.apply_return_pick(plan, rows, kind, 2)   # ER420, PKR 28,000

    payloads = ts.confirmation_booking_payloads(plan, options, picks)
    assert len(payloads) == 3
    types = [p["booking_type"] for p in payloads]
    assert types == ["flight", "hotel", "flight"]
    ret = payloads[2]
    assert ret["origin"] == "Islamabad" and ret["destination"] == "Karachi"
    assert ret["flight_number"] == "ER420"
    assert ret["total_price_pkr"] == 28000
    assert ret["travel_date"] == "2026-08-25"


def test_confirmation_booking_payloads_stays_two_without_a_return_leg():
    options = _naran_options()
    picks = {"transport": 1, "hotel": 1, "transfer": 1}
    plan = ts.build_plan(options, picks)
    assert plan is not None
    payloads = ts.confirmation_booking_payloads(plan, options, picks)
    assert len(payloads) == 2


# ── Full end-to-end reproduction, via process_message_agentic ──────────────
#
# Uses REAL (dict-backed) planner-state persistence rather than the no-op
# mocks test_interactive_trip_planner.py deliberately uses — that file tests
# the OLDER find_options(history) text-reparse fallback on purpose (see its
# own docstring/fixture), and the return-leg offer is scoped to only ever
# fire on genuine structured state (master_agent._planner_options_are_structured)
# precisely so it can never interfere with that fallback path. This fixture
# exercises the structured-state path the return leg actually depends on.

class _Fn:
    def __init__(self, name, arguments):
        self.name, self.arguments = name, arguments


class _Call:
    def __init__(self, call_id, name, args):
        self.id, self.type = call_id, "function"
        self.function = _Fn(name, json.dumps(args))


class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content, self.tool_calls = content, tool_calls or []


@pytest.fixture
def agent(monkeypatch):
    state: dict = {"options": None, "history": []}

    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _history(_cid, limit=20):
        return list(state["history"])

    async def _get_planner_state(_cid):
        return state["options"]

    async def _save_planner_state(_cid, _uid, options):
        state["options"] = options

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        state["history"].append({"role": "user", "content": user_msg})
        state["history"].append({"role": "assistant", "content": reply})

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    async def _dispatch(*, name, args, **kw):
        return {
            "search_flights": agent.flight_response,
            "search_hotels": HOTELS,
        }.get(name, json.dumps({}))

    async def _reprice(bd):
        out = dict(bd)
        out["total_price_pkr"] = bd.get("total_price_pkr") or 1000
        return out

    async def _fake_generate(messages, tools=None, **kwargs):
        i = agent._i
        agent._i += 1
        return agent.script[i] if i < len(agent.script) else _Msg("(nothing more)")

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "get_active_planner_state", _get_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma, "generate_with_tools", _fake_generate)
    monkeypatch.setattr(ma, "reprice_booking", _reprice)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    class _Agent:
        script: list = []
        _i = 0
        flight_response = FLIGHTS_RETURN

        def run(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    agent = _Agent()
    return agent


def _search_and_pick(agent):
    agent.script = [_Msg(tool_calls=[
        _Call("c1", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Islamabad",
            "travel_date": "2026-08-14", "passengers": 2, "cabin_class": "ECONOMY"}),
        _Call("c2", "search_hotels", {
            "city": "Naran", "check_in": "2026-08-14",
            "check_out": "2026-08-25", "guests": 2}),
    ])]
    agent.run(
        "I want to travel from Karachi to Naran from 14 August 2026 to "
        "25 August 2026 for 2 adults. My budget is 300,000."
    )
    return agent.run("Flight 1, Hotel 1, Sedan")


def test_confirming_a_dated_plan_offers_a_return_leg(agent):
    _search_and_pick(agent)
    reply = agent.run("yes")
    assert "return trip" in reply["response"].lower()
    assert "PA911" in reply["response"] or "ER420" in reply["response"]
    assert "action" not in reply


def test_picking_a_return_leg_adds_it_as_a_third_component(agent):
    _search_and_pick(agent)
    agent.run("yes")
    ask = agent.run("2")   # ER420, PKR 28,000
    assert "pickup address" in ask["response"].lower()
    out = agent.run("123 Street Islamabad")
    components = out["booking_data"]["components"]
    assert len(components) == 3
    kinds = [c["booking_type"] for c in components]
    assert kinds.count("flight") == 2 and kinds.count("hotel") == 1
    return_leg = next(c for c in components if c.get("flight_number") == "ER420")
    assert return_leg["origin"] == "Islamabad" and return_leg["destination"] == "Karachi"
    assert return_leg["total_price_pkr"] == 28000


def test_declining_the_return_leg_books_one_way_as_before(agent):
    _search_and_pick(agent)
    agent.run("yes")
    ask = agent.run("no thanks")
    assert "pickup address" in ask["response"].lower()
    out = agent.run("123 Street Islamabad")
    components = out["booking_data"]["components"]
    assert len(components) == 2
    assert {c["booking_type"] for c in components} == {"flight", "hotel"}


def test_an_unrecognised_reply_re_asks_the_return_question(agent):
    _search_and_pick(agent)
    agent.run("yes")
    reply = agent.run("maybe later")
    assert "return trip" in reply["response"].lower()
    assert "action" not in reply


def test_no_return_date_given_means_no_offer_at_all(agent):
    """A traveller who only gives a start date + nights (no explicit second
    date) sees exactly today's behaviour — no return question, straight to
    booking the one-way trip."""
    agent.script = [_Msg(tool_calls=[
        _Call("c1", "search_flights", {
            "origin_city": "Karachi", "destination_city": "Islamabad",
            "travel_date": "2026-08-14", "passengers": 2, "cabin_class": "ECONOMY"}),
        _Call("c2", "search_hotels", {
            "city": "Naran", "check_in": "2026-08-14",
            "check_out": "2026-08-25", "guests": 2}),
    ])]
    agent.run("I want to travel from Karachi to Naran on 14 August 2026 for 11 nights, 2 adults.")
    agent.run("Flight 1, Hotel 1, Sedan")
    ask = agent.run("yes")
    assert "return trip" not in ask["response"].lower()
    assert "pickup address" in ask["response"].lower()
    out = agent.run("123 Street Islamabad")
    assert "action" in out
    assert len(out["booking_data"]["components"]) == 2


def test_no_return_options_found_falls_back_to_one_way_silently(agent):
    """The deterministic return-leg search coming back empty must never block
    the outbound booking -- same "degrade to today's behaviour" posture as
    every other optional-enhancement gate in this app."""
    _search_and_pick(agent)
    agent.flight_response = json.dumps({"flights": [], "note": "nothing found"})
    ask = agent.run("yes")
    assert "return trip" not in ask["response"].lower()
    assert "pickup address" in ask["response"].lower()
    out = agent.run("123 Street Islamabad")
    assert "action" in out
    assert len(out["booking_data"]["components"]) == 2
