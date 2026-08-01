from __future__ import annotations
# =============================================================================
# PURPOSE: Unified LLM service — Groq primary, OpenRouter + Gemini as fallbacks.
#
#   Public API (all agents import these):
#       generate_text(messages, *, temperature, max_output_tokens) -> str
#       generate_json(messages, *, temperature, max_output_tokens) -> Any
#       generate_with_tools(messages, tools, ...)  -> assistant message object
#       LLMError  — raised on unrecoverable failures, carrying a typed `.kind`
#
#   Provider priority:
#       1. Groq   (settings.GROQ_MODEL)       — primary (free, fast, cheap on quota)
#       2. OpenRouter (settings.OPENROUTER_MODEL) — second independent budget
#       3. Gemini (settings.GEMINI_MODEL)     — third budget, ALSO tool-capable
#
#   All three speak tool calling: Groq/OpenRouter over the OpenAI schema, Gemini
#   over its native function-calling API (see _gemini_generate_with_tools).
# =============================================================================

import asyncio
import contextvars
import json
import logging
import re
import time
import uuid
from typing import Any

import httpx

from core.config import settings

logger = logging.getLogger(__name__)


# Which provider/model actually produced the last answer on THIS request.
#
# Saved history used to record settings.GROQ_MODEL unconditionally, so a turn
# that Gemini or OpenRouter actually served was filed under Groq — and that is
# the single field you most want to be true when you are working out why one
# turn behaved differently from the next.
#
# A ContextVar, not a module global: FastAPI runs every request in its own task,
# so two concurrent chats cannot overwrite each other's attribution.
#
# The var holds a MUTABLE dict rather than the value itself, and that detail is
# load-bearing. A child context (anything wrapped in create_task/gather, and
# asyncio.wait_for on Python ≤3.11) gets a COPY of the context: a `.set()` inside
# it is invisible to the caller that has to persist the value. Every copy shares
# the same dict object, so mutating it is visible everywhere — which is exactly
# the "written deep in the call stack, read at the top" shape we need.
_answering: contextvars.ContextVar[dict | None] = contextvars.ContextVar(
    "llm_answering_provider", default=None,
)


def begin_turn() -> None:
    """
    Start attribution for one user turn. Call at the top of a request, in the
    request's own task, before any provider call.
    """
    _answering.set({})


def _note_answered(provider: str, model: str) -> None:
    holder = _answering.get()
    if holder is None:
        # No begin_turn() — best effort. Correct in the common case (same task),
        # and a stale read here only mislabels a log field, never a booking.
        _answering.set({"provider": provider, "model": model})
        return
    holder["provider"] = provider
    holder["model"] = model


def answering_provider() -> str | None:
    """Provider name that served the last call in this turn, or None."""
    return (_answering.get() or {}).get("provider")


def answering_model(default: str | None = None) -> str:
    """
    Model id that served the last call in this turn.

    Falls back to the configured Groq model so callers that persist it always
    have something to write — but that fallback now only applies when no call
    was made at all (a deterministic reply, a guard that short-circuited).
    """
    return (_answering.get() or {}).get("model") or default or settings.GROQ_MODEL


# ── Typed provider failures ───────────────────────────────────────────────────
#
# "429" is four different problems wearing the same hat, and treating them alike
# is what made the agent unusable: a DAILY token budget that is spent for the
# next several hours was retried every turn as though it were a per-minute blip,
# while a payload the model can never accept (413) was retried too. The caller
# needs to know WHICH so it can pick a cooldown, a fallback, and an honest
# user-facing message. `kind` is that discriminator.

QUOTA_MINUTE = "quota_minute"                # per-minute TPM/RPM wall — clears in seconds
QUOTA_DAILY = "quota_daily"                  # per-day TPD/RPD budget — gone for hours
REQUEST_TOO_LARGE = "request_too_large"      # payload exceeds the model's window/TPM
INVALID_KEY = "invalid_key"                  # 401/403 — a different model won't help
PROVIDER_UNAVAILABLE = "provider_unavailable"  # transport/5xx/misconfiguration
TOOL_CALL_FAILURE = "tool_call_failure"      # model emitted an unusable tool call

# Kinds that mean "this provider cannot serve ANY request right now", as opposed
# to "this particular request was wrong".
_BLOCKING_KINDS = (QUOTA_MINUTE, QUOTA_DAILY, INVALID_KEY)


class LLMError(RuntimeError):
    """
    An LLM call failure with a machine-readable cause.

    `kind` is one of the constants above. `retry_after` is seconds, parsed from
    the provider's own headers or error body when it told us — never guessed.
    The message is for LOGS ONLY; callers render user-facing text from `kind`.
    """

    def __init__(
        self,
        message: str = "",
        *,
        kind: str = PROVIDER_UNAVAILABLE,
        provider: str | None = None,
        model: str | None = None,
        retry_after: float | None = None,
    ):
        super().__init__(message or kind)
        self.kind = kind
        self.provider = provider
        self.model = model
        self.retry_after = retry_after


# Keep GeminiError as an alias so old imports don't break during transition
GeminiError = LLMError


def error_kind(exc: Exception) -> str:
    """The typed cause of `exc`, for callers that catch a bare Exception."""
    return getattr(exc, "kind", PROVIDER_UNAVAILABLE)


def is_quota_error(exc: Exception) -> bool:
    """True for either flavour of quota wall (per-minute or per-day)."""
    return error_kind(exc) in (QUOTA_MINUTE, QUOTA_DAILY)


# ── Token estimation ──────────────────────────────────────────────────────────
#
# Groq bills and rejects on tokens, but only tells us the count AFTER the call —
# by which time a too-large request has already spent a retry and, on a TPD wall,
# nothing at all. A cheap local estimate lets us log the size of every request we
# send and compare it against what the provider actually charged, so payload
# growth is visible in the logs instead of showing up as a mystery 429.
#
# 4 chars/token is the standard English heuristic and was calibrated against this
# app's own traffic: the 35,541-char fixed payload estimated 8,885 tokens and Groq
# reported "Requested 8635" for the same call — ~3% high, i.e. conservative.
_CHARS_PER_TOKEN = 4.0
# JSON is denser than prose: braces, quotes, commas and digit runs each cost a
# token, so a serialised tool result tokenises well below 4 chars/token. Measured
# against Groq's own counts on this app's traffic, prose came in ~2% high while a
# JSON-heavy booking payload was ~25% LOW at 4.0 — an underestimate is the
# dangerous direction, because it hides an approaching request-too-large wall.
_JSON_CHARS_PER_TOKEN = 3.2
# Each message carries role/delimiter overhead the char count doesn't see.
_TOKENS_PER_MESSAGE = 4


def estimate_tokens(text: str, *, json_like: bool = False) -> int:
    """Rough token count for a blob of text. Never raises."""
    divisor = _JSON_CHARS_PER_TOKEN if json_like else _CHARS_PER_TOKEN
    return int(len(text or "") / divisor) + 1


def estimate_request_tokens(messages: list[dict] | None, tools: list[dict] | None = None) -> int:
    """
    Estimated input size of a chat request, tool schemas included.

    Deliberately counts the JSON serialisation of tool calls and schemas, because
    that is what actually goes over the wire — a 7-tool schema block is ~1.9k
    tokens on its own and was invisible in every earlier size calculation.
    """
    total = 0
    for m in messages or []:
        total += _TOKENS_PER_MESSAGE
        content = m.get("content")
        # A 'tool' message is always a serialised result, never prose.
        as_json = (m.get("role") or "").lower() == "tool"
        if isinstance(content, str):
            total += estimate_tokens(content, json_like=as_json)
        elif content is not None:
            total += estimate_tokens(json.dumps(content), json_like=True)
        if m.get("tool_calls"):
            try:
                total += estimate_tokens(json.dumps(m["tool_calls"]), json_like=True)
            except (TypeError, ValueError):
                pass
    if tools:
        try:
            total += estimate_tokens(
                json.dumps(tools, separators=(",", ":")), json_like=True)
        except (TypeError, ValueError):
            pass
    return total


def _log_call(
    provider: str,
    model: str,
    *,
    est_in: int,
    status: str,
    actual_in: Any = None,
    actual_out: Any = None,
    retry_after: float | None = None,
    detail: str = "",
) -> None:
    """
    One structured line per provider call. This is the record that turns "the
    agent said quota exhausted" into a diagnosis — provider, model, error
    category, when it resets, and how big the request actually was.
    """
    parts = [
        f"llm_call provider={provider}",
        f"model={model}",
        f"est_in={est_in}",
        f"status={status}",
    ]
    if actual_in is not None:
        parts.append(f"in={actual_in}")
    if actual_out is not None:
        parts.append(f"out={actual_out}")
    if retry_after is not None:
        parts.append(f"retry_after={retry_after:.0f}s")
    if detail:
        parts.append(f"detail={detail[:160]!r}")
    line = " ".join(parts)
    if status.startswith("ok"):
        # Single choke point for attribution: every provider path logs its
        # success here, so recording it here cannot drift out of sync with the
        # provider chain the way a per-branch assignment would.
        _note_answered(provider, model)
    # "ok_salvaged" is a success we still want visible — a rising salvage rate
    # is how you find out the model is drifting before users do.
    if status == "ok":
        logger.info(line)
    else:
        logger.warning(line)


# ── Provider error classification ─────────────────────────────────────────────

