from __future__ import annotations
# =============================================================================
# PURPOSE: Unified LLM service — Groq primary, Gemini as fallback.
#
#   Public API (unchanged — all agents import these):
#       generate_text(messages, *, temperature, max_output_tokens) -> str
#       generate_json(messages, *, temperature, max_output_tokens) -> Any
#       LLMError  — raised on unrecoverable failures
#
#   Provider priority:
#       1. Groq   (settings.GROQ_MODEL)       — primary (free, fast, cheap on quota)
#       2. Gemini (settings.GEMINI_MODEL)     — fallback if Groq quota/timeout
#
#   To switch to Gemini-primary: swap the try-order in generate_text / generate_json.
# =============================================================================

import asyncio
import json
import logging
import re
import time
from typing import Any

import httpx

from core.config import settings

logger = logging.getLogger(__name__)


class LLMError(RuntimeError):
    """Raised on any LLM call failure."""


# Keep GeminiError as an alias so old imports don't break during transition
GeminiError = LLMError


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

_groq_client = None


def _get_groq_client():
    global _groq_client
    if _groq_client is not None:
        return _groq_client
    if not settings.GROQ_API_KEY:
        return None
    try:
        from groq import AsyncGroq
        # max_retries=0: on a free-tier TPM 429, Groq returns a large `retry-after`
        # (~55s) and the SDK would otherwise sleep+retry internally, blowing past the
        # 60s request cap and hanging the chat UI. Fail fast instead and let the
        # orchestrator degrade gracefully (generate_with_tools -> quota_exhausted).
        _groq_client = AsyncGroq(api_key=settings.GROQ_API_KEY, max_retries=0)
        logger.info("Groq client ready — model=%s", settings.GROQ_MODEL)
        return _groq_client
    except Exception as exc:
        logger.warning("Groq client init failed: %s", exc)
        return None


# ── Groq availability window ──────────────────────────────────────────────────
#
# A Groq 429 is NOT always the per-minute wall. When the DAILY token budget is
# spent the 429 comes back with the minute-window counters still completely full
# (x-ratelimit-remaining-tokens: 12000) and a retry-after measured in TENS OF
# MINUTES. Re-probing Groq at the top of every agentic step then buys nothing and
# costs a round trip each time — three per turn, against a 60s interactive budget
# that a turn has already been observed to blow. Remember when Groq told us to
# come back, and go straight to the fallback until then.
_groq_blocked_until: float = 0.0
_GROQ_MIN_COOLDOWN = 20.0    # floor, for a 429 carrying no usable retry-after
_GROQ_MAX_COOLDOWN = 900.0   # ceiling, so one odd header can't park Groq for hours


def _groq_available() -> bool:
    return time.monotonic() >= _groq_blocked_until


def _note_groq_rate_limit(exc: Exception) -> None:
    """Park Groq for as long as it asked to be left alone."""
    global _groq_blocked_until
    delay = _GROQ_MIN_COOLDOWN
    resp = getattr(exc, "response", None)
    if resp is not None:
        try:
            delay = max(float(resp.headers.get("retry-after")), _GROQ_MIN_COOLDOWN)
        except (TypeError, ValueError, AttributeError):
            pass
    delay = min(delay, _GROQ_MAX_COOLDOWN)
    _groq_blocked_until = time.monotonic() + delay
    logger.warning("Groq rate-limited — skipping it for %.0fs", delay)


# ── OpenRouter availability window ────────────────────────────────────────────
#
# OpenRouter's free tier has its OWN daily cap (50 requests/day across ALL free
# models, keyed to the account — not the model), and when it is spent every
# configured model returns 429 instantly. Tracking that matters for more than
# saving a round trip: _use_groq below decides whether Groq's cooldown is worth
# honouring, and that decision is only sound if "there is a fallback" means a
# fallback that can actually answer right now, not merely one that has a key.
_openrouter_blocked_until: float = 0.0
_OPENROUTER_MIN_COOLDOWN = 30.0
_OPENROUTER_MAX_COOLDOWN = 900.0


def _openrouter_available() -> bool:
    return time.monotonic() >= _openrouter_blocked_until


