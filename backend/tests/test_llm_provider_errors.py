"""
Provider failure classification, reset-aware cooldowns, and the fallback chain.

Every error string here is a REAL body observed from the provider, not a
paraphrase — the whole point of the classifier is that Groq's daily wall and its
per-minute wall are the same status code with the same headers, so the tests are
only meaningful if the bodies are verbatim.
"""
import asyncio
import time

import pytest

from services import llm_service as svc
from services.llm_service import (
    INVALID_KEY,
    LLMError,
    PROVIDER_UNAVAILABLE,
    QUOTA_DAILY,
    QUOTA_MINUTE,
    REQUEST_TOO_LARGE,
    classify_provider_error,
    estimate_request_tokens,
    estimate_tokens,
)

# ── Real provider bodies ──────────────────────────────────────────────────────

GROQ_TPD = (
    "Rate limit reached for model `llama-3.3-70b-versatile` in organization "
    "`org_01abc` service tier `on_demand` on tokens per day (TPD): Limit 100000, "
    "Used 91437, Requested 8635. Please try again in 5m39.6s. Visit "
    "https://console.groq.com/docs/rate-limits for more information."
)
GROQ_TPM = (
    "Rate limit reached for model `llama-3.3-70b-versatile` in organization "
    "`org_01abc` service tier `on_demand` on tokens per minute (TPM): Limit 12000, "
    "Used 11000, Requested 8635. Please try again in 7.66s."
)
GROQ_413 = (
    "Request too large for model `llama-3.1-8b-instant` in organization `org_01abc` "
    "service tier `on_demand` on tokens per minute (TPM): Limit 6000, Requested 9198, "
    "please reduce your message size and try again."
)
OPENROUTER_DAILY = "Rate limit exceeded: free-models-per-day"
OPENROUTER_413 = "Input is too long for requested model"
GEMINI_DAILY = (
    "429 RESOURCE_EXHAUSTED. quota_metric: generativelanguage.googleapis.com/"
    "generate_content_free_tier_requests, quota_id: "
    "GenerateRequestsPerDayPerProjectPerModel-FreeTier"
)
GEMINI_MINUTE = (
    "429 RESOURCE_EXHAUSTED. quota_id: "
    "GenerateRequestsPerMinutePerProjectPerModel-FreeTier, retryDelay: 25s"
)


# ── Classification ────────────────────────────────────────────────────────────

def test_groq_daily_wall_is_not_a_minute_wall():
    """The bug that started all of this: TPD read as an ordinary per-minute 429."""
    kind, retry = classify_provider_error(GROQ_TPD, status_code=429)
    assert kind == QUOTA_DAILY
    assert retry == pytest.approx(339.6, abs=0.1)   # 5m39.6s


def test_groq_minute_wall_classified_and_reset_parsed():
    kind, retry = classify_provider_error(GROQ_TPM, status_code=429)
    assert kind == QUOTA_MINUTE
    assert retry == pytest.approx(7.66, abs=0.01)


def test_groq_request_too_large_beats_the_tpm_wording_in_the_same_body():
    """
    GROQ_413 says "per minute (TPM)" too. Classifying it as a rate limit would
    park the provider and retry the identical payload, which can only fail again.
    """
    kind, retry = classify_provider_error(GROQ_413, status_code=413)
    assert kind == REQUEST_TOO_LARGE
    assert retry is None


def test_openrouter_hyphenated_daily_marker():
    kind, _ = classify_provider_error(OPENROUTER_DAILY, status_code=429)
    assert kind == QUOTA_DAILY


def test_openrouter_input_too_long():
    kind, _ = classify_provider_error(OPENROUTER_413, status_code=400)
    assert kind == REQUEST_TOO_LARGE


def test_gemini_camelcase_perday_marker():
    kind, _ = classify_provider_error(GEMINI_DAILY, status_code=429)
    assert kind == QUOTA_DAILY


def test_gemini_camelcase_perminute_marker():
    kind, _ = classify_provider_error(GEMINI_MINUTE, status_code=429)
    assert kind == QUOTA_MINUTE


def test_invalid_key():
    kind, _ = classify_provider_error("Invalid API Key", status_code=401)
    assert kind == INVALID_KEY


