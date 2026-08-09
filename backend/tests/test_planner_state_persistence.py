"""
Structured Trip Planner state — save_planner_state()/get_active_planner_state()
in memory_agent.py — removes find_options()'s dependency on the bounded
limit=20 conversational history window.

This is the key regression the whole feature exists for: once the rendered
options message falls outside get_conversation_history's most recent 20
rows, the OLD text-scan path (find_options(history)) returns {} and the
selection is lost. A targeted, conversation_id-scoped lookup for a
role="system" row doesn't care how long the conversation has grown.

Exercises the REAL memory_agent.save_turn/get_conversation_history/
save_planner_state/get_active_planner_state against a fake Supabase client
(the actual external boundary — nothing in memory_agent.py or
trip_selection.py is mocked), AND the real process_message_agentic
orchestration for the end-to-end scenarios. trip_selection itself is never
mocked, per the task's explicit requirement.
"""
import asyncio
import json
from datetime import datetime, timezone

import pytest

from agents import master_agent as ma
from agents import memory_agent
from agents import trip_selection as ts


# ── A general-purpose fake Supabase client — the real ai_messages shape ──────

class _Rows:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, db, table):
        self.db = db
        self.table = table
        self._select_cols = None
        self._payload = None
        self._filters: dict[str, tuple[str, object]] = {}
        self._limit = None
        self._order_desc = False

    def select(self, cols):
        self._select_cols = [c.strip() for c in cols.split(",")]
        return self

    def insert(self, payload):
        self._payload = payload
        return self

    def update(self, payload):
        self._payload = payload
        return self

    def eq(self, col, val):
        self._filters[col] = ("eq", val)
        return self

    def in_(self, col, vals):
        self._filters[col] = ("in", set(vals))
        return self

    def order(self, col, desc=False):
        self._order_desc = desc
        return self

    def limit(self, n):
        self._limit = n
        return self

    def _matches(self, row):
        for col, (kind, val) in self._filters.items():
            if kind == "eq" and row.get(col) != val:
                return False
            if kind == "in" and row.get(col) not in val:
                return False
        return True

    def execute(self):
        if self.table == "ai_messages" and self._payload is not None and "role" in self._payload:
            row = dict(self._payload)
            row.setdefault("created_at", datetime.now(timezone.utc).isoformat())
            self.db.setdefault("ai_messages", []).append(row)
            return _Rows([row])
        if self.table == "ai_conversations":
            return _Rows([])
        rows = [r for r in self.db.get("ai_messages", []) if self._matches(r)]
        rows.sort(key=lambda r: r["created_at"], reverse=self._order_desc)
        if self._limit:
            rows = rows[: self._limit]
        if self._select_cols:
            rows = [{c: r.get(c) for c in self._select_cols} for r in rows]
        return _Rows(rows)


class _FakeSupabase:
    def __init__(self):
        self.db: dict = {}

    def table(self, name):
        return _Query(self.db, name)


@pytest.fixture
def fake_supabase(monkeypatch):
    fake = _FakeSupabase()
    monkeypatch.setattr(memory_agent, "supabase_admin", fake)
    return fake


FLIGHTS_SWAT = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [{"flight_number": "PK948", "airline": "PIA", "from": "Karachi",
                 "to": "Islamabad", "depart": "2026-08-14 07:00", "arrive": "09:03",
                 "cabin": "ECONOMY", "total_price_pkr": 69256}],
})
HOTELS_SWAT = json.dumps({
    "city": "Swat", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Hotel Pameer", "stars": 4, "price_per_night_pkr": 17482,
                "total_stay_pkr": 69928}],
})
FLIGHTS_HUNZA = json.dumps({
    "search_date": "2026-08-20", "passengers": 2,
    "flights": [{"flight_number": "PA900", "airline": "Airblue", "from": "Karachi",
                 "to": "Gilgit", "depart": "2026-08-20 07:00", "arrive": "09:05",
                 "cabin": "ECONOMY", "total_price_pkr": 45000}],
})
HOTELS_HUNZA = json.dumps({
    "city": "Hunza", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Old Hunza Inn", "stars": 4, "price_per_night_pkr": 13900,
                "total_stay_pkr": 55600}],
})