def _note_openrouter_rate_limit(resp=None) -> None:
    """Park OpenRouter until the reset it reported (or a short default)."""
    global _openrouter_blocked_until
    delay = _OPENROUTER_MIN_COOLDOWN
    reset_ms = None
    if resp is not None:
        try:
            reset_ms = resp.headers.get("X-RateLimit-Reset")
        except Exception:
            reset_ms = None
        if reset_ms is None:
            # The daily-cap 429 carries the reset inside the error body instead.
            try:
                meta = ((resp.json().get("error") or {}).get("metadata") or {})
                reset_ms = (meta.get("headers") or {}).get("X-RateLimit-Reset")
            except Exception:
                reset_ms = None
    if reset_ms:
        try:
            secs = float(reset_ms) / 1000.0 - time.time()
            if secs > 0:
                delay = max(secs, _OPENROUTER_MIN_COOLDOWN)
        except (TypeError, ValueError):
            pass
    delay = min(delay, _OPENROUTER_MAX_COOLDOWN)
    _openrouter_blocked_until = time.monotonic() + delay
    logger.warning("OpenRouter rate-limited — skipping it for %.0fs", delay)


def _fallback_ready(include_gemini: bool = True) -> bool:
    """
    Is there a provider OTHER than Groq that could actually serve a request right
    now? A configured key is not enough — an OpenRouter key whose daily free quota
    is spent answers nothing, and treating it as a live fallback is what made the
    agent skip a perfectly healthy Groq and report "quota exhausted" instead.
    """
    if settings.OPENROUTER_API_KEY and _openrouter_available():
        return True
    return bool(include_gemini and settings.GEMINI_API_KEY)


def _use_groq(has_fallback: bool) -> bool:
    """
    Whether to try Groq at all. A known cooldown is only worth honouring when
    something else can serve the request — with no usable fallback, a doomed
    attempt still beats no attempt (and Groq's per-minute window often reset
    seconds after the 429 that parked it).
    """
    if _get_groq_client() is None:
        return False
    return _groq_available() or not has_fallback


async def _call_groq(
    messages: list[dict],
    *,
    temperature: float,
    max_output_tokens: int,
    json_mode: bool = False,
) -> str:
    client = _get_groq_client()
    if client is None:
        raise LLMError("groq_unavailable")

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

    try:
        response = await client.chat.completions.create(**kwargs)
        text = (response.choices[0].message.content or "").strip()
        if not text:
            raise LLMError("Groq returned empty response")
        logger.info("Groq usage — in=%s out=%s",
                    response.usage.prompt_tokens,
                    response.usage.completion_tokens)
        return text
    except LLMError:
        raise
    except Exception as exc:
        err = str(exc)
        if "429" in err or "rate_limit" in err.lower():
            _note_groq_rate_limit(exc)
            raise LLMError("quota_exhausted")
        if "401" in err or "403" in err:
            raise LLMError("invalid_key")
        raise LLMError(f"Groq call failed: {exc}") from exc


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