def test_unknown_error_is_provider_unavailable():
    kind, _ = classify_provider_error("upstream connect error", status_code=502)
    assert kind == PROVIDER_UNAVAILABLE


def test_unlabelled_429_with_a_long_reset_is_treated_as_daily():
    """No per-minute bucket ever asks you to wait ten minutes."""
    kind, retry = classify_provider_error(
        "Too many requests. Please try again in 10m0s.", status_code=429
    )
    assert kind == QUOTA_DAILY
    assert retry == pytest.approx(600.0)


def test_unlabelled_429_with_a_short_reset_is_treated_as_minute():
    kind, _ = classify_provider_error(
        "Too many requests. Please try again in 12s.", status_code=429
    )
    assert kind == QUOTA_MINUTE


class _Headers(dict):
    """httpx-style case-insensitive-ish header bag; .get is all we use."""


def test_retry_after_header_used_when_body_says_nothing():
    kind, retry = classify_provider_error(
        "rate limit", status_code=429, headers=_Headers({"retry-after": "42"})
    )
    assert kind == QUOTA_MINUTE
    assert retry == pytest.approx(42.0)


def test_openrouter_epoch_reset_header_converted_to_seconds():
    future_ms = str(int((time.time() + 600) * 1000))
    headers = _Headers()
    headers["X-RateLimit-Reset"] = future_ms
    _, retry = classify_provider_error(
        "rate limit", status_code=429, headers=headers
    )
    assert retry is not None and 550 < retry < 650


# ── Reset-aware cooldown ──────────────────────────────────────────────────────

def test_daily_cooldown_is_not_capped_at_the_old_900s_ceiling():
    """
    The previous code clamped every cooldown to 900s, so a wall that resets in
    50 minutes was re-probed after 15 — three wasted round trips per turn.
    """
    state = svc._ProviderState("groq")
    state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    assert state.seconds_left() > 2900
    assert state.daily_exhausted() is True
    assert state.available() is False


def test_daily_cooldown_is_still_bounded_at_24h():
    state = svc._ProviderState("groq")
    state.note_failure(QUOTA_DAILY, 10 ** 9, GROQ_TPD)
    assert state.seconds_left() <= 24 * 3600 + 1


def test_daily_wall_without_a_reset_uses_a_conservative_default():
    state = svc._ProviderState("groq")
    state.note_failure(QUOTA_DAILY, None, "daily quota")
    assert 1000 < state.seconds_left() <= svc._DAILY_DEFAULT_COOLDOWN + 1


def test_minute_cooldown_keeps_fast_recovery():
    state = svc._ProviderState("groq")
    state.note_failure(QUOTA_MINUTE, 7.66, GROQ_TPM)
    # Floored so we don't hot-loop, but still well inside one interactive turn.
    assert state.seconds_left() <= svc._MINUTE_MAX_COOLDOWN
    assert state.seconds_left() >= svc._MINUTE_MIN_COOLDOWN - 1
    assert state.daily_exhausted() is False


def test_minute_cooldown_cannot_be_stretched_into_a_daily_one():
    state = svc._ProviderState("groq")
    state.note_failure(QUOTA_MINUTE, 100000.0, "odd header")
    assert state.seconds_left() <= svc._MINUTE_MAX_COOLDOWN


def test_request_too_large_marks_the_model_not_the_provider():
    """A 413 is about THIS payload — the provider itself is still healthy."""
    state = svc._ProviderState("openrouter")
    err = svc._note_provider_error(state, GROQ_413, status_code=413, model="tiny-model")
    assert err.kind == REQUEST_TOO_LARGE
    assert state.available() is True          # not parked
    assert "tiny-model" in state.oversized_models


def test_success_clears_the_oversized_marker():
    state = svc._ProviderState("openrouter")
    state.note_oversized("tiny-model")
    state.note_success("tiny-model")
    assert "tiny-model" not in state.oversized_models