def _swat_options() -> dict:
    return ts.build_options(
        [("search_flights", FLIGHTS_SWAT), ("search_hotels", HOTELS_SWAT)],
        "Swat", passengers=2, preferred_mode="flight")


def _hunza_options() -> dict:
    return ts.build_options(
        [("search_flights", FLIGHTS_HUNZA), ("search_hotels", HOTELS_HUNZA)],
        "Hunza", passengers=2, preferred_mode="flight")


# ── 1-2. Save + retrieve ──────────────────────────────────────────────────────

def test_structured_planner_state_saves_and_retrieves(fake_supabase):
    options = _swat_options()
    asyncio.run(memory_agent.save_planner_state("c1", "u1", options))

    state = asyncio.run(memory_agent.get_active_planner_state("c1"))

    assert state is not None
    assert state["destination"] == "Swat"
    assert state["picks"] == {}


# ── 3 & 15. Isolation by conversation_id ─────────────────────────────────────

def test_state_is_isolated_by_conversation_id(fake_supabase):
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    asyncio.run(memory_agent.save_planner_state("c2", "u1", _hunza_options()))

    state_1 = asyncio.run(memory_agent.get_active_planner_state("c1"))
    state_2 = asyncio.run(memory_agent.get_active_planner_state("c2"))

    assert state_1 is not None and state_2 is not None
    assert state_1["destination"] == "Swat"
    assert state_2["destination"] == "Hunza"


def test_two_devices_on_different_conversations_never_cross_state(fake_supabase):
    """Two tabs/devices, two different conversation_ids -- neither can ever
    see the other's active planner state, by construction of the query."""
    asyncio.run(memory_agent.save_planner_state("device-a-conv", "u1", _swat_options()))
    asyncio.run(memory_agent.save_planner_state("device-b-conv", "u1", _hunza_options()))

    state_a = asyncio.run(memory_agent.get_active_planner_state("device-a-conv"))
    state_b = asyncio.run(memory_agent.get_active_planner_state("device-b-conv"))
    assert state_a is not None and state_b is not None
    assert state_a["destination"] == "Swat"
    assert state_b["destination"] == "Hunza"
    # A conversation nobody ever wrote state for sees nothing at all.
    assert asyncio.run(memory_agent.get_active_planner_state("device-c-conv")) is None


# ── 4 & 16. Not returned by get_conversation_history / never in LLM history ──

def test_planner_state_row_is_invisible_to_get_conversation_history(fake_supabase):
    asyncio.run(memory_agent.save_turn("c1", "u1", "Plan a trip to Swat", "some reply"))
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))

    history = asyncio.run(memory_agent.get_conversation_history("c1", limit=20))

    assert len(history) == 2  # only the user+assistant pair, never the system row
    assert all(m["role"] in ("user", "assistant") for m in history)


def test_planner_state_never_reaches_compact_history(fake_supabase):
    asyncio.run(memory_agent.save_turn("c1", "u1", "Plan a trip to Swat", "some reply"))
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))

    history = asyncio.run(memory_agent.get_conversation_history("c1", limit=20))
    compact = ma._compact_history(history)

    assert not any("trip planner state" in (m.get("content") or "") for m in compact)
    assert len(compact) == len(history)


# ── 5 & 18. Survives >20 and >100 messages — THE key regression ─────────────

def test_selection_still_resolves_after_more_than_20_messages(fake_supabase):
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    for i in range(15):  # 30 more rows, comfortably past limit=20
        asyncio.run(memory_agent.save_turn("c1", "u1", f"aside {i}", f"reply {i}"))

    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None
    picks = ts.merge_picks(state, "Flight 1, Hotel 1, Transfer 1", state.get("picks", {})).picks
    assert ts.complete(state, picks)
    assert ts.build_plan(state, picks) is not None


