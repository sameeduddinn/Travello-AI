"""
save_message() retries the ai_messages insert exactly once before giving up.

This is the write-side counterpart to the read-side history fix: a silent
first-attempt failure of the assistant's rendered options message (a
transient Supabase blip) reproduces the exact same symptom as a failed
history READ — the next turn's find_options() sees nothing to resolve
"Flight 2, Hotel 3, Transfer 1" against. Most failures at this layer are
transient, so one immediate retry recovers most of them without changing
save_message()'s existing contract: still never raises to its caller, still
logs and swallows a failure that survives the retry.

Exercises the REAL save_message/save_turn/get_conversation_history against a
fake Supabase client (the actual external boundary) — nothing in
memory_agent.py or trip_selection.py is mocked.
"""
import asyncio

import pytest

from agents import memory_agent
from agents import trip_selection as ts


class _Rows:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, db, table, calls, fail_by_role):
        self.db = db
        self.table = table
        self.calls = calls
        self.fail_by_role = fail_by_role  # {"user": 2, "assistant": 1, ...}
        self._payload = None
        self._filters = {}
        self._limit = None
        self._order_desc = False

    def insert(self, payload):
        self._payload = payload
        return self

    def update(self, payload):
        self._payload = payload
        return self

    def eq(self, col, val):
        self._filters[col] = val
        return self

    def in_(self, col, vals):
        self._filters[col] = set(vals)
        return self

    def select(self, *a, **k):
        return self

    def order(self, col, desc=False):
        self._order_desc = desc
        return self

    def limit(self, n):
        self._limit = n
        return self

    def execute(self):
        payload = self._payload
        is_message_insert = self.table == "ai_messages" and payload is not None and "role" in payload
        if is_message_insert:
            assert payload is not None
            role = payload["role"]
            self.calls["ai_messages_insert"] += 1
            self.calls.setdefault(f"ai_messages_insert_{role}", 0)
            self.calls[f"ai_messages_insert_{role}"] += 1
            remaining_failures = self.fail_by_role.get(role, 0)
            if self.calls[f"ai_messages_insert_{role}"] <= remaining_failures:
                raise RuntimeError(f"simulated transient Supabase write failure ({role})")
            self.db.setdefault("ai_messages", []).append(dict(payload))
            return _Rows([dict(payload)])
        if self.table == "ai_conversations":
            self.calls["ai_conversations_update"] += 1
            return _Rows([])
        # a SELECT
        rows = [
            r for r in self.db.get("ai_messages", [])
            if all(
                (r.get(k) in v) if isinstance(v, set) else (r.get(k) == v)
                for k, v in self._filters.items()
            )
        ]
        rows.sort(key=lambda r: r["created_at"], reverse=self._order_desc)
        if self._limit:
            rows = rows[: self._limit]
        return _Rows(rows)


class _FakeSupabase:
    def __init__(self, fail_by_role=None):
        self.db = {}
        self.calls = {"ai_messages_insert": 0, "ai_conversations_update": 0}
        self.fail_by_role = fail_by_role or {}

    def table(self, name):
        return _Query(self.db, name, self.calls, self.fail_by_role)


@pytest.fixture
def fake_supabase(monkeypatch):
    def _make(fail_first_n_message_inserts=0, fail_by_role=None):
        # fail_first_n_message_inserts: convenience for the single-message
        # (save_message) tests, where there's only one role in play.
        # fail_by_role: per-role attempt-failure counts, for save_turn tests
        # where user and assistant inserts run concurrently.
        fake = _FakeSupabase(fail_by_role or {"assistant": fail_first_n_message_inserts})
        monkeypatch.setattr(memory_agent, "supabase_admin", fake)
        return fake

    return _make


# ── 1 & 2. Retry count ────────────────────────────────────────────────────────

def test_the_insert_is_retried_exactly_once_after_a_failure(fake_supabase):
    fake = fake_supabase(fail_first_n_message_inserts=1)

    asyncio.run(memory_agent.save_message("c1", "u1", "assistant", "the options list"))

    assert fake.calls["ai_messages_insert"] == 2, "one failure, one retry -> two attempts total"
    assert len(fake.db["ai_messages"]) == 1, "the message must be persisted after the retry"
    assert fake.calls["ai_conversations_update"] == 1, "the metadata touch runs once, after success"


def test_a_successful_first_attempt_is_not_retried(fake_supabase):
    fake = fake_supabase(fail_first_n_message_inserts=0)

    asyncio.run(memory_agent.save_message("c1", "u1", "assistant", "the options list"))

    assert fake.calls["ai_messages_insert"] == 1, "no failure -> exactly one attempt"
    assert len(fake.db["ai_messages"]) == 1


