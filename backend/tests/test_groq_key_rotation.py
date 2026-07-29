"""
Two Groq keys: a second daily budget, and nothing more than that.

The free-tier limit that actually ends a day is per-ACCOUNT (TPD), so a second
Groq account buys the agent another day's worth of turns. Everything here is
about keeping that narrow: rotate on a real daily wall, never on a failure that
would repeat identically on the other account, and never let one key's cooldown
speak for the other.

No key value is ever a real credential — the strings below are fakes, and one
test exists specifically to prove they never reach a log line.
"""
import asyncio
import logging
from types import SimpleNamespace

import pytest

from services import llm_service as svc
from services.llm_service import (
    LLMError,
    QUOTA_DAILY,
    QUOTA_MINUTE,
    REQUEST_TOO_LARGE,
)

# Shaped like real Groq keys so a substring search for them is meaningful.
KEY_1 = "gsk_TESTONLYfake1AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
KEY_2 = "gsk_TESTONLYfake2BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"

GROQ_TPD = (
    "Rate limit reached for model `llama-3.3-70b-versatile` in organization "
    "`org_01abc` service tier `on_demand` on tokens per day (TPD): Limit 100000, "
    "Used 91437, Requested 8635. Please try again in 5m39.6s."
)
GROQ_TPM = (
    "Rate limit reached for model `llama-3.3-70b-versatile` in organization "
    "`org_01abc` service tier `on_demand` on tokens per minute (TPM): Limit 12000, "
    "Used 11000, Requested 8635. Please try again in 7.66s."
)
GROQ_413 = (
    "Request too large for model `llama-3.3-70b-versatile` in organization "
    "`org_01abc` service tier `on_demand` on tokens per minute (TPM): Limit 12000, "
    "Requested 13500."
)

MESSAGES = [{"role": "user", "content": "hi"}]


def _run(coro):
    return asyncio.run(coro)


class _Msg:
    """Stand-in for the assistant message the provider paths return."""

    def __init__(self, content):
        self.content = content
        self.tool_calls = None


def _keys(monkeypatch, *, key1=KEY_1, key2=KEY_2, legacy=""):
    """Configure the Groq keys and hand out one distinguishable client each."""
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY", legacy, raising=False)
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY_1", key1, raising=False)
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY_2", key2, raising=False)
    clients = {0: SimpleNamespace(slot=0), 1: SimpleNamespace(slot=1)}
    monkeypatch.setattr(
        svc, "_get_groq_client", lambda: clients[0] if svc.settings.groq_api_keys else None)
    monkeypatch.setattr(
        svc, "_get_groq_client_2",
        lambda: clients[1] if len(svc.settings.groq_api_keys) > 1 else None)
    return clients


def _no_other_providers(monkeypatch):
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "", raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_API_KEY", "", raising=False)


def _record_groq(monkeypatch, outcomes):
    """
    Stub the Groq tool path. `outcomes` maps key_index -> LLMError to raise, or
    a string to return. Records the slots actually attempted, in order.
    """
    used: list[int] = []

    async def groq(*a, key_index=0, **k):
        used.append(key_index)
        result = outcomes.get(key_index, "answered")
        if isinstance(result, Exception):
            raise result
        return _Msg(result)

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq)
    return used


def _daily(slot):
    return LLMError(GROQ_TPD, kind=QUOTA_DAILY, provider=f"groq{slot or ''}",
                    retry_after=340.0)


# ── config: how the two variables resolve ────────────────────────────────────

def test_both_keys_are_offered_in_order(monkeypatch):
    _keys(monkeypatch)
    assert svc.settings.groq_api_keys == [KEY_1, KEY_2]


def test_legacy_groq_api_key_still_works(monkeypatch):
    """A deployment that predates the split must keep running untouched."""
    _keys(monkeypatch, key1="", key2="", legacy=KEY_1)
    assert svc.settings.groq_api_keys == [KEY_1]
    assert svc._configured("groq") is True
    assert svc._configured("groq2") is False
    assert svc._get_groq_client() is not None
    assert svc._get_groq_client_2() is None