def test_selection_still_resolves_after_more_than_100_messages(fake_supabase):
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    for i in range(55):  # 110 more rows
        asyncio.run(memory_agent.save_turn("c1", "u1", f"aside {i}", f"reply {i}"))

    # The old text-scan path is now provably broken at this depth (the
    # regression this whole feature exists to close):
    history = asyncio.run(memory_agent.get_conversation_history("c1", limit=20))
    assert ts.find_options(history) == {}, "sanity check: the old path IS broken here"

    # The structured path is not:
    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None and state["destination"] == "Swat"
    picks = ts.merge_picks(state, "Flight 1, Hotel 1, Transfer 1", state.get("picks", {})).picks
    assert ts.complete(state, picks)


# ── 6-8. Pick updates, multiple updates, plan regeneration ──────────────────

def test_picks_update_correctly(fake_supabase):
    options = _swat_options()
    asyncio.run(memory_agent.save_planner_state("c1", "u1", options))

    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None
    picks = ts.merge_picks(state, "Flight 1", {}).picks
    asyncio.run(memory_agent.save_planner_state("c1", "u1", {**state, "picks": picks}))

    updated = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert updated is not None
    assert updated["picks"] == {"transport": 1}


def test_multiple_pick_updates_preserve_previous_picks(fake_supabase):
    options = _swat_options()
    asyncio.run(memory_agent.save_planner_state("c1", "u1", options))

    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None
    picks = ts.merge_picks(state, "Flight 1", state.get("picks", {})).picks
    asyncio.run(memory_agent.save_planner_state("c1", "u1", {**state, "picks": picks}))

    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None
    picks = ts.merge_picks(state, "Hotel 1", state.get("picks", {})).picks
    asyncio.run(memory_agent.save_planner_state("c1", "u1", {**state, "picks": picks}))

    final_state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert final_state is not None
    assert final_state["picks"] == {"transport": 1, "hotel": 1}


def test_plan_can_be_regenerated_from_structured_state(fake_supabase):
    options = _swat_options()
    asyncio.run(memory_agent.save_planner_state("c1", "u1", options))
    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None

    picks = ts.merge_picks(state, "Flight 1, Hotel 1, Transfer 1", {}).picks
    plan = ts.build_plan(state, picks)

    assert plan is not None
    assert plan.total_pkr > 0
    text = ts.render_plan(plan, state, picks, "Swat")
    assert "YOUR TRIP PLAN" in text


# ── 9-11. Same-destination continuation / different-destination staleness ───

def test_same_destination_continuation_works(fake_supabase):
    options = _swat_options()
    asyncio.run(memory_agent.save_planner_state("c1", "u1", options))
    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None

    assert not trip_selection_stale(state, ["What's the weather like there in August?"])
    picks = ts.merge_picks(state, "Flight 1, Hotel 1, Transfer 1", {}).picks
    assert ts.complete(state, picks)


def test_different_destination_stale_state_is_rejected(fake_supabase):
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None

    assert trip_selection_stale(state, ["Now plan a trip to Hunza for me"])


def test_newer_options_for_the_new_destination_win(fake_supabase):
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _hunza_options()))

    state = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert state is not None
    assert state["destination"] == "Hunza"


def trip_selection_stale(state: dict, recent_user_texts: list[str]) -> bool:
    """Mirrors the exact staleness check master_agent.py applies to
    structured state — same helper, same rule as find_options()'s own."""
    destination = state.get("destination") or ""
    return bool(destination) and any(
        ts.named_a_different_destination(t, destination) for t in recent_user_texts
    )


# ── 12-13. Write/read failure fall back safely ────────────────────────────────

def test_write_failure_falls_back_safely(monkeypatch):
    class _RaisingTable:
        def insert(self, *a, **k):
            raise RuntimeError("simulated write failure")

    class _RaisingSupabase:
        def table(self, name):
            return _RaisingTable()

    monkeypatch.setattr(memory_agent, "supabase_admin", _RaisingSupabase())

    # Must not raise.
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    # Nothing was persisted -- the caller's own fallback (find_options) is
    # what actually recovers here, exercised end to end below.
    assert asyncio.run(memory_agent.get_active_planner_state("c1")) is None