async def _call_gemini(
    messages: list[dict],
    *,
    temperature: float,
    max_output_tokens: int,
    response_mime_type: str | None = None,
) -> str:
    client = _get_gemini_client()
    if client is None:
        raise LLMError("gemini_unavailable")

    from google.genai import types

    system_text, rest = _extract_system(messages)

    contents = []
    for m in rest:
        role = "model" if m["role"] == "assistant" else "user"
        contents.append(types.Content(role=role, parts=[types.Part(text=m["content"])]))

    if not contents:
        raise LLMError("No messages to send")

    config = types.GenerateContentConfig(
        temperature=temperature,
        max_output_tokens=max_output_tokens,
        system_instruction=system_text or None,
        response_mime_type=response_mime_type,
    )

    try:
        response = await client.aio.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=contents,
            config=config,
        )
        text = (response.text or "").strip()
        if not text:
            raise LLMError("Gemini returned empty response")
        usage = getattr(response, "usage_metadata", None)
        if usage:
            logger.info("Gemini usage — in=%s out=%s",
                        getattr(usage, "prompt_token_count", "?"),
                        getattr(usage, "candidates_token_count", "?"))
        return text
    except LLMError:
        raise
    except Exception as exc:
        err = str(exc)
        if "429" in err or "RESOURCE_EXHAUSTED" in err:
            raise LLMError("quota_exhausted")
        if "401" in err or "403" in err or "PERMISSION_DENIED" in err:
            raise LLMError("invalid_key")
        raise LLMError(f"Gemini call failed: {exc}") from exc


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
_OPENROUTER_REQUEST_TIMEOUT = 20.0
_OPENROUTER_TOTAL_BUDGET = 35.0


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
    upstream (429). Raises LLMError (mapping 429 -> quota_exhausted) so callers treat it
    like Groq."""
    if not settings.OPENROUTER_API_KEY:
        raise LLMError("openrouter_unavailable")

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

    last_exc: LLMError | None = None
    deadline = time.monotonic() + _OPENROUTER_TOTAL_BUDGET
    async with httpx.AsyncClient(timeout=_OPENROUTER_REQUEST_TIMEOUT) as client:
        for model in _openrouter_models():
            if time.monotonic() >= deadline:
                # Out of budget — trying another slow free model would only push
                # the turn past the client's timeout. Surface what we have.
                logger.warning("OpenRouter budget spent — skipping remaining models")
                break
            payload = {**base_payload, "model": model}
            try:
                resp = await client.post(_OPENROUTER_URL, headers=headers, json=payload)
            except Exception as exc:
                # Transport error is the same for every model — don't hammer the list.
                raise LLMError(f"OpenRouter request failed: {exc}") from exc

            if resp.status_code in (401, 403):
                # Key-level problem — a different model won't help.
                raise LLMError("invalid_key")
            if resp.status_code == 429:
                last_exc = LLMError("quota_exhausted")
                # Free-tier limits on OpenRouter are per ACCOUNT, not per model, so
                # one 429 means the next model will 429 too. Remember it, so the
                # next turn prefers Groq instead of walking a dead model list.
                _note_openrouter_rate_limit(resp)
                logger.warning("OpenRouter model %s rate-limited (429) — trying next", model)
                continue
            if resp.status_code >= 400:
                last_exc = LLMError(f"OpenRouter HTTP {resp.status_code}: {resp.text[:200]}")
                logger.warning("OpenRouter model %s HTTP %s — trying next", model, resp.status_code)
                continue

            try:
                data = resp.json()
            except Exception as exc:
                last_exc = LLMError(f"OpenRouter returned non-JSON: {exc}")
                logger.warning("OpenRouter model %s returned non-JSON — trying next", model)
                continue

            # OpenRouter sometimes surfaces upstream provider errors inside a 200 body.
            if isinstance(data, dict) and data.get("error"):
                err = data["error"]
                msg = err.get("message", "") if isinstance(err, dict) else str(err)
                if "rate" in msg.lower() or "429" in msg:
                    last_exc = LLMError("quota_exhausted")
                    _note_openrouter_rate_limit(resp)
                    logger.warning("OpenRouter model %s rate-limited (body) — trying next", model)
                else:
                    last_exc = LLMError(f"OpenRouter error: {msg[:200]}")
                    logger.warning("OpenRouter model %s body error — trying next", model)
                continue

            return data

    # Every model failed — surface the last error (usually quota_exhausted, which the
    # orchestrator renders as the friendly "busy for a moment" message).
    raise last_exc or LLMError("quota_exhausted")


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
        raise LLMError(f"OpenRouter malformed response: {exc}") from exc
    if not text:
        raise LLMError("OpenRouter returned empty response")
    return text


# ── Public API ────────────────────────────────────────────────────────────────

async def generate_text(
    messages: list[dict],
    *,
    temperature: float = 0.7,
    max_output_tokens: int = 1024,
) -> str:
    """Send chat messages, return plain-text reply. Groq → OpenRouter → Gemini."""
    # Primary: Groq (free, fast) — its cooldown is skipped only when some other
    # provider is genuinely able to serve right now.
    if _use_groq(_fallback_ready()):
        try:
            return await _call_groq(messages, temperature=temperature,
                                    max_output_tokens=max_output_tokens)
        except LLMError as exc:
            logger.warning("Groq failed (%s), trying OpenRouter", exc)

    # Fallback 1: OpenRouter (second independent budget)
    if settings.OPENROUTER_API_KEY:
        try:
            return await _call_openrouter(messages, temperature=temperature,
                                          max_output_tokens=max_output_tokens)
        except LLMError as exc:
            logger.warning("OpenRouter failed (%s), falling back to Gemini", exc)

    # Fallback 2: Gemini
    return await _call_gemini(messages, temperature=temperature,
                               max_output_tokens=max_output_tokens)


async def generate_json(
    messages: list[dict],
    *,
    temperature: float = 0.2,
    max_output_tokens: int = 2048,
) -> Any:
    """Force JSON output and parse it. Groq → OpenRouter → Gemini."""
    # Primary: Groq with json_mode — see generate_text on the cooldown condition
    if _use_groq(_fallback_ready()):
        try:
            raw = await _call_groq(messages, temperature=temperature,
                                   max_output_tokens=max_output_tokens,
                                   json_mode=True)
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                # Groq json_mode occasionally wraps output in markdown fences — strip them
                return json.loads(_strip_code_fences(raw))
        except LLMError as exc:
            logger.warning("Groq JSON failed (%s), trying OpenRouter", exc)

    # Fallback 1: OpenRouter with json_mode
    if settings.OPENROUTER_API_KEY:
        try:
            raw = await _call_openrouter(messages, temperature=temperature,
                                         max_output_tokens=max_output_tokens,
                                         json_mode=True)
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                return json.loads(_strip_code_fences(raw))
        except (LLMError, json.JSONDecodeError) as exc:
            logger.warning("OpenRouter JSON failed (%s), falling back to Gemini", exc)

    # Fallback 2: Gemini with native JSON mime type
    raw = await _call_gemini(messages, temperature=temperature,
                              max_output_tokens=max_output_tokens,
                              response_mime_type="application/json")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error("Gemini JSON parse failed. Raw=%r", raw[:500])
        raise LLMError(f"Invalid JSON response: {exc}") from exc


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
        raise LLMError(f"OpenRouter malformed tool response: {exc}") from exc

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
):
    """Groq tool-calling loop with malformed-call salvage + transient-error retry."""
    client = _get_groq_client()
    if client is None:
        raise LLMError("groq_unavailable")

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
    last_exc: Exception | None = None
    for attempt in range(max_attempts):
        try:
            response = await client.chat.completions.create(**kwargs)
            message = response.choices[0].message
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
            if "429" in err or "rate_limit" in err.lower():
                _note_groq_rate_limit(exc)
                raise LLMError("quota_exhausted")
            if "401" in err or "403" in err:
                raise LLMError("invalid_key")
            if "tool_use_failed" in err or "Failed to call a function" in err:
                salvaged = _salvage_from_exception(exc, known_names)
                if salvaged:
                    logger.info("Recovered %d malformed tool call(s) from Groq", len(salvaged))
                    return _SalvagedMessage(None, salvaged)
                last_exc = exc
                continue  # stochastic slip — retry
            # Transient server-side errors (over capacity, gateway) — back off and retry
            if any(code in err for code in ("500", "502", "503", "504")) or "over capacity" in err.lower():
                last_exc = exc
                if attempt < max_attempts - 1:
                    await asyncio.sleep(0.6 * (2 ** attempt))  # 0.6s, 1.2s, 2.4s
                continue
            raise LLMError(f"Groq tool call failed: {exc}") from exc

    raise LLMError(f"Groq tool call failed after {max_attempts} attempts: {last_exc}")


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

    Groq (Llama 3.3) is primary; OpenRouter is the fallback on ANY Groq failure —
    crucially a rate-limit (429), so a tool-using turn can still complete under
    Groq's free-tier 12k TPM wall instead of degrading to the "try again" message.
    Both speak the OpenAI tool schema, so the same messages + tools work on either.
    Raises LLMError only if BOTH providers fail, so the orchestrator can degrade.

    The caller passes a complete OpenAI/Groq-format message list (which may include
    'tool' role messages and assistant messages carrying tool_calls).
    """
    # Gemini is not part of the tool-calling chain, so only OpenRouter counts as
    # a fallback here. If its own quota is spent, Groq is tried even while it is
    # in cooldown — a Groq per-minute wall usually clears within seconds, and an
    # attempt that might work always beats reporting "quota exhausted" without
    # having asked the one provider that is actually up.
    groq_ready = _use_groq(_fallback_ready(include_gemini=False))
    groq_error: LLMError | None = None
    if groq_ready:
        try:
            return await _groq_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens, max_attempts=max_attempts,
            )
        except LLMError as exc:
            groq_error = exc
            if not (settings.OPENROUTER_API_KEY and _openrouter_available()):
                raise
            logger.warning("Groq tools failed (%s) — falling back to OpenRouter", exc)

    if settings.OPENROUTER_API_KEY and _openrouter_available():
        try:
            return await _openrouter_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens,
            )
        except LLMError as exc:
            # Groq was skipped for its cooldown and the fallback we skipped it for
            # has just turned out to be dead. Groq is the only thing left worth
            # asking, cooldown or not.
            if not groq_ready and _get_groq_client() is not None:
                logger.warning(
                    "OpenRouter unusable (%s) — retrying Groq despite its cooldown", exc
                )
                return await _groq_generate_with_tools(
                    messages, tools, temperature=temperature,
                    max_output_tokens=max_output_tokens, max_attempts=max_attempts,
                )
            raise

    # No usable OpenRouter. If Groq was never tried this turn, try it now.
    if not groq_ready and _get_groq_client() is not None:
        return await _groq_generate_with_tools(
            messages, tools, temperature=temperature,
            max_output_tokens=max_output_tokens, max_attempts=max_attempts,
        )
    if groq_error:
        raise groq_error
    raise LLMError("groq_unavailable")