def test_all_providers_exhausted_only_counts_daily_walls(monkeypatch):
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY", "k", raising=False)
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "k", raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_API_KEY", "k", raising=False)

    assert svc.all_providers_exhausted() is False

    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 3000.0, OPENROUTER_DAILY)
    assert svc.all_providers_exhausted() is False        # gemini still fine

    # A per-minute wall on the last provider does NOT count — it clears in seconds.
    svc._gemini_state.note_failure(QUOTA_MINUTE, 20.0, GEMINI_MINUTE)
    assert svc.all_providers_exhausted() is False

    svc._gemini_state.note_failure(QUOTA_DAILY, 3000.0, GEMINI_DAILY)
    assert svc.all_providers_exhausted() is True


def test_use_groq_refuses_a_known_daily_wall_even_with_no_fallback(monkeypatch):
    """
    With no fallback the old rule was "try anyway", which is right for a minute
    wall and wrong for a daily one — that budget is measurably gone.

    `_use_groq` also answers False when Groq isn't configured at all, so the
    client is stubbed: this test is about the QUOTA decision, and it must give
    the same answer on a machine with no GROQ_API_KEY as on one with a live key.
    """
    monkeypatch.setattr(svc, "_get_groq_client", lambda: object())

    svc._groq_state.note_failure(QUOTA_MINUTE, 20.0, GROQ_TPM)
    assert svc._use_groq(has_fallback=False) is True

    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    assert svc._use_groq(has_fallback=False) is False


def test_use_groq_is_false_when_groq_is_not_configured(monkeypatch):
    """The companion case — no key means no attempt, cooldown or not."""
    monkeypatch.setattr(svc, "_get_groq_client", lambda: None)
    assert svc._use_groq(has_fallback=False) is False
    assert svc._use_groq(has_fallback=True) is False


# ── Token estimation ──────────────────────────────────────────────────────────

def test_estimate_tokens_tracks_length():
    assert estimate_tokens("") == 1
    assert 20 <= estimate_tokens("x" * 100) <= 30


def test_estimate_request_tokens_counts_tool_schemas():
    """
    Tool schemas were invisible in every earlier size calculation, and they are
    a quarter of the payload.
    """
    messages = [{"role": "user", "content": "hi"}]
    tools = [{"type": "function", "function": {
        "name": "search_flights", "description": "x" * 400, "parameters": {}}}]
    bare = estimate_request_tokens(messages)
    withtools = estimate_request_tokens(messages, tools)
    assert withtools > bare + 90


def test_estimate_request_tokens_counts_tool_calls_on_assistant_turns():
    messages = [{
        "role": "assistant", "content": None,
        "tool_calls": [{"id": "1", "type": "function", "function": {
            "name": "search_flights", "arguments": '{"origin_city":"Lahore"}'}}],
    }]
    assert estimate_request_tokens(messages) > 10


def test_estimate_matches_the_real_groq_figure_within_10_percent():
    """
    Calibration check. Groq reported "Requested 8635" for the old fixed payload;
    the chars/4 heuristic estimated 8,885 for the same content. If this drifts,
    the request-size logs stop being trustworthy.
    """
    from prompts.master_agent import MASTER_AGENTIC_SYSTEM
    from agents.agent_tools import TOOL_SCHEMAS

    system = MASTER_AGENTIC_SYSTEM.format(
        weekday="Wednesday", today="2026-07-29", memory="(none)")
    est = estimate_request_tokens([{"role": "system", "content": system}], TOOL_SCHEMAS)
    assert 7800 <= est <= 9500, est


# ── Fallback chain ────────────────────────────────────────────────────────────

class _FakeMessage:
    def __init__(self, content="ok", tool_calls=None):
        self.content = content
        self.tool_calls = tool_calls or []


def _run(coro):
    return asyncio.run(coro)


def _configure_all(monkeypatch):
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY", "k", raising=False)
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "k", raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_API_KEY", "k", raising=False)
    monkeypatch.setattr(svc, "_get_groq_client", lambda: object())
    monkeypatch.setattr(svc, "_get_gemini_client", lambda: object())


def test_generate_with_tools_falls_through_groq_to_openrouter(monkeypatch):
    _configure_all(monkeypatch)
    called = []

    async def groq_fail(*a, **k):
        called.append("groq")
        raise LLMError("tpd", kind=QUOTA_DAILY, provider="groq", retry_after=300)

    async def openrouter_ok(*a, **k):
        called.append("openrouter")
        return _FakeMessage("from openrouter")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq_fail)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter_ok)

    msg = _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert msg.content == "from openrouter"
    assert called == ["groq", "openrouter"]