def test_key_1_takes_precedence_over_the_legacy_name(monkeypatch):
    _keys(monkeypatch, key1=KEY_1, key2="", legacy="gsk_TESTONLYlegacy")
    assert svc.settings.groq_api_keys == [KEY_1]


def test_key_2_is_optional(monkeypatch):
    _keys(monkeypatch, key2="")
    assert svc.settings.groq_api_keys == [KEY_1]
    assert svc._configured("groq2") is False
    assert svc._groq_slots_to_try(has_fallback=False) == [0]


def test_the_same_key_twice_is_not_two_budgets(monkeypatch):
    """
    Rotating onto the account that just said its day is spent achieves nothing,
    and counting it twice would make the exhaustion checks wrong.
    """
    _keys(monkeypatch, key1=KEY_1, key2=KEY_1)
    assert svc.settings.groq_api_keys == [KEY_1]
    assert svc._configured("groq2") is False


def test_no_groq_key_at_all(monkeypatch):
    _keys(monkeypatch, key1="", key2="", legacy="")
    assert svc.settings.groq_api_keys == []
    assert svc._configured("groq") is False
    assert svc._groq_slots_to_try(has_fallback=True) == []


# ── the rotation itself ──────────────────────────────────────────────────────

def test_key_1_succeeds_without_touching_key_2(monkeypatch):
    _keys(monkeypatch)
    used = _record_groq(monkeypatch, {0: "from key 1"})

    msg = _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert msg.content == "from key 1"
    assert used == [0]


def test_key_1_daily_wall_rotates_to_key_2(monkeypatch):
    _keys(monkeypatch)
    used = _record_groq(monkeypatch, {0: _daily(0), 1: "from key 2"})

    msg = _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert msg.content == "from key 2"
    assert used == [0, 1]


def test_both_keys_daily_falls_through_to_the_existing_providers(monkeypatch):
    """Rotation is inserted BEFORE the old chain, it does not replace it."""
    _keys(monkeypatch)
    used = _record_groq(monkeypatch, {0: _daily(0), 1: _daily(1)})
    monkeypatch.setattr(svc, "_get_gemini_client", lambda: object())

    async def openrouter(*a, **k):
        return _Msg("from openrouter")

    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter)

    msg = _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert msg.content == "from openrouter"
    assert used == [0, 1]


def test_with_no_key_2_a_daily_wall_goes_straight_to_openrouter(monkeypatch):
    _keys(monkeypatch, key2="")
    used = _record_groq(monkeypatch, {0: _daily(0)})

    async def openrouter(*a, **k):
        return _Msg("from openrouter")

    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter)

    msg = _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert msg.content == "from openrouter"
    assert used == [0]


def test_a_known_daily_exhausted_key_is_not_retried_next_step(monkeypatch):
    """
    The agentic loop calls this once per tool step. Key 1's wall was recorded on
    step 1; step 2 must open on key 2, not spend a round trip rediscovering it.
    """
    _keys(monkeypatch)
    _no_other_providers(monkeypatch)
    used = _record_groq(monkeypatch, {0: _daily(0), 1: "from key 2"})

    _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert used == [0, 1]

    svc._groq_state.note_failure(QUOTA_DAILY, 340.0, GROQ_TPD)
    used.clear()
    _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert used == [1]


# ── failures that must NOT rotate ────────────────────────────────────────────

def test_413_does_not_rotate_the_key(monkeypatch):
    """
    Both keys run the same model, so the same oversized payload is refused
    identically. Rotating spends a second round trip to learn nothing.
    """
    _keys(monkeypatch)
    _no_other_providers(monkeypatch)
    err = LLMError(GROQ_413, kind=REQUEST_TOO_LARGE, provider="groq",
                   model=svc.settings.GROQ_MODEL)
    used = _record_groq(monkeypatch, {0: err, 1: "should never be reached"})

    with pytest.raises(LLMError) as caught:
        _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert caught.value.kind == REQUEST_TOO_LARGE
    assert used == [0]


