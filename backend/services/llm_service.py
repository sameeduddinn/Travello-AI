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


def _use_groq(has_fallback: bool) -> bool:
    """
    Whether to try Groq at all. A known cooldown is only worth honouring when
    something else can serve the request — with no fallback configured, a doomed
    attempt still beats no attempt.
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
    # Primary: Groq (free, fast) — unless it is in a known rate-limit cooldown
    if _use_groq(bool(settings.OPENROUTER_API_KEY or settings.GEMINI_API_KEY)):
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
    # Primary: Groq with json_mode — unless it is in a known rate-limit cooldown
    if _use_groq(bool(settings.OPENROUTER_API_KEY or settings.GEMINI_API_KEY)):
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
# Groq then rejects the request with a 400 'tool_use_failed'. We salvage the
# intended call(s) from that error payload so a stochastic formatting slip
# doesn't break the turn. The optional '>' must be matched — otherwise a
# refusal or answer the model already generated correctly, with only this
# trailing malformed call attached, is thrown away and the turn silently
# falls back to the legacy pipeline for an unrelated formatting reason.
_MALFORMED_FUNC_RE = re.compile(
    r"<function=([a-zA-Z0-9_]+)\s*>?\s*(\{.*?\})\s*</function>", re.DOTALL
)


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


def _salvage_tool_calls(text: str | None) -> list | None:
    """Extract well-formed tool calls from a malformed <function=...> blob."""
    if not text:
        return None
    calls: list = []
    for i, m in enumerate(_MALFORMED_FUNC_RE.finditer(text)):
        name, args = m.group(1), m.group(2)
        try:
            json.loads(args)  # only accept valid JSON args
        except json.JSONDecodeError:
            repaired = _repair_json_arithmetic(args)
            try:
                json.loads(repaired)
            except json.JSONDecodeError:
                continue
            args = repaired
        calls.append(_SalvagedToolCall(f"call_salvaged_{i}", name, args))
    return calls or None


def _salvage_from_exception(exc: Exception) -> list | None:
    """Pull failed_generation out of a Groq tool_use_failed 400 and parse it."""
    failed_text = None
    body = getattr(exc, "body", None)
    if isinstance(body, dict):
        failed_text = (body.get("error") or {}).get("failed_generation")
    # Fall back to scanning the string form — the <function=...> blob appears there too.
    return _salvage_tool_calls(failed_text or str(exc))


def _openrouter_tool_message(data: dict):
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
        salvaged = _salvage_tool_calls(content)
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

    last_exc: Exception | None = None
    for attempt in range(max_attempts):
        try:
            response = await client.chat.completions.create(**kwargs)
            return response.choices[0].message
        except Exception as exc:
            err = str(exc)
            if "429" in err or "rate_limit" in err.lower():
                _note_groq_rate_limit(exc)
                raise LLMError("quota_exhausted")
            if "401" in err or "403" in err:
                raise LLMError("invalid_key")
            if "tool_use_failed" in err or "Failed to call a function" in err:
                salvaged = _salvage_from_exception(exc)
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
    return _openrouter_tool_message(data)


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
    groq_ready = _use_groq(bool(settings.OPENROUTER_API_KEY))
    if groq_ready:
        try:
            return await _groq_generate_with_tools(
                messages, tools, temperature=temperature,
                max_output_tokens=max_output_tokens, max_attempts=max_attempts,
            )
        except LLMError as exc:
            if not settings.OPENROUTER_API_KEY:
                raise
            logger.warning("Groq tools failed (%s) — falling back to OpenRouter", exc)

    if settings.OPENROUTER_API_KEY:
        return await _openrouter_generate_with_tools(
            messages, tools, temperature=temperature, max_output_tokens=max_output_tokens,
        )

    raise LLMError("groq_unavailable")