def test_generate_with_tools_reaches_gemini_when_the_first_two_are_out(monkeypatch):
    """
    Gemini used to be text-only, so this chain ended at OpenRouter and the whole
    agentic path died for the rest of the day once two budgets were spent.
    """
    _configure_all(monkeypatch)
    called = []

    async def groq_fail(*a, **k):
        called.append("groq")
        raise LLMError("tpd", kind=QUOTA_DAILY, provider="groq", retry_after=300)

    async def openrouter_fail(*a, **k):
        called.append("openrouter")
        raise LLMError("daily", kind=QUOTA_DAILY, provider="openrouter", retry_after=300)

    async def gemini_ok(*a, **k):
        called.append("gemini")
        return _FakeMessage("from gemini")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq_fail)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter_fail)
    monkeypatch.setattr(svc, "_gemini_generate_with_tools", gemini_ok)

    msg = _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert msg.content == "from gemini"
    assert called == ["groq", "openrouter", "gemini"]


def test_generate_with_tools_raises_the_typed_cause_when_all_fail(monkeypatch):
    _configure_all(monkeypatch)

    async def fail_daily(*a, **k):
        raise LLMError("tpd", kind=QUOTA_DAILY, provider="x", retry_after=300)

    monkeypatch.setattr(svc, "_groq_generate_with_tools", fail_daily)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", fail_daily)
    monkeypatch.setattr(svc, "_gemini_generate_with_tools", fail_daily)

    with pytest.raises(LLMError) as excinfo:
        _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert excinfo.value.kind == QUOTA_DAILY


def test_a_provider_on_a_daily_wall_is_skipped_entirely(monkeypatch):
    """No request is even attempted against a provider whose budget is known gone."""
    _configure_all(monkeypatch)
    called = []

    async def groq(*a, **k):
        called.append("groq")
        return _FakeMessage("groq")

    async def gemini(*a, **k):
        called.append("gemini")
        return _FakeMessage("gemini")

    async def openrouter(*a, **k):
        called.append("openrouter")
        return _FakeMessage("openrouter")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter)
    monkeypatch.setattr(svc, "_gemini_generate_with_tools", gemini)

    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 3000.0, OPENROUTER_DAILY)

    msg = _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert msg.content == "gemini"
    assert called == ["gemini"]


def test_all_in_minute_cooldown_still_retries_rather_than_giving_up(monkeypatch):
    """
    A per-minute wall recorded seconds ago has usually cleared. Reporting failure
    without asking anyone is worse than one cheap attempt.
    """
    _configure_all(monkeypatch)
    called = []

    async def groq(*a, **k):
        called.append("groq")
        return _FakeMessage("groq recovered")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq)
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "", raising=False)

    svc._groq_state.note_failure(QUOTA_MINUTE, 60.0, GROQ_TPM)
    svc._gemini_state.note_failure(QUOTA_MINUTE, 60.0, GEMINI_MINUTE)

    msg = _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert msg.content == "groq recovered"
    assert called == ["groq"]


def test_tool_capable_providers_lists_only_configured_ones(monkeypatch):
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY", "k", raising=False)
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "", raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_API_KEY", "k", raising=False)
    assert svc.tool_capable_providers() == ["groq", "gemini"]


# ── Gemini native function-calling translation ────────────────────────────────

def test_gemini_tool_declarations_built_from_our_openai_schemas():
    from agents.agent_tools import TOOL_SCHEMAS

    decls = svc._gemini_tool_declarations(TOOL_SCHEMAS)
    assert len(decls) == len(TOOL_SCHEMAS)
    assert {d.name for d in decls} == {t["function"]["name"] for t in TOOL_SCHEMAS}