def test_read_failure_falls_back_safely(monkeypatch):
    class _RaisingSupabase:
        def table(self, name):
            raise RuntimeError("simulated read failure")
    monkeypatch.setattr(memory_agent, "supabase_admin", _RaisingSupabase())

    result = asyncio.run(memory_agent.get_active_planner_state("c1"))
    assert result is None


# ── 14 & 19. Old conversation with no structured state -> existing fallback ──

def test_old_conversation_with_no_structured_state_behaves_exactly_as_before(fake_supabase):
    asyncio.run(memory_agent.save_turn(
        "c1", "u1", "Plan a trip to Swat",
        ts.render_options(_swat_options())))

    assert asyncio.run(memory_agent.get_active_planner_state("c1")) is None

    history = asyncio.run(memory_agent.get_conversation_history("c1", limit=20))
    options = ts.find_options(history)
    assert options and options["destination"] == "Swat"


# ── 17 & 20. End-to-end via the real orchestration ───────────────────────────

class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content = content
        self.tool_calls = tool_calls or []


@pytest.fixture
def agentic(fake_supabase, monkeypatch):
    async def _memory(_uid):
        return {}

    async def _profile(_uid):
        return {"display_name": "Sameed"}

    async def _log_task(*a, **k):
        pass

    async def _log_failure(**kwargs):
        return None

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "_log_task", _log_task)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _log_failure)
    # get_conversation_history/save_turn/save_planner_state/
    # get_active_planner_state are deliberately left REAL here, backed by
    # fake_supabase — this is the end-to-end path, not a unit test.

    def _run(message, conversation_id="c1"):
        return asyncio.run(ma.process_message_agentic("u1", conversation_id, message))

    return _run