# The three providers spell the same window three different ways, so the
# separator is optional and the match is case-insensitive:
#   Groq        "on tokens per day (TPD)"          -> "per day"
#   OpenRouter  "Rate limit exceeded: free-models-per-day"  -> "per-day"
#   Gemini      "GenerateRequestsPerDayPerProjectPerModel"  -> "PerDay"
_DAILY_RE = re.compile(r"per[\s_-]*day|\bTPD\b|\bRPD\b", re.IGNORECASE)
_MINUTE_RE = re.compile(r"per[\s_-]*minute|\bTPM\b|\bRPM\b", re.IGNORECASE)

# A 429 whose reset is further out than this is a budget window, not a per-minute
# bucket — no per-minute wall ever asks you to wait five minutes.
_UNLABELLED_DAILY_THRESHOLD = 180.0
_TOO_LARGE_RE = re.compile(
    r"request_too_large|request too large|too large for|context length|"
    r"maximum context|input is too long|prompt is too long|reduce the length",
    re.IGNORECASE,
)
_RATE_LIMIT_RE = re.compile(r"rate[_ ]?limit|429|resource_exhausted|quota", re.IGNORECASE)
_INVALID_KEY_RE = re.compile(r"\b401\b|\b403\b|invalid_api_key|permission_denied|unauthorized",
                             re.IGNORECASE)

# "Please try again in 5m39.6s" / "in 1h2m3s" / "in 12.5s" — Groq puts the real
# reset here, and on a DAILY wall it is the only place it appears (the response
# headers describe the per-minute bucket, which reads full).
_DURATION_RE = re.compile(
    r"try again in\s*(?:(\d+)h)?\s*(?:(\d+)m(?!s))?\s*(?:([\d.]+)s)?", re.IGNORECASE
)


def _parse_retry_seconds(text: str) -> float | None:
    """Seconds from a 'try again in 1h2m3.5s' phrase, or None."""
    m = _DURATION_RE.search(text or "")
    if not m or not any(m.groups()):
        return None
    hours, minutes, seconds = m.groups()
    try:
        total = (int(hours or 0) * 3600) + (int(minutes or 0) * 60) + float(seconds or 0)
    except (TypeError, ValueError):
        return None
    return total or None


def _header_retry_seconds(headers: Any) -> float | None:
    """Seconds from a Retry-After / X-RateLimit-Reset header, or None."""
    if not headers:
        return None

    def _get(name: str):
        try:
            return headers.get(name)
        except Exception:
            return None

    raw = _get("retry-after") or _get("Retry-After")
    if raw:
        try:
            return float(raw)
        except (TypeError, ValueError):
            parsed = _parse_retry_seconds(str(raw))
            if parsed:
                return parsed
    # OpenRouter reports an absolute epoch-milliseconds reset instead.
    reset = _get("X-RateLimit-Reset") or _get("x-ratelimit-reset")
    if reset:
        try:
            secs = float(reset) / 1000.0 - time.time()
            if secs > 0:
                return secs
        except (TypeError, ValueError):
            pass
    # Groq's per-minute token bucket reset, e.g. "7.66s".
    tok_reset = _get("x-ratelimit-reset-tokens") or _get("X-RateLimit-Reset-Tokens")
    if tok_reset:
        parsed = _parse_retry_seconds(f"try again in {tok_reset}")
        if parsed:
            return parsed
    return None


def classify_provider_error(
    text: str,
    *,
    status_code: int | None = None,
    headers: Any = None,
) -> tuple[str, float | None]:
    """
    Map a raw provider error (body text + status + headers) to (kind, retry_after).

    The ordering matters. A Groq daily-quota 429 and a per-minute 429 are the SAME
    status code with the SAME headers — only the body distinguishes them ("on
    tokens per day (TPD)" vs "per minute (TPM)") — so the body is read first and
    the status code is only a fallback. Getting this backwards is precisely what
    made the agent re-probe a provider whose budget was gone for the rest of the
    day, on every single turn.
    """
    text = text or ""
    retry = _parse_retry_seconds(text) or _header_retry_seconds(headers)

    # 413 / context-window errors are NOT rate limits: the same payload will fail
    # forever, so a cooldown is the wrong response — the payload must shrink.
    if status_code == 413 or _TOO_LARGE_RE.search(text):
        return REQUEST_TOO_LARGE, None

    if status_code in (401, 403) or _INVALID_KEY_RE.search(text):
        return INVALID_KEY, None

    if status_code == 429 or _RATE_LIMIT_RE.search(text):
        if _DAILY_RE.search(text):
            return QUOTA_DAILY, retry
        if _MINUTE_RE.search(text):
            return QUOTA_MINUTE, retry
        # Unlabelled 429. A long reset means a budget window, not a minute bucket.
        if retry and retry > _UNLABELLED_DAILY_THRESHOLD:
            return QUOTA_DAILY, retry
        return QUOTA_MINUTE, retry

    return PROVIDER_UNAVAILABLE, retry


def _strip_code_fences(raw: str) -> str:
    """
    Remove a leading ```json / ``` fence and trailing ``` from an LLM response.
    Uses exact prefix removal (NOT str.lstrip, which strips any chars in the set —
    e.g. lstrip("```json") would also eat a leading 'n' or 's' from real content).
    """
    s = raw.strip()
    if s.startswith("```"):
        s = s[3:]                       # drop the opening ```
        if s[:4].lower() == "json":     # drop an optional 'json' language tag
            s = s[4:]
        s = s.lstrip()                  # drop any whitespace/newline after the fence
    if s.endswith("```"):
        s = s[:-3]
    return s.strip()


# ── Message format helpers ────────────────────────────────────────────────────

def _extract_system(messages: list[dict]) -> tuple[str, list[dict]]:
    """Split system messages from user/assistant messages."""
    system_parts: list[str] = []
    rest: list[dict] = []
    for m in messages:
        role = (m.get("role") or "").lower().strip()
        text = m.get("content") or ""
        if not text:
            continue
        if role == "system":
            system_parts.append(text)
        else:
            rest.append({"role": role, "content": text})
    return "\n\n".join(system_parts), rest


# ── Groq provider ─────────────────────────────────────────────────────────────
#
# TWO keys, because the free-tier limit that actually ends a day is per-ACCOUNT
# (TPD), not per-minute. A second Groq account is a second daily budget, so a
# spent key 1 no longer drops the agent onto a weaker fallback for hours.
#
# Each key gets its OWN client and its OWN _ProviderState. Sharing state would
# defeat the point: key 1's daily wall would park key 2 as well.
#
# Slot 0 keeps the plain names (_get_groq_client, _groq_state, provider "groq")
# so every existing call site, log line and test stub reads the same as before.

_GROQ_SLOT_NAMES = ("groq", "groq2")

_groq_client = None      # key 1
_groq_client_2 = None    # key 2 (optional)


def _build_groq_client(api_key: str, label: str):
    """
    Construct one Groq client. `label` is "key 1"/"key 2" — a POSITION, never
    the key itself; nothing in this module may put a key value in a log line.
    """
    try:
        from groq import AsyncGroq
        # max_retries=0: on a free-tier TPM 429, Groq returns a large `retry-after`
        # (~55s) and the SDK would otherwise sleep+retry internally, blowing past the
        # 60s request cap and hanging the chat UI. Fail fast instead and let the
        # orchestrator degrade gracefully on a typed QUOTA_MINUTE error.
        client = AsyncGroq(api_key=api_key, max_retries=0)
        logger.info("Groq client ready — %s, model=%s", label, settings.GROQ_MODEL)
        return client
    except Exception as exc:
        logger.warning("Groq client init failed (%s): %s", label, exc)
        return None


def _get_groq_client():
    """Client for Groq key 1. Deliberately zero-arg — the long-standing accessor."""
    global _groq_client
    if _groq_client is not None:
        return _groq_client
    keys = settings.groq_api_keys
    if not keys:
        return None
    _groq_client = _build_groq_client(keys[0], "key 1")
    return _groq_client


def _get_groq_client_2():
    """Client for the optional Groq key 2. None when only one key is configured."""
    global _groq_client_2
    if _groq_client_2 is not None:
        return _groq_client_2
    keys = settings.groq_api_keys
    if len(keys) < 2:
        return None
    _groq_client_2 = _build_groq_client(keys[1], "key 2")
    return _groq_client_2


def _groq_client_for(index: int):
    return _get_groq_client() if index == 0 else _get_groq_client_2()


# ── Provider availability windows ─────────────────────────────────────────────
#
# A 429 is NOT always the per-minute wall. When Groq's DAILY token budget is spent
# the 429 comes back with the minute-window counters still completely full
# (x-ratelimit-remaining-tokens: 12000) and a reset measured in MINUTES TO HOURS.
# OpenRouter's free tier likewise has a per-ACCOUNT daily request cap that every
# model shares. Re-probing either at the top of every agentic step then buys
# nothing and costs a round trip each time — three per turn, against a 60s
# interactive budget a turn has already been observed to blow.
#
# So each provider carries a state: when it is blocked until, WHY, and which of
# its models have refused our payload as too large. The cooldown is driven by the
# reset the provider itself reported — a daily wall is honoured in full (capped
# only at 24h so a corrupt header can't park a provider forever), while a minute
# wall keeps the old fast-recovery behaviour.

_MINUTE_MIN_COOLDOWN = 15.0      # floor for a per-minute 429 with no usable reset
_MINUTE_MAX_COOLDOWN = 300.0     # ceiling — a minute bucket never needs longer
_DAILY_DEFAULT_COOLDOWN = 1800.0  # a daily wall that didn't say when it resets
_DAILY_MAX_COOLDOWN = 24 * 3600.0
_INVALID_KEY_COOLDOWN = 600.0    # a bad key won't fix itself; stop hammering it