def test_retired_gemini_model_falls_back_to_the_latest_alias(monkeypatch):
    """
    Google keeps a retired model id listed in models.list() but serves it only to
    accounts that already used it — a newer key gets 404 "no longer available to
    new users". That silently disabled this project's whole Gemini fallback, and
    because .env pins the id, config alone cannot fix it.
    """
    monkeypatch.setattr(svc, "_gemini_active_model", None, raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_MODEL", "gemini-2.5-flash", raising=False)
    assert svc._gemini_model() == "gemini-2.5-flash"

    switched = svc._switch_gemini_model_if_retired(
        "404 NOT_FOUND. This model models/gemini-2.5-flash is no longer available "
        "to new users."
    )
    assert switched is True
    assert svc._gemini_model() == svc._GEMINI_MODEL_ALIAS

    # Already on the alias — no second switch, so we can't loop.
    assert svc._switch_gemini_model_if_retired("no longer available") is False


def test_an_ordinary_gemini_error_does_not_switch_models(monkeypatch):
    monkeypatch.setattr(svc, "_gemini_active_model", None, raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_MODEL", "gemini-2.5-flash", raising=False)
    assert svc._switch_gemini_model_if_retired("429 RESOURCE_EXHAUSTED") is False
    assert svc._gemini_model() == "gemini-2.5-flash"


def test_thought_signature_is_reattached_to_a_returned_function_call():
    """
    Gemini 3 rejects a function_call handed back without its opaque
    thought_signature ("Function call is missing a thought_signature in
    functionCall parts"), which kills round 2 of every tool loop. The signature
    has nowhere to live in the provider-neutral OpenAI message shape, so it is
    cached by call id and re-attached during translation.
    """
    svc._gemini_signatures.clear()
    svc._remember_signature("gemini_abc12345_0", b"sig-bytes")

    messages = [
        {"role": "user", "content": "flights please"},
        {"role": "assistant", "content": None, "tool_calls": [{
            "id": "gemini_abc12345_0", "type": "function",
            "function": {"name": "search_flights", "arguments": "{}"},
        }]},
        {"role": "tool", "tool_call_id": "gemini_abc12345_0", "content": "{}"},
    ]
    contents = svc._gemini_contents_from_openai(messages)
    model_turn = contents[1]
    assert model_turn.parts[0].thought_signature == b"sig-bytes"


def test_a_call_with_no_signature_still_translates():
    """
    It must still translate — but NOT as a structured call.

    This used to assert the opposite (send it through unsigned), which read as
    the tolerant choice and was the exact thing Gemini 400s on. See
    test_a_tool_call_from_another_provider_is_replayed_as_text below for the
    failure that produced the change.
    """
    svc._gemini_signatures.clear()
    messages = [{"role": "assistant", "content": None, "tool_calls": [{
        "id": "groq_call_0", "type": "function",
        "function": {"name": "search_flights", "arguments": "{}"},
    }]}]
    contents = svc._gemini_contents_from_openai(messages)
    part = contents[0].parts[0]
    assert part.function_call is None
    assert not part.thought_signature
    assert "search_flights" in part.text


def test_signature_cache_is_bounded():
    svc._gemini_signatures.clear()
    for i in range(svc._GEMINI_SIGNATURE_CACHE_MAX + 50):
        svc._remember_signature(f"call_{i}", b"x")
    assert len(svc._gemini_signatures) <= svc._GEMINI_SIGNATURE_CACHE_MAX
    svc._gemini_signatures.clear()


_TOOL_TURN = [
    {"role": "system", "content": "sys"},
    {"role": "user", "content": "flights please"},
    {"role": "assistant", "content": None, "tool_calls": [{
        "id": "call_1", "type": "function",
        "function": {"name": "search_flights", "arguments": '{"origin_city":"Lahore"}'},
    }]},
    {"role": "tool", "tool_call_id": "call_1", "content": '{"flights":[{"n":"ER937"}]}'},
]


def test_gemini_message_translation_round_trips_its_own_tool_turn():
    """
    Gemini has no tool_call_id, so a tool RESULT is matched back to its function
    by name via the assistant turn that requested it. If that mapping breaks, the
    model sees an answer with no question.

    The signature is pre-seeded because this is the GEMINI-MADE case: Gemini
    returned that call, so we hold its thought_signature and can send it back
    structured.
    """
    svc._gemini_signatures["call_1"] = b"sig"
    try:
        contents = svc._gemini_contents_from_openai(_TOOL_TURN)
    finally:
        svc._gemini_signatures.pop("call_1", None)

    # system is hoisted out, so: user, model(function_call), user(function_response)
    assert [c.role for c in contents] == ["user", "model", "user"]
    assert contents[1].parts[0].function_call.name == "search_flights"
    assert contents[1].parts[0].function_call.args == {"origin_city": "Lahore"}
    assert contents[1].parts[0].thought_signature == b"sig"
    assert contents[2].parts[0].function_response.name == "search_flights"


def test_a_tool_call_from_another_provider_is_replayed_as_text():
    """
    The mid-turn handover case, and a live failure before it was fixed.

    Groq or OpenRouter makes the tool call, then dies on the synthesis step, and
    Gemini inherits a history full of another model's calls. Gemini rejects any
    functionCall part it did not produce — 400, "Function call is missing a
    thought_signature" — so the whole turn came back as the generic fallback
    message despite the flight data having already been fetched.

    With no signature the exchange is replayed as text instead: same
    information, no structured call for Gemini to object to.
    """
    svc._gemini_signatures.pop("call_1", None)
    contents = svc._gemini_contents_from_openai(_TOOL_TURN)

    assert [c.role for c in contents] == ["user", "model", "user"]
    call_part = contents[1].parts[0]
    assert call_part.function_call is None
    assert "search_flights" in call_part.text
    assert "Lahore" in call_part.text

    result_part = contents[2].parts[0]
    assert result_part.function_response is None
    # The data itself must survive the downgrade — that is the whole point.
    assert "ER937" in result_part.text


def test_a_mixed_history_keeps_the_signed_call_structured():
    """One provider's call downgraded must not drag Gemini's own call down with it."""
    svc._gemini_signatures["gemini_call"] = b"sig"
    try:
        contents = svc._gemini_contents_from_openai([
            {"role": "user", "content": "flights please"},
            {"role": "assistant", "content": None, "tool_calls": [
                {"id": "foreign_call", "type": "function",
                 "function": {"name": "search_flights", "arguments": "{}"}},
                {"id": "gemini_call", "type": "function",
                 "function": {"name": "search_hotels", "arguments": "{}"}},
            ]},
            {"role": "tool", "tool_call_id": "foreign_call", "content": '{"flights":[]}'},
            {"role": "tool", "tool_call_id": "gemini_call", "content": '{"hotels":[]}'},
        ])
    finally:
        svc._gemini_signatures.pop("gemini_call", None)

    model_parts = contents[1].parts
    assert model_parts[0].function_call is None            # foreign -> text
    assert model_parts[1].function_call.name == "search_hotels"  # ours -> structured
    assert contents[2].parts[0].function_response is None  # foreign result -> text
    assert contents[3].parts[0].function_response.name == "search_hotels"


# ── The "we never even sent a request" error must still be typed ──────────────
#
# Everything above tests a failure we observed. This block tests the failure we
# DIDN'T observe, because we knew better than to ask — and that path used to
# collapse every reason into a generic provider_unavailable, which the router
# renders as "something went wrong, try again". Told that, a user retries
# immediately, against a wall we already know lasts hours.

def test_no_provider_error_is_typed_quota_when_every_provider_is_daily_walled():
    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 3000.0, OPENROUTER_DAILY)
    svc._gemini_state.note_failure(QUOTA_DAILY, 3000.0, GEMINI_DAILY)

    err = svc._no_provider_error()
    assert err.kind == QUOTA_DAILY
    assert err.retry_after and err.retry_after > 60


def test_no_provider_error_stays_generic_when_a_minute_wall_is_in_the_mix():
    """A minute wall clears in seconds — calling that a daily quota would lie."""
    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 3000.0, OPENROUTER_DAILY)
    svc._gemini_state.note_failure(QUOTA_MINUTE, 20.0, GEMINI_MINUTE)

    assert svc._no_provider_error().kind == PROVIDER_UNAVAILABLE


