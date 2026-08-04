from __future__ import annotations
# PURPOSE: The project's "self-improvement mechanism" — NOT model fine-tuning.

import asyncio
import json
import logging

from agents.agent_tools import (
    date_provenance_error,
    execute_tool,
    suggest_city_correction,
)
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)


# ── Supabase logging — fire-and-forget, must NEVER raise or block a turn ──────

def _truncate(value, n: int = 500) -> str | None:
    if value is None:
        return None
    s = str(value)
    return s[:n]


async def log_agent_failure(
    *,
    user_id: str,
    conversation_id: str | None,
    failure_type: str,  # 'tool_call_error' | 'slot_fill_failure' | 'user_correction'
    user_message: str,
    tool_name: str | None = None,
    tool_args: dict | None = None,
    error_detail: str | None = None,
    assistant_message: str | None = None,
    retry_attempted: bool = False,
    retry_corrected_args: dict | None = None,
    retry_succeeded: bool | None = None,
) -> None:
    """
    Insert one row into agent_failure_log. This is the entire "self-improvement"
    data trail — reviewed by a human later, never read back into the model.
    Mirrors the fire-and-forget posture of master_agent._log_task: failures
    here must never surface to the user or interrupt the turn.
    """
    payload = {
        "user_id": user_id,
        "conversation_id": conversation_id,
        "failure_type": failure_type,
        "tool_name": tool_name,
        "tool_args": tool_args,
        "error_detail": _truncate(error_detail),
        "user_message": _truncate(user_message) or "",
        "assistant_message": _truncate(assistant_message),
        "retry_attempted": retry_attempted,
        "retry_corrected_args": retry_corrected_args,
        "retry_succeeded": retry_succeeded,
    }

    def _insert():
        return supabase_admin.table("agent_failure_log").insert(payload).execute()

    try:
        await asyncio.to_thread(_insert)
    except Exception as exc:
        logger.debug("agent_failure_log insert failed (non-fatal): %s", exc)


# ── User-correction detector ───────────────────────────────────────────────────
#
# Heuristic and deliberately conservative: fires only on an explicit correction
# phrase, never on ordinary disagreement ("no thanks") or a plain new request.
# This is a LOGGING signal only, never a retry trigger — only the user actually
# knows what the real correction is, so nothing here guesses at it.

_CORRECTION_PHRASES: tuple[str, ...] = (
    "no i meant", "no, i meant", "i didn't say", "i did not say",
    "that's wrong", "thats wrong", "that is wrong", "you got it wrong",
    "you misunderstood", "you misheard", "not what i said", "not what i asked",
    "i actually said", "wrong city", "wrong date", "wrong dates",
    "wrong airport", "wrong number", "wrong amount", "that's not right",
    "thats not right", "that's incorrect", "thats incorrect",
    "you made a mistake", "that's a mistake", "correction:",
    "i never said", "misunderstood me",
)


def detect_user_correction(message: str) -> bool:
    """True if this message reads like the user correcting a prior agent turn."""
    msg = (message or "").lower()
    return any(phrase in msg for phrase in _CORRECTION_PHRASES)


# ── Retryable-failure classification ───────────────────────────────────────────

def _classify_retry(name: str, args: dict, error_data: dict) -> tuple[str, dict] | None:
    """
    Decide whether a tool failure "looks fixable" without the user. Returns
    (failure_type, corrected_args) when it is, else None — a None here means
    the only honest fix is asking the user, so it gets logged, never retried.
    """
    err = error_data.get("error")

    # A real exception from the downstream service — assume transient and
    # replay the EXACT same call once. Nothing about the args changes; this is
    # the "tool_call_error" category.
    if err == "tool_execution_error":
        return "tool_call_error", dict(args or {})

    # search_flights' scope guard rejected the origin/destination as
    # unrecognized. If either city is a close spelling match to a REAL known
    # place (suggest_city_correction is strict — see agent_tools.py), that was
    # a typo, not an actual unknown/international destination — correct it and
    # retry. This is a "slot_fill_failure": the model filled the slot wrong,
    # and the correction is deterministic, not guessed.
    if name == "search_flights" and isinstance(err, str) and (
        "outside Pakistan" in err or "No domestic airport" in err
    ):
        corrected = dict(args or {})
        changed = False
        for field in ("origin_city", "destination_city"):
            # corrected[...] holds raw model-authored tool arguments, so the
            # value is not guaranteed to be a string.
            fix = suggest_city_correction(corrected.get(field) or "")
            if fix:
                corrected[field] = fix
                changed = True
        if changed:
            return "slot_fill_failure", corrected

    return None


# ── Main entry point — the retry-aware replacement for execute_tool dispatch ──

async def dispatch_tool_with_retry(
    *,
    user_id: str,
    conversation_id: str,
    user_message: str,
    name: str,
    args: dict,
    has_user_date: bool,
) -> str:
    """
    execute_tool, wrapped with the date-provenance gate (unchanged behaviour)
    plus one deterministic retry for failures that look fixable, and logging
    of everything that goes wrong for later human review. This IS the entire
    "self-improvement" mechanism described in the FYP report: logging + a
    single bounded retry, no fine-tuning, no autonomous prompt/weight changes.
    """
    gate = date_provenance_error(name, has_user_date=has_user_date)
    if gate:
        logger.info("date-provenance gate blocked %s — no user-supplied date this conversation", name)
        asyncio.ensure_future(log_agent_failure(
            user_id=user_id, conversation_id=conversation_id,
            failure_type="slot_fill_failure", user_message=user_message,
            tool_name=name, tool_args=args, error_detail="date_not_provided",
        ))
        return json.dumps(gate)

    raw = await execute_tool(name, args)
    data = _safe_json(raw)
    if data is None or "error" not in data:
        return raw  # success — nothing to log or retry

    classified = _classify_retry(name, args, data)
    if classified is None:
        # Not safely fixable without the user — log for review, do not retry.
        asyncio.ensure_future(log_agent_failure(
            user_id=user_id, conversation_id=conversation_id,
            failure_type="slot_fill_failure", user_message=user_message,
            tool_name=name, tool_args=args, error_detail=str(data.get("error")),
        ))
        return raw

    failure_type, corrected_args = classified
    retry_raw = await execute_tool(name, corrected_args)
    retry_data = _safe_json(retry_raw)
    retry_succeeded = retry_data is not None and "error" not in retry_data

    asyncio.ensure_future(log_agent_failure(
        user_id=user_id, conversation_id=conversation_id,
        failure_type=failure_type, user_message=user_message,
        tool_name=name, tool_args=args, error_detail=str(data.get("error")),
        retry_attempted=True, retry_corrected_args=corrected_args,
        retry_succeeded=retry_succeeded,
    ))
    return retry_raw


def _safe_json(raw: str) -> dict | None:
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else None
    except (json.JSONDecodeError, TypeError):
        return None