def test_413_does_not_rotate_on_the_following_step_either(monkeypatch):
    """
    The subtle version: once key 1 is marked oversized, a naive slot filter
    would skip it and open the NEXT step on key 2 — rotating for a 413 one step
    late. The marker is shared across keys precisely to stop that.
    """
    _keys(monkeypatch)
    _no_other_providers(monkeypatch)
    used = _record_groq(monkeypatch, {0: "unused", 1: "unused"})

    svc._groq_state.note_oversized(svc.settings.GROQ_MODEL)
    svc._groq2_state.note_oversized(svc.settings.GROQ_MODEL)
    assert svc._groq_slots_to_try(has_fallback=False) == []

    with pytest.raises(LLMError):
        _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert used == []


def test_a_413_marks_every_groq_slot(monkeypatch):
    """_groq_exception_error is what puts the shared marker in place."""
    _keys(monkeypatch)

    class _Boom(Exception):
        body = {"error": {"message": GROQ_413}}
        status_code = 413

    svc._groq_exception_error(_Boom(), est_in=9000, key_index=0)
    assert svc.settings.GROQ_MODEL in svc._groq_state.oversized_models
    assert svc.settings.GROQ_MODEL in svc._groq2_state.oversized_models


def test_a_minute_wall_does_not_rotate(monkeypatch):
    """A per-minute window clears on its own; the other account is not the fix."""
    _keys(monkeypatch)
    err = LLMError(GROQ_TPM, kind=QUOTA_MINUTE, provider="groq", retry_after=8.0)
    used = _record_groq(monkeypatch, {0: err, 1: "should never be reached"})

    async def openrouter(*a, **k):
        return _Msg("from openrouter")

    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter)

    msg = _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert msg.content == "from openrouter"
    assert used == [0]


def test_an_application_bug_does_not_rotate(monkeypatch):
    """A malformed request is ours to fix — another account produces the same 400."""
    _keys(monkeypatch)
    _no_other_providers(monkeypatch)
    err = LLMError("tool call failed", kind=svc.TOOL_CALL_FAILURE, provider="groq")
    used = _record_groq(monkeypatch, {0: err, 1: "should never be reached"})

    with pytest.raises(LLMError) as caught:
        _run(svc.generate_with_tools(MESSAGES, tools=[]))
    assert caught.value.kind == svc.TOOL_CALL_FAILURE
    assert used == [0]


# ── independent cooldown state ───────────────────────────────────────────────

def test_cooldowns_are_tracked_per_key(monkeypatch):
    _keys(monkeypatch)
    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)

    assert svc._groq_state.daily_exhausted() is True
    assert svc._groq2_state.daily_exhausted() is False
    assert svc._groq2_state.available() is True
    assert svc._use_groq(True, 0) is False
    assert svc._use_groq(True, 1) is True

    health = svc.provider_health()
    assert health["groq"]["block_kind"] == QUOTA_DAILY
    assert health["groq2"]["block_kind"] == ""
    assert health["groq2"]["configured"] is True


def test_a_minute_wall_on_key_1_prefers_key_2_over_waiting(monkeypatch):
    """
    Not rotation-on-a-minute-error: key 1 is ALREADY parked when the call
    starts, and a ready sibling is a reason to skip a parked key rather than
    poke it — the same rule that already applied to OpenRouter and Gemini.
    """
    _keys(monkeypatch)
    _no_other_providers(monkeypatch)
    svc._groq_state.note_failure(QUOTA_MINUTE, 30.0, GROQ_TPM)
    assert svc._groq_slots_to_try(has_fallback=False) == [1]