class _ProviderState:
    """Live health of one provider — see the module comment above."""

    def __init__(self, name: str):
        self.name = name
        self.blocked_until: float = 0.0
        self.block_kind: str = ""
        self.block_reason: str = ""
        # Models that returned 413 for a payload this size. Cleared whenever a
        # call to that model succeeds, so a shrunken payload re-enables it.
        self.oversized_models: set[str] = set()

    def available(self) -> bool:
        return time.monotonic() >= self.blocked_until

    def seconds_left(self) -> float:
        return max(self.blocked_until - time.monotonic(), 0.0)

    def daily_exhausted(self) -> bool:
        return self.block_kind == QUOTA_DAILY and not self.available()

    def note_failure(self, kind: str, retry_after: float | None, detail: str = "") -> None:
        if kind == QUOTA_DAILY:
            delay = min(retry_after or _DAILY_DEFAULT_COOLDOWN, _DAILY_MAX_COOLDOWN)
        elif kind == QUOTA_MINUTE:
            delay = min(
                max(retry_after or _MINUTE_MIN_COOLDOWN, _MINUTE_MIN_COOLDOWN),
                _MINUTE_MAX_COOLDOWN,
            )
        elif kind == INVALID_KEY:
            delay = _INVALID_KEY_COOLDOWN
        else:
            return  # transport blips and 413s are per-request, not per-provider
        self.blocked_until = time.monotonic() + delay
        self.block_kind = kind
        self.block_reason = detail[:200]
        logger.warning(
            "provider %s blocked kind=%s for %.0fs (%s)",
            self.name, kind, delay, detail[:120] or "no detail",
        )

    def note_success(self, model: str | None = None) -> None:
        self.blocked_until = 0.0
        self.block_kind = ""
        self.block_reason = ""
        if model:
            self.oversized_models.discard(model)

    def note_oversized(self, model: str) -> None:
        self.oversized_models.add(model)


_groq_state = _ProviderState("groq")      # key 1
_groq2_state = _ProviderState("groq2")    # key 2 (optional)
_openrouter_state = _ProviderState("openrouter")
_gemini_state = _ProviderState("gemini")


def _groq_state_for(index: int) -> _ProviderState:
    return _groq_state if index == 0 else _groq2_state


def _provider_states() -> dict[str, _ProviderState]:
    return {
        "groq": _groq_state,
        "groq2": _groq2_state,
        "openrouter": _openrouter_state,
        "gemini": _gemini_state,
    }


def _configured(name: str) -> bool:
    """
    Is this budget usable at all?

    The two Groq slots are POSITIONS in settings.groq_api_keys, not variable
    names — one key configured means slot 0 only, whichever variable supplied
    it. Everything that reasons about exhaustion (all_providers_exhausted,
    _no_provider_error, provider_health) reads this, so an absent key 2 simply
    never counts.
    """
    if name == "groq":
        return len(settings.groq_api_keys) >= 1
    if name == "groq2":
        return len(settings.groq_api_keys) >= 2
    return bool({
        "openrouter": settings.OPENROUTER_API_KEY,
        "gemini": settings.GEMINI_API_KEY,
    }.get(name))


def provider_health() -> dict[str, dict]:
    """Snapshot of every provider's state — for logging and the /chat guard."""
    return {
        name: {
            "configured": _configured(name),
            "available": state.available(),
            "block_kind": state.block_kind if not state.available() else "",
            "seconds_left": round(state.seconds_left()),
        }
        for name, state in _provider_states().items()
    }


def all_providers_exhausted() -> bool:
    """
    True when EVERY configured provider is sitting on a known DAILY quota wall.

    This is the one condition where sending another request is pure waste: the
    caller can answer honestly and instantly instead of spending a turn's budget
    discovering the same thing three times over. A per-minute wall deliberately
    does NOT count — those clear in seconds and are worth retrying.
    """
    states = [s for name, s in _provider_states().items() if _configured(name)]
    if not states:
        return False
    return all(s.daily_exhausted() for s in states)


def _reset_provider_state_for_tests() -> None:
    """Clear all provider cooldowns and cached clients. Test-only helper."""
    global _groq_client, _groq_client_2
    for state in _provider_states().values():
        state.blocked_until = 0.0
        state.block_kind = ""
        state.block_reason = ""
        state.oversized_models.clear()
    # Clients are cached per key; a test that changes the configured keys must
    # not keep talking to the previous test's client.
    _groq_client = None
    _groq_client_2 = None


def _note_provider_error(
    state: _ProviderState,
    text: str,
    *,
    status_code: int | None = None,
    headers: Any = None,
    model: str | None = None,
) -> LLMError:
    """Classify a raw provider failure, record it against the provider, return it typed."""
    kind, retry = classify_provider_error(text, status_code=status_code, headers=headers)
    if kind == REQUEST_TOO_LARGE and model:
        state.note_oversized(model)
    else:
        state.note_failure(kind, retry, text)
    return LLMError(
        f"{state.name}: {text[:200]}",
        kind=kind, provider=state.name, model=model, retry_after=retry,
    )


def _fallback_ready(include_gemini: bool = True) -> bool:
    """
    Is there a provider OTHER than Groq that could actually serve a request right
    now? A configured key is not enough — an OpenRouter key whose daily free quota
    is spent answers nothing, and treating it as a live fallback is what made the
    agent skip a perfectly healthy Groq and report "quota exhausted" instead.
    """
    if settings.OPENROUTER_API_KEY and _openrouter_state.available():
        return True
    return bool(
        include_gemini and settings.GEMINI_API_KEY and _gemini_state.available()
    )


def _use_groq(has_fallback: bool, index: int = 0) -> bool:
    """
    Whether to try this Groq key at all. A known cooldown is only worth
    honouring when something else can serve the request — with no usable
    fallback, a doomed attempt still beats no attempt (and Groq's per-minute
    window often reset seconds after the 429 that parked it).

    The one exception is a DAILY wall: that budget is measurably gone for the
    reset window the provider itself quoted, so retrying it cannot succeed and
    only burns the interactive turn budget the user is waiting on.
    """
    if _groq_client_for(index) is None:
        return False
    state = _groq_state_for(index)
    if state.daily_exhausted():
        return False
    return state.available() or not has_fallback


def _groq_slots_to_try(has_fallback: bool) -> list[int]:
    """
    Which Groq keys are worth attempting for THIS call, in order.

    A slot is dropped when it has no client, when its own state says it cannot
    serve, or when the model already refused a payload this size.

    That last check reads EVERY slot's oversized set, not just this one's,
    because a 413 is a property of the payload and the model — and both keys run
    settings.GROQ_MODEL. Rotating the key after a 413 would resend the identical
    request to the identical model and fail identically, having spent another
    slice of the turn the user is waiting on.

    A sibling key that is ready counts as a fallback for this one, so a key
    parked on a per-minute wall is skipped in favour of the other key rather
    than being attempted anyway. That is not rotation on a minute error — it is
    the existing "don't poke a provider we know is parked" rule, now with one
    more provider to choose from.
    """
    live = [i for i in range(len(settings.groq_api_keys)) if _groq_client_for(i) is not None]
    oversized = any(
        settings.GROQ_MODEL in _groq_state_for(i).oversized_models for i in live
    )
    if oversized:
        logger.warning(
            "skipping Groq — %s already refused a payload this size (413)",
            settings.GROQ_MODEL,
        )
        return []
    out: list[int] = []
    for i in live:
        sibling_ready = any(j != i and _groq_state_for(j).available() for j in live)
        if _use_groq(has_fallback or sibling_ready, i):
            out.append(i)
    return out


async def _call_groq(
    messages: list[dict],
    *,
    temperature: float,
    max_output_tokens: int,
    json_mode: bool = False,
    key_index: int = 0,
) -> str:
    client = _groq_client_for(key_index)
    slot = _GROQ_SLOT_NAMES[key_index]
    state = _groq_state_for(key_index)
    if client is None:
        raise LLMError("groq client unavailable", kind=PROVIDER_UNAVAILABLE, provider=slot)

    system_text, rest = _extract_system(messages)

    groq_messages = []
    if system_text:
        groq_messages.append({"role": "system", "content": system_text})
    groq_messages.extend(rest)

    kwargs: dict = {
        "model": settings.GROQ_MODEL,
        "messages": groq_messages,
        "temperature": temperature,
        "max_tokens": max_output_tokens,
    }
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    est_in = estimate_request_tokens(groq_messages)
    try:
        response = await client.chat.completions.create(**kwargs)
        text = (response.choices[0].message.content or "").strip()
        if not text:
            _log_call(slot, settings.GROQ_MODEL, est_in=est_in, status="empty_response")
            raise LLMError("groq returned empty response", kind=PROVIDER_UNAVAILABLE,
                           provider=slot, model=settings.GROQ_MODEL)
        state.note_success(settings.GROQ_MODEL)
        _log_call(slot, settings.GROQ_MODEL, est_in=est_in, status="ok",
                  actual_in=response.usage.prompt_tokens,
                  actual_out=response.usage.completion_tokens)
        return text
    except LLMError:
        raise
    except Exception as exc:
        raise _groq_exception_error(exc, est_in, key_index=key_index) from exc