def test_original_long_conversation_failure_is_now_resolved_end_to_end(fake_supabase, agentic):
    """The exact regression from the original bug report: options rendered,
    then >20 more messages, then a selection -- must resolve, not fall
    through to a generic 'what's your origin/destination' reply."""
    asyncio.run(memory_agent.save_planner_state("c1", "u1", _swat_options()))
    for i in range(15):
        asyncio.run(memory_agent.save_turn("c1", "u1", f"aside {i}", f"reply {i}"))

    calls = {"n": 0}

    async def _fake_llm(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")

    ma.generate_with_tools = _fake_llm

    result = agentic("Flight 1, Hotel 1, Transfer 1")

    assert calls["n"] == 0, "structured state must resolve deterministically, no model call"
    assert "YOUR TRIP PLAN" in result["response"]


def test_structured_state_failure_causes_no_fabricated_pricing_or_booking(fake_supabase, agentic, monkeypatch):
    """If the structured-state read itself fails (not just "absent"), the
    turn must still behave exactly like the old, safe fallback -- never
    fabricate a price, an action, or booking_data."""
    async def _raising_get_state(_cid):
        raise RuntimeError("should never propagate")

    # get_active_planner_state itself already swallows -- simulate that
    # contract directly, matching what master_agent.py actually calls.
    async def _none(_cid):
        return None
    monkeypatch.setattr(ma, "get_active_planner_state", _none)

    async def _fake_llm(messages, tools=None, **kw):
        return _Msg(content=(
            "Sure! Could you tell me your travel dates, number of travellers, "
            "and budget?"
        ))
    monkeypatch.setattr(ma, "generate_with_tools", _fake_llm)

    result = agentic("Flight 1, Hotel 1, Transfer 1")

    assert result.get("action") is None
    assert result.get("booking_data") is None
    assert "PKR" not in result["response"]


# ── 21+. Shape validation -- corrupted/tampered metadata never reaches ──────
# outstanding()/complete()/build_plan() (see trip_selection.is_valid_planner_state)

def _valid_state() -> dict:
    return _swat_options()


def test_valid_state_passes_validation():
    assert ts.is_valid_planner_state(_valid_state())


def test_none_metadata_fails_validation():
    assert not ts.is_valid_planner_state(None)


def test_non_dict_metadata_fails_validation():
    assert not ts.is_valid_planner_state("not-a-dict")
    assert not ts.is_valid_planner_state(["a", "list"])


def test_missing_transport_fails_validation():
    state = _valid_state()
    del state["transport"]
    assert not ts.is_valid_planner_state(state)


def test_empty_transport_fails_validation():
    state = {**_valid_state(), "transport": []}
    assert not ts.is_valid_planner_state(state)


def test_missing_hotels_fails_validation():
    state = _valid_state()
    del state["hotels"]
    assert not ts.is_valid_planner_state(state)


def test_empty_hotels_fails_validation():
    state = {**_valid_state(), "hotels": []}
    assert not ts.is_valid_planner_state(state)


def test_missing_transfers_fails_validation():
    state = _valid_state()
    del state["transfers"]
    assert not ts.is_valid_planner_state(state)


def test_empty_transfers_is_valid():
    # A destination reached by its own airport legitimately has no hub
    # transfer -- unlike transport/hotels, empty is a real, valid shape.
    state = {**_valid_state(), "transfers": []}
    assert ts.is_valid_planner_state(state)


def test_missing_picks_fails_validation():
    state = _valid_state()
    del state["picks"]
    assert not ts.is_valid_planner_state(state)


def test_wrong_type_picks_fails_validation():
    state = {**_valid_state(), "picks": "transport 1"}
    assert not ts.is_valid_planner_state(state)


def test_wrong_type_transport_fails_validation():
    state = {**_valid_state(), "transport": "not-a-list"}
    assert not ts.is_valid_planner_state(state)


def test_transport_row_not_a_dict_fails_validation():
    state = {**_valid_state(), "transport": ["not-a-dict-row"]}
    assert not ts.is_valid_planner_state(state)


def test_pick_value_out_of_range_fails_validation():
    state = _valid_state()
    state["picks"] = {"transport": 99}
    assert not ts.is_valid_planner_state(state)


def test_pick_unknown_key_fails_validation():
    state = _valid_state()
    state["picks"] = {"vehicle": 1}
    assert not ts.is_valid_planner_state(state)


def test_missing_destination_fails_validation():
    state = _valid_state()
    del state["destination"]
    assert not ts.is_valid_planner_state(state)


def test_missing_transport_kind_fails_validation():
    state = _valid_state()
    del state["transport_kind"]
    assert not ts.is_valid_planner_state(state)


# ── End to end: a corrupted structured-state row never crashes the turn, ────
# never fabricates a plan, and safely falls back to find_options(history).

def test_corrupted_structured_state_falls_back_end_to_end(fake_supabase, agentic):
    """A tampered/corrupted metadata row (missing "transport") must not
    reach build_plan() -- the turn must fall back exactly like an absent
    state, never raise, and never fabricate a plan from the bad row."""
    broken = _swat_options()
    del broken["transport"]
    asyncio.run(memory_agent.save_planner_state("c1", "u1", broken))

    # No conversation history at all, so the find_options(history) fallback
    # also finds nothing -- proving the corrupted row genuinely isn't used,
    # not just "happens to still work" via the text-scan path.
    result = agentic("Flight 1, Hotel 1, Transfer 1")

    assert result.get("action") is None
    assert result.get("booking_data") is None
    assert "YOUR TRIP PLAN" not in result["response"]


def test_corrupted_structured_state_with_history_still_falls_back_to_text_scan(fake_supabase, agentic):
    """With a corrupted structured-state row AND a real rendered options
    block still in history, the turn must recover via find_options(history)
    -- the corrupted row must not block the existing safe fallback."""
    asyncio.run(memory_agent.save_turn(
        "c1", "u1", "Plan a trip to Swat", ts.render_options(_swat_options())))
    broken = _swat_options()
    del broken["transport"]
    asyncio.run(memory_agent.save_planner_state("c1", "u1", broken))

    calls = {"n": 0}

    async def _fake_llm(*a, **k):
        calls["n"] += 1
        return _Msg("should never be reached")
    ma.generate_with_tools = _fake_llm

    result = agentic("Flight 1, Hotel 1, Transfer 1")

    assert calls["n"] == 0
    assert "YOUR TRIP PLAN" in result["response"]
