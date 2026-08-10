"""
A reply to the assistant's OWN post-confirmation follow-up question (e.g.
"Islamabad Airport" answering "what's the pickup address?") must reach the
booking pipeline instead of being silently re-answered with the same Trip
Plan card — the bug traced and fixed here.

Same harness as test_northern_trip_planning.py: the pure trip_selection
functions (find_options/merge_picks/build_plan) are exercised for real via
history, and the booking turn drives the REAL process_message_agentic loop
with a SCRIPTED model — so what's verified is that the message actually
reaches generate_with_tools (captured verbatim from the messages it was
called with) and that its resulting prepare_booking call clears the same
gates (get_transfer_error, reprice_booking, the atomic package gate) as any
other booking turn. Nothing here is a claim about what a real model would
write — the script stands in for that and is inspected directly.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma
from agents import trip_selection as ts


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


def _recording_script(recorder, *turns):
    """Same replay-one-per-step stand-in as _script, but also records the
    `messages` list generate_with_tools was called with on every step —
    the only honest way to prove a message reached the model."""
    state = {"i": 0}

    async def _fake(messages, tools=None, **kwargs):
        recorder.append(messages)
        i = state["i"]
        state["i"] += 1
        return turns[i] if i < len(turns) else _Msg("(nothing more to say)")

    return _fake


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


# ── A real Swat trip plan, built the same way the app builds one ─────────────

FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 4,
    "flights": [
        {"flight_number": "PK948", "airline": "PIA", "from": "Karachi", "to": "Islamabad",
         "depart": "2026-08-14 07:00", "arrive": "09:03", "cabin": "ECONOMY",
         "total_price_pkr": 69256},
        {"flight_number": "PA911", "airline": "Airblue", "from": "Karachi", "to": "Islamabad",
         "depart": "2026-08-14 07:00", "arrive": "08:50", "cabin": "ECONOMY",
         "total_price_pkr": 129492},
    ],
})
HOTELS = json.dumps({
    "city": "Swat", "nights": 11, "rooms": 1, "guests": 4,
    "hotels": [
        {"name": "Burj Al Swat Hotel", "stars": 4.4, "price_per_night_pkr": 25008,
         "total_stay_pkr": 275088},
        {"name": "Rock City Resort", "stars": 4.3, "price_per_night_pkr": 22579,
         "total_stay_pkr": 248369},
        {"name": "Hotel Pameer", "stars": 4, "price_per_night_pkr": 17482,
         "total_stay_pkr": 192302},
    ],
})


def _swat_plan():
    """Build the exact options/plan a real "Flight 2, Hotel 3, Transfer 1"
    turn produces — real functions, not hand-written expectations."""
    options = ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)],
        "Swat", passengers=4, preferred_mode="flight")
    options = ts.parse_options(ts.render_options(options))  # the real round trip
    picks = ts.merge_picks(options, "Flight 2, Hotel 3, Transfer 1", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    return options, picks, plan


FOLLOWUP_QUESTION = {"role": "assistant", "content": (
    "Great! I'll set up the three parts of your trip. Before I can book the "
    "transfer, I just need the pickup address in Islamabad (e.g. \"123-C, "
    "Jinnah Avenue, Gulberg\")."
)}


def _history_with_plan_shown():
    """History ending on the plan card itself — the ONLY case that must
    still unconditionally render_plan on any non-"yes" reply."""
    options, picks, plan = _swat_plan()
    options_block = ts.render_options(ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)],
        "Swat", passengers=4, preferred_mode="flight"))
    plan_card = ts.render_plan(plan, options, picks, "Swat")
    return options, picks, plan, [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": (
            "1. 14 August to 25 August 2026\n2. 2 adults and 2 children\n"
            "3. 300,000\n4. 5 star"
        )},
        {"role": "user", "content": (
            "1. 14 August to 25 August 2026\n2. 2 adults and 2 children\n"
            "3. 300,000\n4. 5 star"
        )},
        {"role": "assistant", "content": options_block},
        {"role": "user", "content": "Flight 2, Hotel 3, Transfer 1"},
        {"role": "assistant", "content": plan_card},
    ]


def _history_after_confirmation():
    """History ending on the assistant's OWN follow-up question — the new
    case this fix handles."""
    options, picks, _plan, history = _history_with_plan_shown()
    return options, picks, [
        *history,
        {"role": "user", "content": "yes"},
        FOLLOWUP_QUESTION,
    ]


# ── 1. The pickup-address answer is no longer swallowed ──────────────────────

def test_a_pickup_address_answer_reaches_the_model_instead_of_re_rendering(agent, monkeypatch):
    """
    Superseded by a stronger fix than this test's original name describes:
    the pickup-address answer no longer needs to "reach the model" at all —
    it completes the confirmed plan deterministically, in code (see
    master_agent._complete_trip_planner_confirmation), which is exactly what
    closes the original bug (the model unreliably juggling "ask for the
    address" and "book everything together") more completely than routing
    the answer to the model ever could. The regression this test guards —
    the answer must never be silently swallowed or re-render the same
    content — still holds and is asserted below.
    """
    options, picks, history = _history_after_confirmation()
    agent.history = history
    transport_row = options["transport"][picks["transport"] - 1]
    hotel_row = options["hotels"][picks["hotel"] - 1]
    agent.reprice_ok = {transport_row["flight_number"], hotel_row["name"]}

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("Islamabad Airport")

    # 1. The answer was NOT swallowed — it completed the checkout
    #    deterministically, with zero model calls needed.
    assert calls["n"] == 0

    # 2. No duplicate Trip Plan — the turn did NOT take the render-and-return
    #    shortcut this time.
    assert "YOUR TRIP PLAN" not in (result.get("response") or "")

    # 3. The answer made it all the way into a verified booking component,
    #    through the SAME get_transfer_error/reprice_booking gates as any
    #    other booking turn.
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    flight_component = next(
        c for c in result["booking_data"]["components"] if c.get("booking_type") == "flight"
    )
    assert flight_component["transfer_pickup_location"] == "Islamabad Airport"
    assert flight_component["transfer_vehicle_type"] == "SUV"
    assert flight_component["transfer_dropoff_location"] == "Swat"


# ── 2. A combined hotel-name + pickup-address answer also reaches booking ────

def test_a_combined_hotel_and_pickup_answer_reaches_the_model(agent, monkeypatch):
    options, picks, history = _history_after_confirmation()
    agent.history = history
    transport_row = options["transport"][picks["transport"] - 1]
    hotel_row = options["hotels"][picks["hotel"] - 1]

    flight_call = {
        "booking_type": "flight", "origin": "Karachi", "destination": "Islamabad",
        "travel_date": "2026-08-14", "flight_number": transport_row["flight_number"],
        "adults": 2, "children": 2, "cabin_class": "ECONOMY",
        "total_price_pkr": transport_row["price_pkr"],
        "transfer_vehicle_type": "SUV",
        "transfer_pickup_location": "Islamabad Airport",
        "transfer_dropoff_location": "Swat",
    }
    hotel_call = {
        "booking_type": "hotel", "hotel_name": hotel_row["name"], "destination": "Swat",
        "check_in": "2026-08-14", "check_out": "2026-08-25", "rooms": 1, "guests": 4,
    }
    agent.reprice_ok = {transport_row["flight_number"], hotel_row["name"]}

    recorded_messages = []
    monkeypatch.setattr(ma, "generate_with_tools", _recording_script(
        recorded_messages,
        _Msg(tool_calls=[
            _Call("a", "prepare_booking", flight_call),
            _Call("b", "prepare_booking", hotel_call),
        ]),
    ))

    user_message = "Hotel is Hotel Pameer\nFor car transfer the pickup address is Islamabad airport"
    result = agent.run(user_message)

    assert recorded_messages
    assert any(user_message in (m.get("content") or "") for m in recorded_messages[0])
    assert "YOUR TRIP PLAN" not in (result.get("response") or "")
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2


# ── A bare number is never mistaken for a pickup address ─────────────────────
#
# Observed bug: after a "yes" the model sometimes free-lanced its own ad-hoc
# "1. cheaper / 2. raise the budget / 3. suggest an alternative" question
# (nothing in this codebase renders that deterministically), and a bare "2"
# answering IT would reach this same post-confirmation state and — without
# this guard — get used as the literal transfer_pickup_location, since a
# lone digit passes every existing transfer gate (not a known placeholder
# phrase, not a bare city name). The confirmation path no longer reaches the
# model at the point that produced that ad-hoc question, so it shouldn't
# recur, but a bare number is never a real address regardless of its origin.

def test_a_bare_number_is_never_booked_as_the_pickup_address(agent, monkeypatch):
    _, _, history = _history_after_confirmation()
    agent.history = history

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("2")

    assert calls["n"] == 0
    assert result.get("action") is None
    assert result.get("booking_data") is None
    assert "doesn't look like a pickup address" in result["response"].lower()


# ── 3. A question is NOT treated as a booking answer ──────────────────────────
#
# Per the approved design: when a reply in the post-confirmation follow-up
# state does NOT look like a plain answer, the new branch's condition is
# simply False, so control falls to the EXISTING (untouched) `elif _plan:`
# re-render — the same safe, zero-model-call behaviour every other
# non-followup-answer case in this state already gets (see the "swap after a
# followup question" test below). This is deliberate: "prefer the existing
# behaviour rather than forcing a booking attempt" whenever the message is
# ambiguous. It does NOT fall through to ordinary conversation — it is not
# forgotten or dropped, it gets the identical Trip Plan back, unchanged from
# today's behaviour, with no risk of a stray reply nudging the model toward
# a booking attempt.

@pytest.mark.parametrize("message", [
    "Can I change the hotel?",
    "What's the price?",
    "Actually, switch the hotel",
    "Change the transfer to SUV",
])
def test_a_question_or_change_request_does_not_force_a_booking_attempt(agent, monkeypatch, message):
    _, _, history = _history_after_confirmation()
    agent.history = history

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run(message)

    # No booking attempt was forced, and — since this is unambiguously safe —
    # no model call was made at all, exactly like the plan-card and swap cases.
    assert calls["n"] == 0
    assert result.get("action") is None
    assert "YOUR TRIP PLAN" in (result.get("response") or "")


# ── 4. looks_like_a_followup_answer is conservative and deterministic ────────

@pytest.mark.parametrize("message", [
    "Islamabad Airport",
    "Hotel Pameer",
    "Hotel is Hotel Pameer / pickup address is Islamabad Airport",
    "123 Jinnah Avenue, Islamabad",
])
def test_plain_answers_are_recognised(message):
    assert ts.looks_like_a_followup_answer(message) is True


@pytest.mark.parametrize("message", [
    "Can I change the hotel?",
    "What's the price?",
    "Actually, switch the hotel",
    "Change the transfer to SUV",
    "Hotel 2 instead",
])
def test_questions_and_change_requests_are_not_recognised(message):
    assert ts.looks_like_a_followup_answer(message) is False


def test_a_blank_message_is_never_treated_as_an_answer():
    assert ts.looks_like_a_followup_answer("") is False
    assert ts.looks_like_a_followup_answer("   ") is False


# ── 5. Regressions: everything else about this shortcut is unchanged ─────────

def test_first_time_completion_still_renders_the_plan_with_zero_model_calls(agent, monkeypatch):
    """options list is the LAST thing shown -> render_plan, no model call at all."""
    options_block = ts.render_options(ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)],
        "Swat", passengers=4, preferred_mode="flight"))
    agent.history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": options_block},
    ]

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("Flight 2, Hotel 3, Transfer 1")

    assert calls["n"] == 0, "a first-time completion must resolve with zero model calls"
    assert "YOUR TRIP PLAN" in result["response"]


def test_yes_after_the_plan_still_enters_the_booking_path(agent, monkeypatch):
    """
    This plan has a car transfer, so "yes" can't complete deterministically
    in one step -- the pickup address is genuinely unknown. It must ask for
    it directly, in code, rather than reach the model at all (a free-tier
    model was not reliably remembering to ask AND book everything together
    in the same reply -- see master_agent._complete_trip_planner_confirmation)
    and it must NOT silently re-render the same Trip Plan (the bug this
    whole mechanism exists to close).
    """
    _, _, _, history = _history_with_plan_shown()
    agent.history = history

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("yes")

    assert calls["n"] == 0, "asking for the pickup address must resolve deterministically"
    assert "pickup address" in result["response"].lower()
    assert "YOUR TRIP PLAN" not in result["response"]


def test_supplying_the_pickup_address_completes_the_booking_with_zero_model_calls(agent, monkeypatch):
    """
    The turn after "yes" asked for a pickup address: the traveller's plain
    reply completes the SAME checkout deterministically (see
    master_agent._complete_trip_planner_confirmation) -- no model call, and
    the package carries exactly the components they picked.
    """
    _, _, _, history = _history_with_plan_shown()
    agent.history = history
    agent.reprice_ok = {"PA911", "Hotel Pameer"}  # Flight 2 / Hotel 3 from _swat_plan()

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    ask = agent.run("yes")  # asks for the pickup address, deterministically
    # This fixture's _save_turn only records into saved["turns"], not into
    # agent.history -- extend it manually so the next call sees a real,
    # persisted conversation (plan_was_shown must now read False).
    agent.history = agent.history + [
        {"role": "user", "content": "yes"},
        {"role": "assistant", "content": ask["response"]},
    ]
    result = agent.run("123 Street North Islamabad")

    assert calls["n"] == 0, "completing the confirmed plan must resolve deterministically too"
    assert result["action"] == "package_choice"
    components = result["booking_data"]["components"]
    assert len(components) == 2
    flight = next(c for c in components if c["booking_type"] == "flight")
    hotel = next(c for c in components if c["booking_type"] == "hotel")
    assert flight["flight_number"] == "PA911"
    assert hotel["hotel_name"] == "Hotel Pameer"
    assert flight["transfer_vehicle_type"]
    assert flight["transfer_pickup_location"] == "123 Street North Islamabad"


def test_a_pickup_address_answer_that_echoes_the_question_still_completes(agent, monkeypatch):
    """
    Real on-device bug: a traveller answering "what's the pickup address?"
    naturally wrote "Pickup address is Gilgit Baltistan airport" -- the exact
    phrase agent_tools._TRANSFER_PLACEHOLDER_RE exists to catch, because a
    MODEL producing that same text ("Your pickup address in Islamabad") means
    the field was never actually filled in. Taken as literal address text
    without stripping the echoed frame, this genuine answer failed the
    transfer gate, the deterministic path declined, and the turn fell back to
    the old model-driven flow -- reopening the exact "missing: Hotel" bug
    this fix exists to close. clean_pickup_reply() strips just that leading
    frame so this resolves deterministically instead.
    """
    _, _, _, history = _history_with_plan_shown()
    agent.history = history
    agent.reprice_ok = {"PA911", "Hotel Pameer"}

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    ask = agent.run("yes")
    agent.history = agent.history + [
        {"role": "user", "content": "yes"},
        {"role": "assistant", "content": ask["response"]},
    ]
    result = agent.run("Pickup address is Gilgit Baltistan airport")

    assert calls["n"] == 0, "must resolve deterministically, not fall back to the model"
    assert result["action"] == "package_choice"
    components = result["booking_data"]["components"]
    assert len(components) == 2
    flight = next(c for c in components if c["booking_type"] == "flight")
    # The real hub for this trip is Islamabad, and "Gilgit Baltistan airport"
    # never names it -- confirmation_booking_payloads appends the hub so the
    # downstream fare lookup (agent_tools._add_transfer_fare) can still find
    # the real route fare instead of silently falling back to the flat rate.
    # See test_trip_planner_return_leg.py-adjacent coverage for the bug this
    # closes: a real pickup answer that never says the hub name by name used
    # to reprice PKR 18,000 down to PKR 6,000.
    assert flight["transfer_pickup_location"] == "Gilgit Baltistan airport (Islamabad)"


def test_a_non_confirmation_right_after_the_plan_still_re_renders_it(agent, monkeypatch):
    """Last message IS the plan card — this must behave exactly as before."""
    _, _, _, history = _history_with_plan_shown()
    agent.history = history

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("hmm, not sure yet")

    assert calls["n"] == 0
    assert "YOUR TRIP PLAN" in result["response"]


def test_a_swap_after_the_plan_still_updates_and_reprices(agent, monkeypatch):
    _, _, _, history = _history_with_plan_shown()
    agent.history = history

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("Hotel 2 instead")

    assert calls["n"] == 0, "a swap must still resolve deterministically, no model call"
    assert "YOUR TRIP PLAN" in result["response"]
    assert "Hotel #2" in result["response"]


def test_a_swap_after_a_followup_question_still_updates_not_books(agent, monkeypatch):
    """Last message is the FOLLOW-UP QUESTION (not the plan card), but the
    reply is a re-pick, not an answer — must still re-render, not book."""
    _, _, history = _history_after_confirmation()
    agent.history = history

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("Hotel 2 instead")

    assert calls["n"] == 0
    assert "YOUR TRIP PLAN" in result["response"]
    assert "Hotel #2" in result["response"]


# ── 6. Standalone flows are structurally unreachable by this shortcut ────────

def test_standalone_hotel_search_never_enters_the_planner_shortcut(agent, monkeypatch):
    """No AVAILABLE FLIGHTS/HOTELS/TRANSFERS block in history -> find_options
    returns {} -> the whole shortcut (and this fix) never engages."""
    agent.history = [
        {"role": "user", "content": "find me a hotel in Islamabad for 3 nights"},
        {"role": "assistant", "content": "Sure — what dates and how many guests?"},
    ]
    assert ts.find_options(agent.history) == {}


def test_standalone_tool_selection_is_unaffected():
    from agents.prompt_builder import select_tool_names

    assert select_tool_names("book me a sedan to Naran for tomorrow 9am") == ["book_car"]
    assert select_tool_names("find me a hotel in Islamabad for 3 nights") == ["search_hotels"]


# ── 7. No transfer needed -> "yes" alone completes the checkout ─────────────
#
# Skardu has its own airport (hub_options_for returns [], not None) — no car
# transfer is ever offered for it, so the deterministic confirmation path has
# everything it needs on the very first "yes", with no pickup-address detour.

SKARDU_FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [
        {"flight_number": "PK410", "airline": "PIA", "from": "Islamabad", "to": "Skardu",
         "depart": "2026-08-14 06:00", "arrive": "07:15", "cabin": "ECONOMY",
         "total_price_pkr": 42000},
    ],
})
SKARDU_HOTELS = json.dumps({
    "city": "Skardu", "nights": 3, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "Shangrila Resort", "stars": 4.2, "price_per_night_pkr": 15000,
         "total_stay_pkr": 45000},
    ],
})


def test_yes_alone_completes_a_no_transfer_plan(agent, monkeypatch):
    options = ts.build_options(
        [("search_flights", SKARDU_FLIGHTS), ("search_hotels", SKARDU_HOTELS)],
        "Skardu", passengers=2, preferred_mode="flight")
    options = ts.parse_options(ts.render_options(options))
    picks = ts.merge_picks(options, "Flight 1, Hotel 1", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None and plan.transfer is None

    plan_card = ts.render_plan(plan, options, picks, "Skardu")
    agent.history = [
        {"role": "user", "content": "Plan a trip to Skardu on 14 August 2026 for 2 people"},
        {"role": "assistant", "content": ts.render_options(
            ts.build_options([("search_flights", SKARDU_FLIGHTS), ("search_hotels", SKARDU_HOTELS)],
                              "Skardu", passengers=2, preferred_mode="flight"))},
        {"role": "user", "content": "Flight 1, Hotel 1"},
        {"role": "assistant", "content": plan_card},
    ]
    agent.reprice_ok = {"PK410", "Shangrila Resort"}

    calls = {"n": 0}

    async def _fake(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake)

    result = agent.run("yes")

    assert calls["n"] == 0, "no transfer needed -- nothing here requires the model"
    assert result["action"] == "package_choice"
    assert result["booking_data"]["component_count"] == 2
    components = result["booking_data"]["components"]
    assert {c["booking_type"] for c in components} == {"flight", "hotel"}
    flight = next(c for c in components if c["booking_type"] == "flight")
    assert "transfer_vehicle_type" not in flight


# ── 8. A partial refinement (e.g. "business class flights") can't go stale ──
#
# Real on-device bug: options are shown (economy), the traveller asks for
# business class, the model re-searches flights for real and writes an
# accurate prose summary of the fresh business-class prices -- but that
# prose never updates what a later pick resolves against, so "Flight 1,
# Hotel 3, Transfer 2" silently booked the OLD economy fare underneath the
# business-class numbers the traveller had just been shown. Closed by
# trip_selection.merge_fresh_search (see master_agent.py's two render sites).

ECONOMY_FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [{"flight_number": "PK107", "airline": "PIA", "from": "Karachi",
                 "to": "Gilgit", "depart": "2026-08-14 07:00", "arrive": "08:11",
                 "cabin": "ECONOMY", "total_price_pkr": 22066}],
})
BUSINESS_FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [{"flight_number": "PK107", "airline": "PIA", "from": "Karachi",
                 "to": "Gilgit", "depart": "2026-08-14 07:00", "arrive": "08:11",
                 "cabin": "BUSINESS", "total_price_pkr": 67118}],
})
HUNZA_HOTELS = json.dumps({
    "city": "Hunza", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Tourist Cottage Hunza", "stars": 4.3, "price_per_night_pkr": 18319,
                "total_stay_pkr": 73276}],
})


def test_a_cabin_class_refinement_updates_what_a_later_pick_resolves_against(agent, monkeypatch):
    economy_options = ts.build_options(
        [("search_flights", ECONOMY_FLIGHTS), ("search_hotels", HUNZA_HOTELS)],
        "Hunza", passengers=2, preferred_mode="flight")
    agent.history = [
        {"role": "user", "content": "Plan a trip to Hunza on 14 August 2026 for 2 people, flying"},
        {"role": "assistant", "content": ts.render_options(economy_options)},
    ]

    async def _script(messages, tools=None, **kw):
        return _Msg(tool_calls=[
            _Call("c1", "search_flights", {
                "origin_city": "Karachi", "destination_city": "Gilgit",
                "travel_date": "2026-08-14", "passengers": 2, "cabin_class": "BUSINESS"}),
        ])

    async def _dispatch(*, name, args, **kw):
        return {"search_flights": BUSINESS_FLIGHTS}.get(name, json.dumps({}))

    monkeypatch.setattr(ma, "generate_with_tools", _script)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    result = agent.run("I want business class flights")

    # The rendered reply must be the DETERMINISTIC options block (real
    # business-class numbers), not the model's own free-text summary of them.
    assert "AVAILABLE FLIGHTS" in result["response"]
    assert "PKR 67,118" in result["response"]
    assert "BUSINESS" in result["response"]

    # The state a later pick resolves against must show the SAME business
    # fare just displayed -- not the old economy one still sitting in
    # history's first assistant message.
    updated = ts.find_options(agent.history[:0] + [
        {"role": "user", "content": "Plan a trip to Hunza on 14 August 2026 for 2 people, flying"},
        {"role": "assistant", "content": ts.render_options(economy_options)},
        {"role": "user", "content": "I want business class flights"},
        {"role": "assistant", "content": result["response"]},
    ])
    assert updated["transport"][0]["cabin"] == "BUSINESS"
    assert updated["transport"][0]["price_pkr"] == 67118

    picks = ts.merge_picks(updated, "Flight 1, Hotel 1, Transfer 1", {}).picks
    plan = ts.build_plan(updated, picks)
    assert plan is not None
    assert plan.transport["cabin"] == "BUSINESS"
    assert plan.transport_pkr == 67118