def _groq_exception_error(exc: Exception, est_in: int, key_index: int = 0) -> LLMError:
    """Turn a raw Groq SDK exception into a typed, recorded LLMError."""
    body = getattr(exc, "body", None)
    body_text = ""
    if isinstance(body, dict):
        err = body.get("error")
        if isinstance(err, dict):
            body_text = str(err.get("message") or "")
    text = body_text or str(exc)
    resp = getattr(exc, "response", None)
    headers = getattr(resp, "headers", None)
    status = getattr(exc, "status_code", None) or getattr(resp, "status_code", None)
    slot = _GROQ_SLOT_NAMES[key_index]
    llm_error = _note_provider_error(
        _groq_state_for(key_index), text, status_code=status, headers=headers,
        model=settings.GROQ_MODEL,
    )
    if llm_error.kind == REQUEST_TOO_LARGE:
        # The payload is too big for this MODEL, and both keys run the same one.
        # Marking every slot is what stops the next step rotating the key for a
        # request that is guaranteed to be refused again.
        for i in range(len(_GROQ_SLOT_NAMES)):
            _groq_state_for(i).note_oversized(settings.GROQ_MODEL)
    _log_call(slot, settings.GROQ_MODEL, est_in=est_in, status=llm_error.kind,
              retry_after=llm_error.retry_after, detail=text)
    return llm_error


# ── Gemini provider ───────────────────────────────────────────────────────────

_gemini_client = None


def _get_gemini_client():
    global _gemini_client
    if _gemini_client is not None:
        return _gemini_client
    if not settings.GEMINI_API_KEY:
        return None
    try:
        from google import genai
        _gemini_client = genai.Client(api_key=settings.GEMINI_API_KEY)
        logger.info("Gemini client ready — model=%s", settings.GEMINI_MODEL)
        return _gemini_client
    except Exception as exc:
        logger.warning("Gemini client init failed: %s", exc)
        return None


# Google retires Gemini model ids and then serves them ONLY to accounts that were
# already using them: a newer key gets HTTP 404 "no longer available to new users"
# for an id that still appears in models.list(). That is exactly what silently
# disabled this project's Gemini fallback — the configured gemini-2.5-flash 404s
# for this key. A pinned id in .env also overrides the code default, so the
# recovery has to live here rather than in config.
#
# "gemini-flash-latest" is an alias that always resolves to the current Flash
# model. On a retirement error we switch to it once, for the life of the process,
# and log loudly so the pinned value gets fixed properly.
_GEMINI_MODEL_ALIAS = "gemini-flash-latest"
_MODEL_RETIRED_RE = re.compile(
    r"no longer available|is not found for API version|NOT_FOUND", re.IGNORECASE
)
_gemini_active_model: str | None = None


def _gemini_model() -> str:
    return _gemini_active_model or settings.GEMINI_MODEL


def _switch_gemini_model_if_retired(text: str) -> bool:
    """True if we just moved off a retired model id and the call is worth retrying."""
    global _gemini_active_model
    if not _MODEL_RETIRED_RE.search(text or ""):
        return False
    if _gemini_model() == _GEMINI_MODEL_ALIAS:
        return False
    logger.error(
        "Gemini model %r is retired for this API key — falling back to %r for this "
        "process. Update GEMINI_MODEL in .env to stop paying for this round trip.",
        _gemini_model(), _GEMINI_MODEL_ALIAS,
    )
    _gemini_active_model = _GEMINI_MODEL_ALIAS
    return True


def _gemini_error(exc: Exception, est_in: int) -> LLMError:
    """Turn a raw google-genai exception into a typed, recorded LLMError."""
    text = str(exc)
    status = getattr(exc, "code", None) or getattr(exc, "status_code", None)
    llm_error = _note_provider_error(
        _gemini_state, text, status_code=status, model=_gemini_model(),
    )
    _log_call("gemini", _gemini_model(), est_in=est_in, status=llm_error.kind,
              retry_after=llm_error.retry_after, detail=text)
    return llm_error


async def _gemini_call(contents, config, est_in: int):
    """One generate_content call, retried once if the model id turns out retired."""
    client = _get_gemini_client()
    if client is None:
        raise LLMError("gemini client unavailable", kind=PROVIDER_UNAVAILABLE,
                       provider="gemini")
    try:
        return await client.aio.models.generate_content(
            model=_gemini_model(), contents=contents, config=config)
    except Exception as exc:
        if not _switch_gemini_model_if_retired(str(exc)):
            raise _gemini_error(exc, est_in) from exc
    try:
        return await client.aio.models.generate_content(
            model=_gemini_model(), contents=contents, config=config)
    except Exception as exc:
        raise _gemini_error(exc, est_in) from exc


async def _call_gemini(
    messages: list[dict],
    *,
    temperature: float,
    max_output_tokens: int,
    response_mime_type: str | None = None,
) -> str:
    client = _get_gemini_client()
    if client is None:
        raise LLMError("gemini client unavailable", kind=PROVIDER_UNAVAILABLE, provider="gemini")

    from google.genai import types

    system_text, rest = _extract_system(messages)

    contents = []
    for m in rest:
        role = "model" if m["role"] == "assistant" else "user"
        contents.append(types.Content(role=role, parts=[types.Part(text=m["content"])]))

    if not contents:
        raise LLMError("no messages to send", kind=PROVIDER_UNAVAILABLE, provider="gemini")

    config = types.GenerateContentConfig(
        temperature=temperature,
        max_output_tokens=max_output_tokens,
        system_instruction=system_text or None,
        response_mime_type=response_mime_type,
    )

    est_in = estimate_request_tokens(messages)
    response = await _gemini_call(contents, config, est_in)
    text = (response.text or "").strip()
    if not text:
        _log_call("gemini", _gemini_model(), est_in=est_in, status="empty_response")
        raise LLMError("gemini returned empty response", kind=PROVIDER_UNAVAILABLE,
                       provider="gemini", model=_gemini_model())
    usage = getattr(response, "usage_metadata", None)
    _gemini_state.note_success(_gemini_model())
    _log_call("gemini", _gemini_model(), est_in=est_in, status="ok",
              actual_in=getattr(usage, "prompt_token_count", None),
              actual_out=getattr(usage, "candidates_token_count", None))
    return text


# ── Gemini native function calling ────────────────────────────────────────────
#
# Gemini is the THIRD independent token budget, and until now it was text-only —
# so a tool-using turn had exactly two providers, and when both hit their daily
# wall the agent had nothing left to try. Gemini speaks tool calling natively
# (function declarations in, function_call parts out), just not in the OpenAI
# shape, so the whole job here is translation:
#
#   OpenAI                                Gemini
#   ----------------------------------    ----------------------------------
#   tools[].function{name,desc,params}    Tool(function_declarations=[...])
#   assistant{tool_calls:[{fn,args}]}     Content(role="model",
#                                                 parts=[Part(function_call=...)])
#   {role:"tool", tool_call_id, content}  Content(role="user",
#                                                 parts=[Part(function_response=...)])
#
# Gemini has no tool_call_id, so ids are re-minted on the way out and matched back
# by ORDER on the way in — the orchestrator only ever replies to the calls from
# the immediately preceding turn, so order is sufficient and stable.


def _gemini_tool_declarations(tools: list[dict] | None):
    """Our OpenAI tool schemas as Gemini FunctionDeclarations."""
    from google.genai import types

    decls = []
    for t in tools or []:
        fn = (t.get("function") or {}) if isinstance(t, dict) else {}
        name = fn.get("name")
        if not name:
            continue
        # model_validate (not the kwargs constructor) so the plain JSON-Schema dict
        # is coerced into a genai Schema by pydantic — the constructor is typed to
        # accept only an already-built Schema.
        decls.append(types.FunctionDeclaration.model_validate({
            "name": name,
            "description": fn.get("description") or "",
            "parameters": fn.get("parameters") or {"type": "object", "properties": {}},
        }))
    return decls


# Gemini 3 requires that a function_call handed BACK to the model still carries
# the opaque `thought_signature` it was issued with — without it the next call is
# rejected outright ("Function call is missing a thought_signature in functionCall
# parts"), which kills the second round of every tool loop.
#
# The orchestrator serialises tool calls into the provider-neutral OpenAI shape
# (id / name / arguments), and there is nowhere in that shape to put an opaque
# provider blob. So the signature is held here, keyed by the call id we mint, and
# re-attached during translation. Bounded, because ids are per-request and never
# reused; entries are only ever read on the immediately following call.
_GEMINI_SIGNATURE_CACHE_MAX = 256
_gemini_signatures: dict[str, bytes] = {}