def test_no_provider_error_is_a_config_fault_when_nothing_is_configured(monkeypatch):
    monkeypatch.setattr(svc.settings, "GROQ_API_KEY", "", raising=False)
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "", raising=False)
    monkeypatch.setattr(svc.settings, "GEMINI_API_KEY", "", raising=False)
    assert svc._no_provider_error().kind == PROVIDER_UNAVAILABLE


def test_generate_with_tools_reports_quota_daily_when_all_three_are_walled(monkeypatch):
    """End-to-end version of the above, through the real chain."""
    _configure_all(monkeypatch)

    async def never(*a, **k):
        raise AssertionError("no provider should have been asked")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", never)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", never)
    monkeypatch.setattr(svc, "_gemini_generate_with_tools", never)

    svc._groq_state.note_failure(QUOTA_DAILY, 3000.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 3000.0, OPENROUTER_DAILY)
    svc._gemini_state.note_failure(QUOTA_DAILY, 3000.0, GEMINI_DAILY)

    with pytest.raises(LLMError) as caught:
        _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert caught.value.kind == QUOTA_DAILY


# ── A 413'd model is not asked twice in the same turn ─────────────────────────

def test_an_oversized_model_is_skipped_on_the_next_step(monkeypatch):
    """
    The agentic loop calls generate_with_tools once per tool step, and each step
    is STRICTLY bigger than the last (it carries the previous results). So a 413
    on step 1 guarantees a 413 on step 2 — asking again just burns the turn.
    """
    _configure_all(monkeypatch)
    called: list[str] = []

    async def groq(*a, **k):
        called.append("groq")
        raise svc._note_provider_error(
            svc._groq_state, GROQ_413, status_code=413, model=svc.settings.GROQ_MODEL,
        )

    async def openrouter(*a, **k):
        called.append("openrouter")
        return _FakeMessage("from openrouter")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", openrouter)

    # Step 1: Groq is asked, refuses on size, OpenRouter answers.
    _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert called == ["groq", "openrouter"]

    # Step 2 (same turn, larger payload): Groq must not be asked again.
    _run(svc.generate_with_tools([{"role": "user", "content": "hi again"}], tools=[]))
    assert called == ["groq", "openrouter", "openrouter"]

    # A 413 is about the payload, not the provider — Groq is still healthy, and
    # a successful call clears the marker so a shrunken payload re-enables it.
    assert svc._groq_state.available() is True
    svc._groq_state.note_success(svc.settings.GROQ_MODEL)
    _run(svc.generate_with_tools([{"role": "user", "content": "small"}], tools=[]))
    assert called.count("groq") == 2      # asked again once the marker cleared


