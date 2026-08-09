"""
A FAILED conversation-history read and a genuinely empty one must never be
treated the same. Before this fix, both arrived at process_message_agentic
as history == [] — indistinguishable — which let a real, existing selection
turn ("Flight 2, Hotel 3, Transfer 1") be silently read as the start of a
brand-new conversation the moment the history read itself failed (a
transient Supabase hiccup, a race under load), producing a generic
"what's your origin/destination/dates" reply instead of the Trip Plan.

get_conversation_history now raises ConversationHistoryUnavailable on a real
failure instead of swallowing it — process_message_agentic distinguishes:
- a failure on a message that only makes sense as an answer to something
  already shown (a pick, a multi-pick, a bare confirmation) is refused
  outright with the existing _TRIP_PLANNER_FAILED_MESSAGE — no LLM call, no
  legacy fallback, no booking, no fabricated itinerary.
- a failure on anything else is indistinguishable from a genuine first turn
  (which also has an empty history) and proceeds normally, exactly as
  before — this is deliberate: guessing "planner failure" from silence
  would break every legitimate new conversation.

The legacy process_message() pipeline's own history fetch keeps its
original swallow-to-[] behaviour, unchanged, via _history_or_empty.
"""
import asyncio
import json

import pytest

from agents import master_agent as ma
from agents import memory_agent
from agents import trip_selection as ts


class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content = content
        self.tool_calls = tool_calls or []


@pytest.fixture
def agent(monkeypatch):
    """Stub every I/O edge of process_message_agentic; the fix under test and
    every existing gate stay real."""
    saved = {"turns": []}

    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _save_turn(cid, uid, user_msg, reply, **kw):
        saved["turns"].append((user_msg, reply))

    async def _no_planner_state(_cid):
        return None

    async def _noop_save_planner_state(*a, **k):
        pass

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "save_turn", _save_turn)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)

    class _Agent:
        saved: dict = {}

        def run(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    a = _Agent()
    a.saved = saved
    return a


FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
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
    "city": "Swat", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "Burj Al Swat Hotel", "stars": 4.4, "price_per_night_pkr": 25008,
         "total_stay_pkr": 100032},
        {"name": "Rock City Resort", "stars": 4.3, "price_per_night_pkr": 22579,
         "total_stay_pkr": 90316},
        {"name": "Hotel Pameer", "stars": 4, "price_per_night_pkr": 17482,
         "total_stay_pkr": 69928},
    ],
})


def _options_block():
    return ts.render_options(ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)],
        "Swat", passengers=2, preferred_mode="flight"))


async def _raises(conversation_id, limit=20):
    raise RuntimeError("simulated Supabase read failure")


# ── 1. Genuine new conversation: history read SUCCEEDS and returns [] ────────

def test_a_genuine_new_conversation_still_gets_the_normal_planner_flow(agent, monkeypatch):
    async def _empty_ok(conversation_id, limit=20):
        return []

    monkeypatch.setattr(ma, "get_conversation_history", _empty_ok)

    calls = {"n": 0}

    async def _fake_llm(messages, tools=None, **kw):
        calls["n"] += 1
        return _Msg(content=(
            "Sure! When would you like to travel, how many people, and what's "
            "your budget?"
        ))

    monkeypatch.setattr(ma, "generate_with_tools", _fake_llm)

    result = agent.run("Plan a trip from Karachi to Hunza")

    assert calls["n"] >= 1, "a genuine new conversation must still reach the model"
    assert result["response"] != ma._TRIP_PLANNER_FAILED_MESSAGE


# ── 2. Existing conversation: history read SUCCEEDS with real option history ─

def test_an_existing_selection_still_resolves_deterministically_with_zero_model_calls(agent, monkeypatch):
    history = [
        {"role": "user", "content": "Plan a trip to Swat"},
        {"role": "assistant", "content": _options_block()},
    ]

    async def _history_ok(conversation_id, limit=20):
        return history

    monkeypatch.setattr(ma, "get_conversation_history", _history_ok)

    calls = {"n": 0}

    async def _fake_llm(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake_llm)

    result = agent.run("Flight 2, Hotel 3, Transfer 1")

    assert calls["n"] == 0, "a resolvable selection must not need a model call"
    assert "YOUR TRIP PLAN" in result["response"]


# ── 3. The read failure itself is no longer swallowed as an empty success ────

def test_get_conversation_history_raises_instead_of_silently_returning_empty(monkeypatch):
    def _raising_query():
        raise RuntimeError("simulated Supabase read failure")

    class _FakeTable:
        def select(self, *a, **k): return self
        def eq(self, *a, **k): return self
        def in_(self, *a, **k): return self
        def order(self, *a, **k): return self
        def limit(self, *a, **k): return self
        def execute(self): return _raising_query()

    class _FakeSupabase:
        def table(self, name): return _FakeTable()

    monkeypatch.setattr(memory_agent, "supabase_admin", _FakeSupabase())

    with pytest.raises(memory_agent.ConversationHistoryUnavailable):
        asyncio.run(memory_agent.get_conversation_history("c1", limit=20))


# ── 4. Trip-planner continuation + history read failure -> safe refusal ──────