def test_key_2_success_clears_only_its_own_state(monkeypatch):
    _keys(monkeypatch)
    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._groq2_state.note_failure(QUOTA_MINUTE, 30.0, GROQ_TPM)

    svc._groq2_state.note_success(svc.settings.GROQ_MODEL)
    assert svc._groq2_state.available() is True
    assert svc._groq_state.daily_exhausted() is True


def test_all_providers_exhausted_counts_key_2(monkeypatch):
    """A fresh key 2 means the day is NOT over, whatever the others say."""
    _keys(monkeypatch)
    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 3000.0, "daily")
    svc._gemini_state.note_failure(QUOTA_DAILY, 3000.0, "daily")
    assert svc.all_providers_exhausted() is False

    svc._groq2_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    assert svc.all_providers_exhausted() is True
    assert svc._no_provider_error().kind == QUOTA_DAILY


# ── attribution ──────────────────────────────────────────────────────────────

def test_logs_identify_which_key_answered(monkeypatch, caplog):
    _keys(monkeypatch)
    _no_other_providers(monkeypatch)

    async def groq(*a, key_index=0, **k):
        if key_index == 0:
            raise _daily(0)
        # Key 2 logs its success exactly the way the real path does.
        svc._log_call(svc._GROQ_SLOT_NAMES[key_index], svc.settings.GROQ_MODEL,
                      est_in=100, status="ok")
        return _Msg("from key 2")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq)

    svc.begin_turn()
    with caplog.at_level(logging.INFO, logger="services.llm_service"):
        _run(svc.generate_with_tools(MESSAGES, tools=[]))

    assert svc.answering_provider() == "groq2"
    assert svc.answering_model() == svc.settings.GROQ_MODEL
    assert any("provider=groq2" in r.getMessage() for r in caplog.records)


# ── the keys themselves never leave the SDK call ─────────────────────────────

class _FakeGroqError(Exception):
    def __init__(self, message, status_code=429):
        super().__init__(message)
        self.body = {"error": {"message": message}}
        self.status_code = status_code


class _FakeGroqClient:
    """Minimal stand-in for AsyncGroq: records the key, then fails or answers."""

    seen_keys: list[str] = []

    def __init__(self, api_key, max_retries=0):
        _FakeGroqClient.seen_keys.append(api_key)
        self.chat = SimpleNamespace(
            completions=SimpleNamespace(create=self._create))

    async def _create(self, **kwargs):
        raise _FakeGroqError(GROQ_TPD)


def test_no_api_key_ever_reaches_a_log_line_or_an_error(monkeypatch, caplog):
    """
    Exercises the REAL client construction and the REAL error path — the two
    places a key could plausibly be echoed — and asserts neither key appears in
    any log record, the raised error, or the health snapshot.
    """
    import groq as groq_sdk

    monkeypatch.setattr(svc.settings, "GROQ_API_KEY", "", raising=False)
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY_1", KEY_1, raising=False)
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY_2", KEY_2, raising=False)
    monkeypatch.setattr(svc, "_groq_client", None, raising=False)
    monkeypatch.setattr(svc, "_groq_client_2", None, raising=False)
    monkeypatch.setattr(groq_sdk, "AsyncGroq", _FakeGroqClient)
    _no_other_providers(monkeypatch)
    _FakeGroqClient.seen_keys.clear()

    caplog.set_level(logging.DEBUG)
    with pytest.raises(LLMError) as caught:
        _run(svc.generate_with_tools(MESSAGES, tools=[]))

    # Both keys really were used — otherwise this proves nothing.
    assert _FakeGroqClient.seen_keys == [KEY_1, KEY_2]
    assert caught.value.kind == QUOTA_DAILY

    logged = "\n".join(r.getMessage() for r in caplog.records)
    assert "key 1" in logged and "key 2" in logged      # positions are logged
    for secret in (KEY_1, KEY_2):
        assert secret not in logged
        assert secret not in str(caught.value)
        assert secret not in repr(svc.provider_health())