def _remember_signature(call_id: str, signature) -> None:
    if not signature:
        return
    if len(_gemini_signatures) >= _GEMINI_SIGNATURE_CACHE_MAX:
        # Plain FIFO eviction — good enough for a cache that is read once.
        for key in list(_gemini_signatures)[: _GEMINI_SIGNATURE_CACHE_MAX // 2]:
            _gemini_signatures.pop(key, None)
    _gemini_signatures[call_id] = signature


def _gemini_contents_from_openai(messages: list[dict]):
    """
    Translate an OpenAI-format message list (including tool_calls and tool
    results) into Gemini Contents.

    Tool results are matched to their function NAME via the assistant turn that
    requested them, because Gemini's FunctionResponse is keyed by name, not id.

    HANDOVER CASE (why this is not a straight one-to-one translation):
    Gemini rejects — HTTP 400, "Function call is missing a thought_signature in
    functionCall parts" — any functionCall part it did not itself produce. That
    is precisely what a mid-turn failover hands it: Groq or OpenRouter makes the
    tool call, then dies on the synthesis step, and Gemini inherits a history
    full of another model's calls. Observed live: the turn ended in the generic
    fallback message even though the data had already been fetched successfully.

    So a call we have no signature for is NOT sent as a functionCall. It is
    replayed as text — "called search_flights(...)" plus its result — which
    carries exactly the same information, is what the synthesis step needs
    anyway (write prose from data already gathered), and costs one extra
    sentence of tokens. Calls Gemini did make keep their signature and stay
    structured, so a Gemini-only turn is unchanged.
    """
    from google.genai import types

    # tool_call_id -> function name, harvested from assistant turns as we go.
    call_names: dict[str, str] = {}
    # tool_call_ids replayed as text — their results must be replayed as text too,
    # or Gemini gets an answer to a question it was never shown.
    text_only_calls: set[str] = set()
    contents = []
    for m in messages:
        role = (m.get("role") or "").lower()
        if role == "system":
            continue  # hoisted into system_instruction by the caller
        if role == "assistant":
            parts = []
            content = m.get("content")
            if isinstance(content, str) and content.strip():
                parts.append(types.Part(text=content))
            for call in m.get("tool_calls") or []:
                fn = (call or {}).get("function") or {}
                name = fn.get("name")
                if not name:
                    continue
                call_id = str(call.get("id"))
                call_names[call_id] = name
                try:
                    args = json.loads(fn.get("arguments") or "{}")
                except (json.JSONDecodeError, TypeError):
                    args = {}
                signature = _gemini_signatures.get(call_id)
                if not signature:
                    text_only_calls.add(call_id)
                    parts.append(types.Part(
                        text=f"I called {name} with {json.dumps(args, default=str)}."
                    ))
                    continue
                parts.append(types.Part(
                    function_call=types.FunctionCall(
                        name=name, args=args if isinstance(args, dict) else {},
                    ),
                    thought_signature=signature,
                ))
            if parts:
                contents.append(types.Content(role="model", parts=parts))
            continue
        if role == "tool":
            call_id = str(m.get("tool_call_id"))
            name = call_names.get(call_id) or m.get("name") or "tool"
            if call_id in text_only_calls:
                contents.append(types.Content(role="user", parts=[types.Part(
                    text=f"Result from {name}: {_as_str(m.get('content'))}"
                )]))
                continue
            # The result is already a JSON string the model reads directly; wrap it
            # rather than re-parsing, so a non-JSON error string still gets through.
            contents.append(types.Content(role="user", parts=[types.Part(
                function_response=types.FunctionResponse(
                    name=name, response={"result": _as_str(m.get("content"))},
                )
            )]))
            continue
        text = _as_str(m.get("content"))
        if text.strip():
            contents.append(types.Content(role="user", parts=[types.Part(text=text)]))
    return contents


def _as_str(value: Any) -> str:
    if isinstance(value, str):
        return value
    if value is None:
        return ""
    try:
        return json.dumps(value)
    except (TypeError, ValueError):
        return str(value)


async def _gemini_generate_with_tools(
    messages: list[dict],
    tools: list[dict] | None,
    *,
    temperature: float,
    max_output_tokens: int,
):
    """
    Tool-calling via Gemini's native function-calling API.

    Returns the same duck-typed message object the Groq/OpenRouter paths return
    (`.content` / `.tool_calls`), so the orchestrator needs no provider knowledge.
    """
    client = _get_gemini_client()
    if client is None:
        raise LLMError("gemini client unavailable", kind=PROVIDER_UNAVAILABLE, provider="gemini")

    from google.genai import types

    system_text, _ = _extract_system(messages)
    contents = _gemini_contents_from_openai(messages)
    if not contents:
        raise LLMError("no messages to send", kind=PROVIDER_UNAVAILABLE, provider="gemini")

    config_kwargs: dict = {
        "temperature": temperature,
        "max_output_tokens": max_output_tokens,
        "system_instruction": system_text or None,
    }
    decls = _gemini_tool_declarations(tools)
    if decls:
        config_kwargs["tools"] = [types.Tool(function_declarations=decls)]
        # We dispatch tools ourselves through the deterministic gates — letting the
        # SDK auto-execute would bypass every one of them.
        config_kwargs["automatic_function_calling"] = types.AutomaticFunctionCallingConfig(
            disable=True
        )

    est_in = estimate_request_tokens(messages, tools)
    response = await _gemini_call(
        contents, types.GenerateContentConfig(**config_kwargs), est_in)

    candidates = getattr(response, "candidates", None) or []
    parts = []
    if candidates:
        content = getattr(candidates[0], "content", None)
        parts = getattr(content, "parts", None) or []

    text_chunks: list[str] = []
    calls: list = []
    # Ids must be unique across the whole conversation, not just this response —
    # they key the thought-signature cache, and a repeated "gemini_call_0" would
    # hand turn 3 the signature issued on turn 1.
    call_prefix = f"gemini_{uuid.uuid4().hex[:8]}"
    for i, part in enumerate(parts):
        fc = getattr(part, "function_call", None)
        if fc is not None and getattr(fc, "name", None):
            try:
                args = json.dumps(dict(fc.args or {}))
            except (TypeError, ValueError):
                args = "{}"
            call_id = f"{call_prefix}_{i}"
            _remember_signature(call_id, getattr(part, "thought_signature", None))
            calls.append(_SalvagedToolCall(call_id, fc.name, args))
            continue
        chunk = getattr(part, "text", None)
        if chunk:
            text_chunks.append(chunk)

    usage = getattr(response, "usage_metadata", None)
    _gemini_state.note_success(_gemini_model())
    _log_call("gemini", _gemini_model(), est_in=est_in, status="ok",
              actual_in=getattr(usage, "prompt_token_count", None),
              actual_out=getattr(usage, "candidates_token_count", None))

    content_text = "".join(text_chunks).strip() or None
    if calls:
        return _SalvagedMessage(content_text, calls)
    # No structured call — the free-tier salvage path also applies here, since a
    # model that emits "<function=...>" as text does it on any provider.
    if content_text:
        salvaged = _salvage_tool_calls(content_text, _tool_names_from_schemas(tools))
        if salvaged:
            logger.info("Recovered %d malformed tool call(s) from Gemini content", len(salvaged))
            return _SalvagedMessage(None, salvaged)
    return _SalvagedMessage(content_text, [])


# ── OpenRouter provider (OpenAI-compatible fallback) ──────────────────────────
#
# Used ONLY when Groq is rate-limited or otherwise fails. OpenRouter speaks the
# OpenAI chat-completions schema, so the SAME messages + tool schemas we send Groq
# work unchanged — we just POST them over httpx (no extra SDK). This gives the agent
# a second, independent token budget so a tool-using turn can still complete under
# Groq's free-tier 12k TPM wall. Disabled automatically if OPENROUTER_API_KEY is blank.

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# A chat turn is interactive and the Flutter client gives up at 60s. At the old
# 45s-per-request with no overall cap, two ':free' models that QUEUE rather than
# return 429 could burn ~90s here — so the client timed out before the graceful
# rate-limit message could ever be delivered, and the user got the raw error path
# instead. Bound both the single request and the total across the model list, so
# the whole turn still lands inside the client's window with room to spare.
#
# The total is sized against the TURN budget, not just the client's window. That
# distinction is what the 35s original missed: OpenRouter sits AHEAD of Gemini,
# so whatever it spends, Gemini does without. With both Groq keys on a daily
# wall and OpenRouter's free models queuing, 35s left Gemini ~15s of a 52s turn
# — less once a tool call had run — and "roundtrip available?", a question
# needing no tools at all, came back as "that's taking longer than it should".
# The fastest provider in the chain was starved by the slowest.
#
# At 20s a hung model costs one timeout and then OpenRouter yields, leaving
# Gemini ~30s. It must stay >= _OPENROUTER_REQUEST_TIMEOUT, or a healthy-but-
# slow request would be cut off by this deadline before its own timeout fired,
# which would make OpenRouter useless rather than bounded. The model list still
# works as intended: a model rate-limited upstream answers 429 in under a
# second, so the next one is still tried with its full timeout.
_OPENROUTER_REQUEST_TIMEOUT = 20.0
_OPENROUTER_TOTAL_BUDGET = 20.0


def _openrouter_models() -> list[str]:
    """OPENROUTER_MODEL may name several models (comma-separated). We try them in order
    and skip any that are rate-limited upstream, so one flapping free model can't sink
    the whole fallback. Always returns at least one id."""
    raw = settings.OPENROUTER_MODEL or ""
    models = [m.strip() for m in raw.split(",") if m.strip()]
    return models or ["openai/gpt-oss-20b:free"]


async def _openrouter_chat_raw(
    messages: list[dict],
    *,
    temperature: float,
    max_output_tokens: int,
    tools: list[dict] | None = None,
    json_mode: bool = False,
) -> dict:
    """POST an OpenAI-format request to OpenRouter and return the parsed JSON body.
    Tries each model in OPENROUTER_MODEL in order, skipping any that are rate-limited
    upstream (429). Raises a typed LLMError (see classify_provider_error) so callers
    treat it exactly like Groq."""
    if not settings.OPENROUTER_API_KEY:
        raise LLMError("openrouter not configured", kind=PROVIDER_UNAVAILABLE,
                       provider="openrouter")

    base_payload: dict = {
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_output_tokens,
    }
    if tools:
        base_payload["tools"] = tools
        base_payload["tool_choice"] = "auto"
    if json_mode:
        base_payload["response_format"] = {"type": "json_object"}

    headers = {
        "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "X-Title": "Travello AI",
    }

    est_in = estimate_request_tokens(messages, tools)
    last_exc: LLMError | None = None
    deadline = time.monotonic() + _OPENROUTER_TOTAL_BUDGET
    async with httpx.AsyncClient(timeout=_OPENROUTER_REQUEST_TIMEOUT) as client:
        for model in _openrouter_models():
            if time.monotonic() >= deadline:
                # Out of budget — trying another slow free model would only push
                # the turn past the client's timeout. Surface what we have.
                logger.warning("OpenRouter budget spent — skipping remaining models")
                break
            # A model that already refused a payload this size will refuse it
            # again; retrying it wastes the turn's clock for a guaranteed 413.
            if model in _openrouter_state.oversized_models:
                logger.info("OpenRouter model %s skipped — payload known too large", model)
                last_exc = LLMError(
                    f"openrouter: {model} rejected payload size",
                    kind=REQUEST_TOO_LARGE, provider="openrouter", model=model,
                )
                continue
            payload = {**base_payload, "model": model}
            try:
                resp = await client.post(_OPENROUTER_URL, headers=headers, json=payload)
            except Exception as exc:
                # Transport error is the same for every model — don't hammer the list.
                _log_call("openrouter", model, est_in=est_in,
                          status=PROVIDER_UNAVAILABLE, detail=str(exc))
                raise LLMError(f"openrouter request failed: {exc}",
                               kind=PROVIDER_UNAVAILABLE, provider="openrouter",
                               model=model) from exc

            if resp.status_code in (401, 403):
                # Key-level problem — a different model won't help.
                err = _note_provider_error(_openrouter_state, resp.text,
                                           status_code=resp.status_code,
                                           headers=resp.headers, model=model)
                _log_call("openrouter", model, est_in=est_in, status=err.kind,
                          retry_after=err.retry_after, detail=resp.text)
                raise err
            if resp.status_code >= 400:
                body_text = resp.text
                # The daily-cap 429 hides its reset inside the error body, not the
                # headers — pull it out so the cooldown matches the real window.
                if resp.status_code == 429:
                    try:
                        meta = ((resp.json().get("error") or {}).get("metadata") or {})
                        reset_ms = (meta.get("headers") or {}).get("X-RateLimit-Reset")
                        if reset_ms:
                            secs = float(reset_ms) / 1000.0 - time.time()
                            if secs > 0:
                                body_text = f"{body_text} try again in {secs:.0f}s"
                    except Exception:
                        pass
                last_exc = _note_provider_error(
                    _openrouter_state, body_text, status_code=resp.status_code,
                    headers=resp.headers, model=model,
                )
                _log_call("openrouter", model, est_in=est_in, status=last_exc.kind,
                          retry_after=last_exc.retry_after, detail=body_text)
                # A per-account quota (OpenRouter's free tier is keyed to the
                # ACCOUNT, not the model) means the next model fails identically.
                if last_exc.kind in (QUOTA_DAILY, QUOTA_MINUTE):
                    break
                continue

            try:
                data = resp.json()
            except Exception as exc:
                last_exc = LLMError(f"openrouter returned non-JSON: {exc}",
                                    kind=PROVIDER_UNAVAILABLE, provider="openrouter",
                                    model=model)
                logger.warning("OpenRouter model %s returned non-JSON — trying next", model)
                continue

            # OpenRouter sometimes surfaces upstream provider errors inside a 200 body.
            if isinstance(data, dict) and data.get("error"):
                err_body = data["error"]
                msg = err_body.get("message", "") if isinstance(err_body, dict) else str(err_body)
                code = err_body.get("code") if isinstance(err_body, dict) else None
                last_exc = _note_provider_error(
                    _openrouter_state, msg,
                    status_code=code if isinstance(code, int) else None,
                    headers=resp.headers, model=model,
                )
                _log_call("openrouter", model, est_in=est_in, status=last_exc.kind,
                          retry_after=last_exc.retry_after, detail=msg)
                if last_exc.kind in (QUOTA_DAILY, QUOTA_MINUTE):
                    break
                continue

            usage = data.get("usage") or {} if isinstance(data, dict) else {}
            _openrouter_state.note_success(model)
            _log_call("openrouter", model, est_in=est_in, status="ok",
                      actual_in=usage.get("prompt_tokens"),
                      actual_out=usage.get("completion_tokens"))
            return data

    # Every model failed — surface the last typed error so the caller can choose a
    # cooldown, a different provider, and the right message for the user.
    raise last_exc or LLMError("openrouter exhausted", kind=QUOTA_MINUTE,
                               provider="openrouter")


async def _call_openrouter(
    messages: list[dict],
    *,
    temperature: float,
    max_output_tokens: int,
    json_mode: bool = False,
) -> str:
    """Plain-text (or JSON string) completion via OpenRouter."""
    data = await _openrouter_chat_raw(
        messages, temperature=temperature,
        max_output_tokens=max_output_tokens, json_mode=json_mode,
    )
    try:
        text = (data["choices"][0]["message"]["content"] or "").strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMError(f"openrouter malformed response: {exc}",
                       kind=PROVIDER_UNAVAILABLE, provider="openrouter") from exc
    if not text:
        raise LLMError("openrouter returned empty response",
                       kind=PROVIDER_UNAVAILABLE, provider="openrouter")
    return text


# ── Public API ────────────────────────────────────────────────────────────────

async def generate_text(
    messages: list[dict],
    *,
    temperature: float = 0.7,
    max_output_tokens: int = 1024,
) -> str:
    """Send chat messages, return plain-text reply. Groq → OpenRouter → Gemini."""
    last: LLMError | None = None
    # Primary: Groq (free, fast) — its cooldown is skipped only when some other
    # provider is genuinely able to serve right now. Key 2 is tried only when
    # key 1 reports its DAILY budget spent; see _groq_slots_to_try.
    for key_index in _groq_slots_to_try(_fallback_ready()):
        try:
            return await _call_groq(messages, temperature=temperature,
                                    max_output_tokens=max_output_tokens,
                                    key_index=key_index)
        except LLMError as exc:
            last = exc
            if exc.kind != QUOTA_DAILY:
                logger.warning("Groq failed (%s), trying OpenRouter", exc.kind)
                break
            logger.warning("Groq key %d is out of daily quota — trying the next Groq key",
                           key_index + 1)

    # Fallback 1: OpenRouter (second independent budget)
    if settings.OPENROUTER_API_KEY and _openrouter_state.available():
        try:
            return await _call_openrouter(messages, temperature=temperature,
                                          max_output_tokens=max_output_tokens)
        except LLMError as exc:
            last = exc
            logger.warning("OpenRouter failed (%s), falling back to Gemini", exc.kind)

    # Fallback 2: Gemini
    if settings.GEMINI_API_KEY and _gemini_state.available():
        return await _call_gemini(messages, temperature=temperature,
                                  max_output_tokens=max_output_tokens)
    # Every provider is configured-but-blocked (or none is configured). Re-raise
    # the real cause so the caller can tell a daily wall from a minute one.
    raise last or _no_provider_error()


async def generate_json(
    messages: list[dict],
    *,
    temperature: float = 0.2,
    max_output_tokens: int = 2048,
) -> Any:
    """Force JSON output and parse it. Groq → OpenRouter → Gemini."""
    last: LLMError | None = None
    # Primary: Groq with json_mode — see generate_text on the cooldown condition
    for key_index in _groq_slots_to_try(_fallback_ready()):
        try:
            raw = await _call_groq(messages, temperature=temperature,
                                   max_output_tokens=max_output_tokens,
                                   json_mode=True, key_index=key_index)
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                # Groq json_mode occasionally wraps output in markdown fences — strip them
                return json.loads(_strip_code_fences(raw))
        except LLMError as exc:
            last = exc
            if exc.kind != QUOTA_DAILY:
                logger.warning("Groq JSON failed (%s), trying OpenRouter", exc.kind)
                break
            logger.warning("Groq key %d is out of daily quota — trying the next Groq key",
                           key_index + 1)

    # Fallback 1: OpenRouter with json_mode
    if settings.OPENROUTER_API_KEY and _openrouter_state.available():
        try:
            raw = await _call_openrouter(messages, temperature=temperature,
                                         max_output_tokens=max_output_tokens,
                                         json_mode=True)
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                return json.loads(_strip_code_fences(raw))
        except (LLMError, json.JSONDecodeError) as exc:
            if isinstance(exc, LLMError):
                last = exc
            logger.warning("OpenRouter JSON failed (%s), falling back to Gemini", exc)

    # Fallback 2: Gemini with native JSON mime type
    if not (settings.GEMINI_API_KEY and _gemini_state.available()):
        raise last or _no_provider_error()
    raw = await _call_gemini(messages, temperature=temperature,
                              max_output_tokens=max_output_tokens,
                              response_mime_type="application/json")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error("Gemini JSON parse failed. Raw=%r", raw[:500])
        raise LLMError(f"invalid JSON response: {exc}",
                       kind=PROVIDER_UNAVAILABLE, provider="gemini") from exc


# ── Tool-calling (agentic loop) — Groq only ───────────────────────────────────

# Llama-on-Groq occasionally emits a malformed tool call as TEXT instead of a
# structured call, e.g.  <function=search_flights{"city": "Lahore"}</function>
# or, with a closing '>' on the opening tag, <function=search_flights>{"city": "Lahore"}</function>
# Sometimes Groq rejects it with a 400 'tool_use_failed' (salvaged from the error
# payload); other times it comes straight back as the message CONTENT with no
# structured tool_calls at all — and then the raw "<function=...>" markup lands in
# the chat as a bubble the user sees (observed live). Both paths are salvaged.
#
# The name itself may arrive as natural language ("search for flights") or
# hyphenated, so the capture is permissive (spaces / '.' / '-') and the result is
# normalised to a real tool id by _normalize_tool_name below. The optional '>'
# must be matched — otherwise a refusal or answer the model already generated
# correctly, with only this trailing malformed call attached, is thrown away.
_MALFORMED_FUNC_RE = re.compile(
    r"<function=([a-zA-Z0-9_ .\-]+?)\s*>?\s*(\{.*?\})\s*</function>", re.DOTALL
)


def _tool_names_from_schemas(tools: list[dict] | None) -> set[str]:
    """The set of real tool ids from an OpenAI/Groq tools list — used to normalise
    a salvaged, possibly natural-language function name back to a dispatchable id."""
    names: set[str] = set()
    for t in tools or []:
        fn = (t.get("function") or {}) if isinstance(t, dict) else {}
        n = fn.get("name")
        if n:
            names.add(n)
    return names


# Filler the model sprinkles into a spelled-out function name ("search FOR
# flights", "find THE hotels") that isn't part of the real id.
_TOOLNAME_FILLER = {"for", "the", "a", "an", "me", "some", "of", "my", "to", "up"}

# Verb tokens of real tool ids — dropped in the verb-swap fallback so a tool is
# matched on its distinctive noun ("hotels", "car", "booking") when the model
# picks a different verb than the canonical one.
_TOOLNAME_VERBS = {"search", "find", "get", "book", "prepare", "look", "show", "fetch", "reserve"}


def _normalize_tool_name(raw: str, known: set[str]) -> str | None:
    """
    Map a possibly natural-language function name ('search for flights',
    'search-flights', 'Search Flights') to a real tool id. Returns None when it
    can't be resolved to a KNOWN tool, so a nonsense name is dropped rather than
    dispatched. With no known set (shouldn't happen on the tool paths) it falls
    back to the plain underscore form.
    """
    cand = re.sub(r"[\s.\-]+", "_", raw.strip().lower()).strip("_")
    if not known:
        return cand or None
    if cand in known:
        return cand
    tokens = {t for t in re.split(r"[\s_.\-]+", raw.strip().lower()) if t}
    tokens -= _TOOLNAME_FILLER
    best: str | None = None
    for name in known:
        name_tokens = set(name.split("_"))
        # Every significant token of the real tool id must be present in what the
        # model wrote — "search_flights" matches "search for flights", but
        # "search_hotels" does not.
        if name_tokens and name_tokens <= tokens:
            if best is None or len(name_tokens) > len(set(best.split("_"))):
                best = name
    if best:
        return best
    # Verb-swap fallback: the model kept the distinctive NOUN but changed the verb
    # ("find the hotels" for search_hotels, "look up flights" for search_flights).
    # Match on the tool id's non-verb tokens, which are unique per tool.
    for name in known:
        noun_tokens = set(name.split("_")) - _TOOLNAME_VERBS
        if noun_tokens and noun_tokens <= tokens:
            if best is None or len(noun_tokens) > len(set(best.split("_")) - _TOOLNAME_VERBS):
                best = name
    return best


class _ToolCallFunction:
    def __init__(self, name: str, arguments: str):
        self.name = name
        self.arguments = arguments


class _SalvagedToolCall:
    def __init__(self, id: str, name: str, arguments: str):
        self.id = id
        self.type = "function"
        self.function = _ToolCallFunction(name, arguments)


class _SalvagedMessage:
    """Mimics the Groq message object so the orchestrator can treat it uniformly."""
    def __init__(self, content: str | None, tool_calls: list):
        self.content = content
        self.tool_calls = tool_calls


# Llama sometimes emits bare integer arithmetic as a JSON value
# (e.g. "total_price_pkr":5848*8), which no JSON parser accepts. Only the
# narrow digits*digits form is repaired — anything else still fails parsing.
_JSON_INT_MULT_RE = re.compile(r"(?<=[:\s\[,])(\d+)\s*\*\s*(\d+)(?=\s*[,\}\]])")


def _repair_json_arithmetic(args: str) -> str:
    return _JSON_INT_MULT_RE.sub(
        lambda m: str(int(m.group(1)) * int(m.group(2))), args
    )


# The same leaked markup, but with the closing </function> missing entirely:
#   <function=prepare_booking>{"booking_type":"flight", ...}
# _MALFORMED_FUNC_RE requires the closing tag, so these salvage to NOTHING — and a
# reply that is nothing but unsalvageable markup gets stripped to an empty string
# upstream, which surfaced to the user as "I'm having trouble responding right
# now." (reported repeatedly on multi-call turns, e.g. booking both legs of a
# round trip, where the second call is the one left unterminated). The JSON is
# still read by BALANCED BRACES and must parse — nothing is guessed or repaired
# into existence, so a genuinely truncated payload is still dropped rather than
# dispatched with invented arguments.
_DANGLING_FUNC_RE = re.compile(r"<function=([a-zA-Z0-9_ .\-]+?)\s*>?\s*(?=\{)")


def _json_object_at(text: str, start: int) -> str | None:
    """The balanced {...} substring beginning at `start`, or None if it never closes.

    Brace-counting is string-aware so a '}' inside a value ("note": "a } b")
    doesn't end the object early.
    """
    depth = 0
    in_str = False
    escaped = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_str:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return None


def _accept_args(raw: str) -> str | None:
    """Validated tool arguments, or None when they aren't usable JSON."""
    try:
        json.loads(raw)
        return raw
    except json.JSONDecodeError:
        repaired = _repair_json_arithmetic(raw)
        try:
            json.loads(repaired)
        except json.JSONDecodeError:
            return None
        return repaired


def _salvage_tool_calls(text: str | None, known: set[str] | None = None) -> list | None:
    """Extract well-formed tool calls from a malformed <function=...> blob.

    `known` is the set of real tool ids for this turn; the captured function name
    is normalised against it, and any call whose name can't be resolved to a real
    tool is dropped (never dispatched)."""
    if not text:
        return None
    known = known or set()
    calls: list = []
    consumed: list[tuple[int, int]] = []
    for i, m in enumerate(_MALFORMED_FUNC_RE.finditer(text)):
        raw_name, args = m.group(1), m.group(2)
        consumed.append(m.span())
        name = _normalize_tool_name(raw_name, known)
        if not name:
            continue  # couldn't map to a real tool — don't invent a dispatch
        args = _accept_args(args)
        if args is None:
            continue
        calls.append(_SalvagedToolCall(f"call_salvaged_{i}", name, args))

    # Second pass for calls whose closing </function> never arrived. Regions the
    # pass above already claimed are skipped, so a blob holding one complete call
    # and one unterminated call recovers BOTH rather than only the first.
    for j, m in enumerate(_DANGLING_FUNC_RE.finditer(text)):
        if any(lo <= m.start() < hi for lo, hi in consumed):
            continue
        name = _normalize_tool_name(m.group(1), known)
        if not name:
            continue
        blob = _json_object_at(text, m.end())
        if blob is None:
            continue  # truncated mid-JSON — dropping beats guessing the rest
        args = _accept_args(blob)
        if args is None:
            continue
        calls.append(_SalvagedToolCall(f"call_dangling_{j}", name, args))

    return calls or None


def _salvage_from_exception(exc: Exception, known: set[str] | None = None) -> list | None:
    """Pull failed_generation out of a Groq tool_use_failed 400 and parse it."""
    failed_text = None
    body = getattr(exc, "body", None)
    if isinstance(body, dict):
        failed_text = (body.get("error") or {}).get("failed_generation")
    # Fall back to scanning the string form — the <function=...> blob appears there too.
    return _salvage_tool_calls(failed_text or str(exc), known)


def _openrouter_tool_message(data: dict, known: set[str] | None = None):
    """Wrap an OpenRouter (OpenAI-format) response into the .content/.tool_calls
    shape the orchestrator expects, reusing the salvage mimic classes."""
    try:
        message = data["choices"][0]["message"]
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMError(f"openrouter malformed tool response: {exc}",
                       kind=TOOL_CALL_FAILURE, provider="openrouter") from exc

    content = message.get("content")
    raw_calls = message.get("tool_calls") or []
    calls: list = []
    for i, c in enumerate(raw_calls):
        fn = (c or {}).get("function") or {}
        name = fn.get("name")
        if not name:
            continue
        calls.append(_SalvagedToolCall(
            c.get("id") or f"or_call_{i}", name, fn.get("arguments") or "{}"))
    # No structured calls but a malformed <function=...> blob in content → salvage it.
    if not calls and content:
        salvaged = _salvage_tool_calls(content, known)
        if salvaged:
            return _SalvagedMessage(None, salvaged)
    return _SalvagedMessage(content, calls)


async def _groq_generate_with_tools(
    messages: list[dict],
    tools: list[dict] | None,
    *,
    temperature: float,
    max_output_tokens: int,
    max_attempts: int,
    key_index: int = 0,
):
    """
    Groq tool-calling loop with malformed-call salvage + transient-error retry.

    `key_index` selects which Groq account runs it. Both keys use this same
    OpenAI-schema adapter and the same model — key 2 is another budget, not
    another integration.
    """
    client = _groq_client_for(key_index)
    slot = _GROQ_SLOT_NAMES[key_index]
    state = _groq_state_for(key_index)
    if client is None:
        raise LLMError("groq client unavailable", kind=PROVIDER_UNAVAILABLE, provider=slot)

    kwargs: dict = {
        "model": settings.GROQ_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_output_tokens,
    }
    if tools:
        kwargs["tools"] = tools
        kwargs["tool_choice"] = "auto"

    known_names = _tool_names_from_schemas(tools)
    est_in = estimate_request_tokens(messages, tools)
    last_exc: Exception | None = None
    for attempt in range(max_attempts):
        try:
            response = await client.chat.completions.create(**kwargs)
            message = response.choices[0].message
            usage = getattr(response, "usage", None)
            state.note_success(settings.GROQ_MODEL)
            _log_call(slot, settings.GROQ_MODEL, est_in=est_in, status="ok",
                      actual_in=getattr(usage, "prompt_tokens", None),
                      actual_out=getattr(usage, "completion_tokens", None))
            # Llama sometimes emits a tool call as TEXT content instead of a
            # structured call ("<function=search for flights>{...}</function>")
            # WITHOUT a 400 error. With no structured tool_calls, salvage it from
            # the content so the raw markup never reaches the user as a chat bubble.
            if known_names and not getattr(message, "tool_calls", None) and getattr(message, "content", None):
                salvaged = _salvage_tool_calls(message.content, known_names)
                if salvaged:
                    logger.info("Recovered %d malformed tool call(s) from Groq content", len(salvaged))
                    return _SalvagedMessage(None, salvaged)
            return message
        except Exception as exc:
            err = str(exc)
            if "tool_use_failed" in err or "Failed to call a function" in err:
                salvaged = _salvage_from_exception(exc, known_names)
                if salvaged:
                    # Logged like any other call: the request still cost tokens, and
                    # a rising salvage rate is the signal that the model is drifting.
                    _log_call(slot, settings.GROQ_MODEL, est_in=est_in,
                              status="ok_salvaged",
                              detail=f"{len(salvaged)} malformed tool call(s) recovered")
                    state.note_success(settings.GROQ_MODEL)
                    return _SalvagedMessage(None, salvaged)
                last_exc = exc
                continue  # stochastic slip — retry
            typed = _groq_exception_error(exc, est_in, key_index=key_index)
            # A quota wall, a bad key or an oversized payload will not improve on a
            # retry — surface them immediately so the caller can fail over.
            if typed.kind in (QUOTA_MINUTE, QUOTA_DAILY, INVALID_KEY, REQUEST_TOO_LARGE):
                raise typed from exc
            # Transient server-side errors (over capacity, gateway) — back off and retry
            if any(code in err for code in ("500", "502", "503", "504")) or "over capacity" in err.lower():
                last_exc = exc
                if attempt < max_attempts - 1:
                    await asyncio.sleep(0.6 * (2 ** attempt))  # 0.6s, 1.2s, 2.4s
                continue
            raise typed from exc

    raise LLMError(f"groq tool call failed after {max_attempts} attempts: {last_exc}",
                   kind=TOOL_CALL_FAILURE, provider=slot, model=settings.GROQ_MODEL)


async def _openrouter_generate_with_tools(
    messages: list[dict],
    tools: list[dict] | None,
    *,
    temperature: float,
    max_output_tokens: int,
):
    """Tool-calling via OpenRouter (OpenAI-compatible). One shot — no salvage loop."""
    data = await _openrouter_chat_raw(
        messages, temperature=temperature,
        max_output_tokens=max_output_tokens, tools=tools,
    )
    return _openrouter_tool_message(data, _tool_names_from_schemas(tools))


async def generate_with_tools(
    messages: list[dict],
    tools: list[dict] | None,
    *,
    temperature: float = 0.4,
    max_output_tokens: int = 1600,
    max_attempts: int = 3,
):
    """
    Tool-calling chat completion. Returns an assistant message object exposing
    `.content` (str|None) and `.tool_calls` (list|None).

    THREE tool-capable providers, tried in order of cost and speed:
        1. Groq (Llama 3.3)  — OpenAI tool schema
        2. OpenRouter        — OpenAI tool schema, second independent budget
        3. Gemini            — NATIVE function calling (translated in
                               _gemini_generate_with_tools), third budget

    Gemini being in this chain is what stops a tool-using turn from dying when the
    first two budgets are spent — previously it was text-only, so the agentic path
    had exactly two lives per day and then degraded to "try again in a minute" for
    the rest of the day.

    Each provider is skipped when its own state says it cannot serve right now
    (daily wall, bad key, or a model that already refused a payload this size).
    Raises the last typed LLMError if every provider fails, so the orchestrator can
    tell the user WHICH kind of failure it was.

    The caller passes a complete OpenAI/Groq-format message list (which may include
    'tool' role messages and assistant messages carrying tool_calls).
    """
    attempted = False
    last_error: LLMError | None = None

    # 1 — Groq, key 1 then (only on a DAILY wall) key 2. Its cooldown is only
    # honoured when something else can actually serve; with no live fallback a
    # doomed-but-quick attempt beats no attempt.
    for key_index in _groq_slots_to_try(_fallback_ready()):
        attempted = True
        try:
            return await _groq_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens, max_attempts=max_attempts,
                key_index=key_index,
            )
        except LLMError as exc:
            last_error = exc
            # A second key is a second DAILY budget and nothing else. A minute
            # wall clears on its own, a 413 fails identically, and a malformed
            # request is our bug — none of those get better on another account,
            # so only a daily wall is worth spending the next key on.
            if exc.kind != QUOTA_DAILY:
                logger.warning("Groq tools failed (%s) — trying OpenRouter", exc.kind)
                break
            logger.warning(
                "Groq key %d is out of daily quota — trying the next Groq key",
                key_index + 1,
            )

    # 2 — OpenRouter.
    if settings.OPENROUTER_API_KEY and _openrouter_state.available():
        attempted = True
        try:
            return await _openrouter_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens,
            )
        except LLMError as exc:
            last_error = exc
            logger.warning("OpenRouter tools failed (%s) — trying Gemini", exc.kind)

    # 3 — Gemini native function calling.
    if (settings.GEMINI_API_KEY and _gemini_state.available()
            and not _model_oversized(_gemini_state, _gemini_model())):
        attempted = True
        try:
            return await _gemini_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens,
            )
        except LLMError as exc:
            last_error = exc
            logger.warning("Gemini tools failed (%s)", exc.kind)

    # Last resort: every provider was SKIPPED on state alone (all in cooldown) and
    # none was actually asked. A per-minute wall often clears in the seconds since
    # it was recorded, so ask the cheapest one rather than reporting a failure we
    # never confirmed. A DAILY wall is not retried — that budget is measurably gone,
    # and neither is a model that already refused a payload this size.
    if not attempted:
        candidates: list[tuple[str, str, Any]] = [
            (_GROQ_SLOT_NAMES[i], settings.GROQ_MODEL,
             lambda i=i: _groq_generate_with_tools(
                 messages, tools, temperature=temperature,
                 max_output_tokens=max_output_tokens, max_attempts=max_attempts,
                 key_index=i))
            for i in range(len(settings.groq_api_keys))
        ]
        candidates.append(
            ("gemini", _gemini_model(), lambda: _gemini_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens))
        )
        for name, model, call in candidates:
            state = _provider_states()[name]
            if (not _configured(name) or state.daily_exhausted()
                    or _model_oversized(state, model)):
                continue
            logger.warning("all providers in cooldown — retrying %s anyway", name)
            try:
                return await call()
            except LLMError as exc:
                last_error = exc

    raise last_error or _no_provider_error()