def test_an_oversized_model_does_not_block_the_all_in_cooldown_retry(monkeypatch):
    """
    The last-resort pass exists because a minute wall usually cleared already.
    That reasoning does not apply to a 413, so the oversized model stays skipped
    even there — otherwise the fallback of last resort is a guaranteed failure.
    """
    _configure_all(monkeypatch)
    monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "", raising=False)
    called: list[str] = []

    async def groq(*a, **k):
        called.append("groq")
        return _FakeMessage("groq answered")

    async def gemini(*a, **k):
        called.append("gemini")
        return _FakeMessage("gemini answered")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", groq)
    monkeypatch.setattr(svc, "_gemini_generate_with_tools", gemini)

    svc._groq_state.note_oversized(svc.settings.GROQ_MODEL)
    svc._groq_state.note_failure(QUOTA_MINUTE, 60.0, GROQ_TPM)
    svc._gemini_state.note_failure(QUOTA_MINUTE, 60.0, GEMINI_MINUTE)

    msg = _run(svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[]))
    assert msg.content == "gemini answered"
    assert "groq" not in called


# ── Attribution: what actually answered ──────────────────────────────────────

def test_answering_model_reports_the_provider_that_really_served_the_turn(monkeypatch):
    """
    Saved history used to record settings.GROQ_MODEL unconditionally, so a turn
    served by Gemini was filed under Groq — exactly the record you need when you
    are working out why one turn behaved differently from the next.

    The read happens after the call and OUTSIDE the task the call ran in, which
    is the real shape: master_agent persists model_used at the end of the turn,
    while the provider was chosen several frames down inside an asyncio.wait_for.
    """
    _configure_all(monkeypatch)

    async def fail(*a, **k):
        raise LLMError("tpd", kind=QUOTA_DAILY, provider="groq", retry_after=300)

    async def gemini_ok(*a, **k):
        svc._log_call("gemini", "gemini-2.5-flash", est_in=100, status="ok")
        return _FakeMessage("from gemini")

    monkeypatch.setattr(svc, "_groq_generate_with_tools", fail)
    monkeypatch.setattr(svc, "_openrouter_generate_with_tools", fail)
    monkeypatch.setattr(svc, "_gemini_generate_with_tools", gemini_ok)

    async def one_turn():
        svc.begin_turn()
        # A child task — the strictest case for context propagation.
        await asyncio.wait_for(
            asyncio.create_task(
                svc.generate_with_tools([{"role": "user", "content": "hi"}], tools=[])
            ),
            timeout=5,
        )
        return svc.answering_model(), svc.answering_provider()

    model, provider = _run(one_turn())
    assert model == "gemini-2.5-flash"
    assert provider == "gemini"