# ── 3. Both attempts fail: existing swallow/log behaviour is preserved ───────

def test_two_consecutive_failures_are_still_swallowed_not_raised(fake_supabase):
    fake = fake_supabase(fail_first_n_message_inserts=2)

    # Must not raise — save_message's contract (never raises to its caller)
    # is unchanged by adding the retry.
    asyncio.run(memory_agent.save_message("c1", "u1", "assistant", "the options list"))

    assert fake.calls["ai_messages_insert"] == 2, "no third attempt beyond the one retry"
    assert fake.db.get("ai_messages", []) == [], "the message is genuinely lost, same as before"
    assert fake.calls["ai_conversations_update"] == 0, (
        "the conversation must not be touched for a message that was never saved"
    )


def test_a_sustained_failure_does_not_duplicate_the_conversation_touch(fake_supabase):
    """No accidental extra ai_conversations update is introduced by the retry."""
    fake = fake_supabase(fail_first_n_message_inserts=0)

    asyncio.run(memory_agent.save_message("c1", "u1", "assistant", "the options list"))

    assert fake.calls["ai_conversations_update"] == 1


# ── 4 & 5. save_turn() is unchanged: still persists both messages, still ─────
#           never raises, still stamps ordered timestamps.

def test_save_turn_still_persists_both_messages_normally(fake_supabase):
    fake = fake_supabase(fail_first_n_message_inserts=0)

    asyncio.run(memory_agent.save_turn("c1", "u1", "Plan a trip to Swat", "1. dates 2. pax"))

    rows = fake.db["ai_messages"]
    assert [r["role"] for r in rows] == ["user", "assistant"]
    assert rows[0]["created_at"] < rows[1]["created_at"], "assistant strictly after user"


def test_save_turn_never_raises_even_if_one_write_is_lost_after_its_retry(fake_supabase):
    # Both attempts (the original + the one retry) of the ASSISTANT insert
    # fail; the USER insert succeeds normally.
    fake = fake_supabase(fail_by_role={"assistant": 2})

    # save_turn's contract (never raises) is unchanged.
    asyncio.run(memory_agent.save_turn("c1", "u1", "Plan a trip to Swat", "1. dates 2. pax"))

    rows = fake.db["ai_messages"]
    assert [r["role"] for r in rows] == ["user"], (
        "the assistant write is lost after exhausting its retry, exactly as "
        "the un-retried code allowed a single sustained failure to be lost"
    )


# ── 6. Regression: the original failure scenario no longer loses the ─────────
#      assistant's rendered options message on a single transient failure.

FLIGHTS = (
    '{"search_date": "2026-08-14", "passengers": 2, "flights": ['
    '{"flight_number": "PK948", "airline": "PIA", "from": "Karachi", "to": "Islamabad", '
    '"depart": "2026-08-14 07:00", "arrive": "09:03", "cabin": "ECONOMY", "total_price_pkr": 69256}]}'
)
HOTELS = (
    '{"city": "Swat", "nights": 4, "rooms": 1, "guests": 2, "hotels": ['
    '{"name": "Hotel Pameer", "stars": 4, "price_per_night_pkr": 17482, "total_stay_pkr": 69928}]}'
)


def test_a_transient_write_failure_no_longer_loses_the_options_message(fake_supabase):
    """
    Before this fix (test_history_fetch_failure.py's documented, unfixed
    write-side risk): a single failed ai_messages insert for the assistant's
    turn silently dropped the whole options block, and the very next
    find_options() call came back empty — reproducing the reported "generic
    origin/destination" anomaly with no timing/race involved at all. One
    retry closes exactly this transient case.
    """
    fake = fake_supabase(fail_first_n_message_inserts=1)  # the assistant write's FIRST attempt fails

    options_block = ts.render_options(ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", HOTELS)],
        "Swat", passengers=2, preferred_mode="flight"))

    asyncio.run(memory_agent.save_turn("c1", "u1", "Plan a trip to Swat", options_block))

    history = asyncio.run(memory_agent.get_conversation_history("c1", limit=20))
    assert [m["role"] for m in history] == ["user", "assistant"], (
        "both messages survive a single transient failure, thanks to the retry"
    )

    options = ts.find_options(history)
    assert options, "find_options must recover the block that used to be silently lost"
    picks = ts.merge_picks(options, "Flight 1, Hotel 1, Transfer 1", {}).picks
    assert ts.complete(options, picks)