def _model_oversized(state: _ProviderState, model: str | None) -> bool:
    """
    True when this exact model already answered 413 for a payload this size.

    A 413 is the one failure that is guaranteed to repeat: the agentic loop
    calls generate_with_tools once per tool step, and each step's payload is
    STRICTLY LARGER than the last (it carries the previous step's tool results).
    So re-asking the same model after a 413 cannot succeed — it just spends
    another slice of the turn budget the user is waiting on. Skipping it moves
    straight to the next provider, and the marker is cleared by note_success as
    soon as that model accepts anything again, so a shrunken payload re-enables
    it without a restart.
    """
    if not model:
        return False
    if model not in state.oversized_models:
        return False
    logger.warning(
        "skipping %s/%s — it already refused a payload this size (413)",
        state.name, model,
    )
    return True


def _no_provider_error() -> LLMError:
    """
    The typed error for "we never even sent a request".

    Two very different situations end up here and the user-facing wording for
    them is not the same, so they must not share a kind:

      · every configured provider is sitting on a known DAILY wall — that is a
        real, temporary quota fact, and the honest answer is "the daily budget
        is spent, try tomorrow". Reporting it as PROVIDER_UNAVAILABLE would
        show a generic "something went wrong", which invites the user to retry
        immediately, forever, against a wall we already know about.
      · nothing is configured — a deployment fault, not a quota one.
    """
    walled = [
        (name, state) for name, state in _provider_states().items()
        if _configured(name) and state.daily_exhausted()
    ]
    configured = [name for name in _provider_states() if _configured(name)]
    if configured and len(walled) == len(configured):
        soonest = min(state.seconds_left() for _, state in walled)
        return LLMError(
            "all providers on a daily quota wall: "
            + ", ".join(name for name, _ in walled),
            kind=QUOTA_DAILY,
            provider=walled[0][0],
            retry_after=soonest,
        )
    return LLMError("no tool-capable provider available", kind=PROVIDER_UNAVAILABLE)


def tool_capable_providers() -> list[str]:
    """
    Configured providers that can actually run the agentic tool loop.

    Every provider in the chain above is tool-capable, so this is really a
    configuration check: it is what lets the caller say "the assistant has no
    reasoning provider configured" instead of failing obscurely mid-turn.

    Deliberately lists PROVIDERS, not budgets — a second Groq key is a second
    daily allowance on the same provider, not a second thing that could be
    configured wrongly, and callers use this to decide what to tell the user.
    """
    return [name for name in ("groq", "openrouter", "gemini") if _configured(name)]
