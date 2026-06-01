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
#       1. Groq   (llama-3.3-70b-versatile)  — primary (free, fast)
#       2. Gemini (gemini-2.5-flash)         — fallback if Groq quota/timeout
#
#   To switch to Gemini-primary: swap the try-order in generate_text / generate_json.
# =============================================================================

import asyncio
import json
import logging
import re
from typing import Any

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
        _groq_client = AsyncGroq(api_key=settings.GROQ_API_KEY)
        logger.info("Groq client ready — model=%s", settings.GROQ_MODEL)
        return _groq_client
    except Exception as exc:
        logger.warning("Groq client init failed: %s", exc)
        return None


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


# ── Public API ────────────────────────────────────────────────────────────────

async def generate_text(
    messages: list[dict],
    *,
    temperature: float = 0.7,
    max_output_tokens: int = 1024,
) -> str:
    """Send chat messages, return plain-text reply. Tries Groq first, Gemini as fallback."""
    # Primary: Groq (free, fast)
    if settings.GROQ_API_KEY:
        try:
            return await _call_groq(messages, temperature=temperature,
                                    max_output_tokens=max_output_tokens)
        except LLMError as exc:
            logger.warning("Groq failed (%s), falling back to Gemini", exc)

    # Fallback: Gemini
    return await _call_gemini(messages, temperature=temperature,
                               max_output_tokens=max_output_tokens)


async def generate_json(
    messages: list[dict],
    *,
    temperature: float = 0.2,
    max_output_tokens: int = 2048,
) -> Any:
    """Force JSON output and parse it. Tries Groq first, Gemini as fallback."""
    # Primary: Groq with json_mode
    if settings.GROQ_API_KEY:
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
            logger.warning("Groq JSON failed (%s), falling back to Gemini", exc)

    # Fallback: Gemini with native JSON mime type
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
# Groq then rejects the request with a 400 'tool_use_failed'. We salvage the
# intended call(s) from that error payload so a stochastic formatting slip
# doesn't break the turn.
_MALFORMED_FUNC_RE = re.compile(
    r"<function=([a-zA-Z0-9_]+)\s*(\{.*?\})\s*</function>", re.DOTALL
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
            continue
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


async def generate_with_tools(
    messages: list[dict],
    tools: list[dict] | None,
    *,
    temperature: float = 0.4,
    max_output_tokens: int = 1600,
    max_attempts: int = 3,
):
    """
    Tool-calling chat completion (Groq / Llama 3.3). Returns the assistant message
    object, which exposes `.content` (str|None) and `.tool_calls` (list|None).

    Unlike generate_text/generate_json this does NOT split out the system message —
    the caller passes a complete OpenAI/Groq-format message list (which may include
    'tool' role messages and assistant messages carrying tool_calls). This is the
    primitive the agentic orchestrator loops on.

    Resilient to Groq's intermittent 'tool_use_failed' (malformed Llama tool call):
    it first tries to salvage the intended call from the error, then retries.
    Raises LLMError after exhausting attempts so the orchestrator can fall back.
    """
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