def test_answering_model_falls_back_to_the_configured_model_with_no_call(monkeypatch):
    """A turn answered deterministically made no call — record the config, not a lie."""
    monkeypatch.setattr(svc.settings, "GROQ_MODEL", "llama-3.3-70b-versatile", raising=False)
    svc.begin_turn()
    assert svc.answering_model() == "llama-3.3-70b-versatile"
    assert svc.answering_provider() is None


# ── The isolation the rest of this file depends on ───────────────────────────

def test_provider_state_leaks_out_of_this_test():
    """Deliberately park every provider. The next test proves it was cleaned up."""
    svc._groq_state.note_failure(QUOTA_DAILY, 86400.0, GROQ_TPD)
    svc._openrouter_state.note_failure(QUOTA_DAILY, 86400.0, OPENROUTER_DAILY)
    svc._gemini_state.note_failure(QUOTA_DAILY, 86400.0, GEMINI_DAILY)
    svc._groq_state.note_oversized("llama-3.3-70b-versatile")
    assert svc.all_providers_exhausted() is True


def test_provider_state_is_clean_again(monkeypatch):
    """
    Cooldowns are module-level on purpose (they must outlive one request), which
    makes them the obvious way for one test to silently decide another's result.
    The autouse fixture in conftest.py resets them; this asserts it works.
    """
    _configure_all(monkeypatch)
    assert svc.all_providers_exhausted() is False
    assert svc._groq_state.available() is True
    assert svc._groq_state.oversized_models == set()


# ── OpenRouter must not starve the provider behind it ────────────────────────
#
# OpenRouter sits AHEAD of Gemini, so whatever it spends, Gemini does without.
# At the original 35s total, both Groq keys on a daily wall plus queuing ':free'
# models left Gemini ~15s of a 52s turn — less once a tool call had run — and
# "roundtrip available?", a question needing no tools at all, came back as
# "that's taking longer than it should". The fastest provider in the chain was
# being starved by the slowest.
#
# These are arithmetic invariants rather than behaviour: the failure mode is a
# constant drifting upward again, which no behavioural test would catch.

def test_openrouter_leaves_gemini_a_usable_share_of_the_turn():
    from agents.master_agent import _TURN_BUDGET

    worst_case_openrouter = (
        svc._OPENROUTER_TOTAL_BUDGET + svc._OPENROUTER_REQUEST_TIMEOUT
    )  # a fast 429 on the first model, then the second one hangs
    left_for_gemini = _TURN_BUDGET - worst_case_openrouter
    assert left_for_gemini >= 10.0, (
        f"OpenRouter can spend {worst_case_openrouter}s of a {_TURN_BUDGET}s turn, "
        f"leaving Gemini {left_for_gemini}s"
    )


def test_the_budget_still_admits_one_complete_request():
    """
    Below the per-request timeout, a healthy-but-slow model would be cut off by
    the outer deadline before its own timeout fired — bounding OpenRouter into
    uselessness rather than bounding its worst case.
    """
    assert svc._OPENROUTER_TOTAL_BUDGET >= svc._OPENROUTER_REQUEST_TIMEOUT


def test_a_whole_openrouter_attempt_fits_inside_the_client_window():
    """The Flutter client gives up at 60s; the turn budget must beat it."""
    from agents.master_agent import _TURN_BUDGET

    assert _TURN_BUDGET < 60.0
    assert svc._OPENROUTER_TOTAL_BUDGET < _TURN_BUDGET