def test_a_selection_turn_refuses_safely_when_history_cannot_be_read(agent, monkeypatch):
    monkeypatch.setattr(ma, "get_conversation_history", _raises)

    calls = {"n": 0}

    async def _fake_llm(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake_llm)

    legacy_calls = {"n": 0}
    original_process_message = ma.process_message

    async def _tracking_legacy(*a, **k):
        legacy_calls["n"] += 1
        return await original_process_message(*a, **k)

    monkeypatch.setattr(ma, "process_message", _tracking_legacy)

    result = agent.run("Flight 2, Hotel 3, Transfer 1")

    assert result["response"] == ma._TRIP_PLANNER_FAILED_MESSAGE
    assert calls["n"] == 0, "no LLM call may happen once refused"
    assert legacy_calls["n"] == 0, "the legacy pipeline must never be invoked here"
    assert result.get("action") is None
    assert result.get("booking_data") is None
    # The refusal is still persisted as a real turn, not silently dropped.
    assert agent.saved["turns"] == [("Flight 2, Hotel 3, Transfer 1", ma._TRIP_PLANNER_FAILED_MESSAGE)]


@pytest.mark.parametrize("message", [
    "Flight 2, Hotel 3, Transfer 1",
    "Hotel 3",
    "2",
    "yes",
    "SUV",
])
def test_every_continuation_shape_refuses_safely_on_a_failed_read(agent, monkeypatch, message):
    monkeypatch.setattr(ma, "get_conversation_history", _raises)

    calls = {"n": 0}

    async def _fake_llm(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    monkeypatch.setattr(ma, "generate_with_tools", _fake_llm)

    result = agent.run(message)

    assert result["response"] == ma._TRIP_PLANNER_FAILED_MESSAGE
    assert calls["n"] == 0


# ── 5. No fabricated price/service can result from the failure ───────────────

def test_a_failed_read_never_fabricates_a_price_or_service(agent, monkeypatch):
    monkeypatch.setattr(ma, "get_conversation_history", _raises)
    monkeypatch.setattr(ma, "generate_with_tools", lambda *a, **k: (_ for _ in ()).throw(
        AssertionError("the model must never be called on a refused turn")
    ))

    result = agent.run("Flight 2, Hotel 3, Transfer 1")

    assert "PKR" not in result["response"]
    assert result.get("action") is None
    assert result.get("booking_data") is None


# ── 6. Standalone / non-continuation requests are unaffected ─────────────────

@pytest.mark.parametrize("message", [
    "book me a sedan to Naran for tomorrow 9am",
    "find me a hotel in Islamabad for 3 nights",
    "Plan a trip from Karachi to Hunza",
    "what's the weather in Lahore",
])
def test_a_non_continuation_message_proceeds_normally_despite_a_failed_read(agent, monkeypatch, message):
    monkeypatch.setattr(ma, "get_conversation_history", _raises)

    calls = {"n": 0}

    async def _fake_llm(*a, **k):
        calls["n"] += 1
        return _Msg(content="Sure — could you share a few more details?")

    monkeypatch.setattr(ma, "generate_with_tools", _fake_llm)

    result = agent.run(message)

    assert calls["n"] >= 1, "a non-continuation message must not be refused on a failed read"
    assert result["response"] != ma._TRIP_PLANNER_FAILED_MESSAGE


def test_the_planner_continuation_shape_detector_is_narrow(monkeypatch):
    assert ma._looks_like_planner_continuation("Flight 2, Hotel 3, Transfer 1") is True
    assert ma._looks_like_planner_continuation("yes") is True
    assert ma._looks_like_planner_continuation("2") is True
    assert ma._looks_like_planner_continuation("book me a sedan to Naran for tomorrow 9am") is False
    assert ma._looks_like_planner_continuation("Plan a trip from Karachi to Hunza") is False
    assert ma._looks_like_planner_continuation("find me a hotel in Islamabad for 3 nights") is False


# ── The legacy pipeline's OWN history fetch is unaffected ────────────────────

def test_the_legacy_pipeline_keeps_its_original_swallow_behaviour():
    async def _raising(conversation_id, limit=20):
        raise memory_agent.ConversationHistoryUnavailable("simulated")

    import agents.master_agent as ma_module
    original = ma_module.get_conversation_history
    ma_module.get_conversation_history = _raising
    try:
        result = asyncio.run(ma_module._history_or_empty("c1", limit=20))
        assert result == []
    finally:
        ma_module.get_conversation_history = original


# ── Documented, NOT fixed: the write side has the same shape of risk ─────────
#
# save_message() (memory_agent.py) also catches every exception and returns
# as though the write succeeded — save_turn() gathers two of these calls and
# has no way to know if either actually landed. A failed save of the
# ASSISTANT's rendered options-list turn is therefore invisible to the turn
# that produced it (the user still sees the options rendered, since the
# response doesn't depend on the write succeeding) and silently missing from
# every later read — reproducing the exact same "selection turn read as
# brand-new" symptom this fix closes, but from the write side instead of the
# read side. This is NOT fixed here, per instruction — this test only
# demonstrates and locks in the CURRENT (unfixed) behaviour, so it will need
# updating if/when the write side gets the same treatment.

def test_KNOWN_LIMITATION_a_failed_save_of_the_options_turn_is_silently_invisible(monkeypatch):
    class _FailingTable:
        def insert(self, *a, **k): return self
        def update(self, *a, **k): return self
        def eq(self, *a, **k): return self
        def execute(self):
            raise RuntimeError("simulated Supabase write failure")

    class _FailingSupabase:
        def table(self, name): return _FailingTable()

    monkeypatch.setattr(memory_agent, "supabase_admin", _FailingSupabase())

    # save_message raises nothing and returns nothing useful — the caller has
    # no way to learn the write failed.
    result = asyncio.run(memory_agent.save_message("c1", "u1", "assistant", "the options list"))
    assert result is None  # no exception, no failure signal of any kind
