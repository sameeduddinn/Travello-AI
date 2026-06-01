from __future__ import annotations
# =============================================================================
# PURPOSE: Persistence layer for the multi-agent system.
#
#   - user_preferences  : long-lived per-user travel profile (read/write/upsert)
#   - ai_conversations  : conversation lifecycle
#   - ai_messages       : chat history (user/assistant only — never system)
#
# All Supabase calls are wrapped in asyncio.to_thread because supabase-py v2 is
# synchronous and we don't want to block the event loop in async agent code.
# =============================================================================

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any

from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)


# Fields safe to upsert into user_preferences (excludes id/timestamps/theme/language)
_UPSERTABLE_PREF_FIELDS = {
    "origin_city",
    "currency",
    "preferred_class",
    "travel_style",
    "companion_type",
    "budget_style",
    "past_destinations",
}


# user profile (name, email, cnic from profiles table)

async def get_user_profile(user_id: str) -> dict[str, Any]:
    """
    Fetch the user's basic profile: full_name, email, cnic.
    Returns {} on any failure — never raises.
    """
    def _query():
        # profiles table columns: full_name, phone, avatar_url (NOT cnic/name/email)
        return (
            supabase_admin.table("profiles")
            .select("full_name, phone")
            .eq("id", user_id)
            .limit(1)
            .execute()
        )

    try:
        result = await asyncio.to_thread(_query)
        rows = result.data or []
        if not rows:
            return {}
        row = rows[0]
        return {
            "display_name": row.get("full_name") or "",
            "phone": row.get("phone") or "",
        }
    except Exception as exc:
        logger.warning("get_user_profile failed for user=%s: %s", user_id, exc)
        return {}


# user_preferences

async def get_user_memory(user_id: str) -> dict[str, Any]:
    """
    Fetch the user's saved travel preferences.
    Returns {} if the user has no preferences row yet.
    """
    def _query():
        return (
            supabase_admin.table("user_preferences")
            .select("*")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )

    try:
        result = await asyncio.to_thread(_query)
        rows = result.data or []
        return rows[0] if rows else {}
    except Exception as exc:
        logger.warning("get_user_memory failed for user=%s: %s", user_id, exc)
        return {}


async def save_user_memory(user_id: str, preferences: dict[str, Any]) -> None:
    """
    Upsert the user's travel preferences. Only writes fields in the
    `_UPSERTABLE_PREF_FIELDS` allow-list — silently drops anything else
    (id, theme, language, created_at, updated_at).
    """
    payload: dict[str, Any] = {
        k: v
        for k, v in preferences.items()
        if k in _UPSERTABLE_PREF_FIELDS and v is not None
    }
    if not payload:
        return  # nothing to update
    payload["user_id"] = user_id

    def _upsert():
        return (
            supabase_admin.table("user_preferences")
            .upsert(payload, on_conflict="user_id")
            .execute()
        )

    try:
        await asyncio.to_thread(_upsert)
    except Exception as exc:
        logger.warning("save_user_memory failed for user=%s: %s", user_id, exc)


# ai_conversations

async def start_new_conversation(
    user_id: str,
    title: str = "New Conversation",
) -> str:
    """
    Create a new ai_conversations row and return its UUID.
    Raises on failure — caller cannot proceed without a conversation id.
    """
    def _insert():
        return (
            supabase_admin.table("ai_conversations")
            .insert({"user_id": user_id, "title": title})
            .execute()
        )

    result = await asyncio.to_thread(_insert)
    rows = result.data or []
    if not rows:
        raise RuntimeError("Failed to create ai_conversations row")
    return str(rows[0]["id"])


# ai_messages

async def get_conversation_history(
    conversation_id: str,
    limit: int = 20,
) -> list[dict[str, str]]:
    """
    Return the last `limit` messages in chronological (ASC) order, formatted for
    Gemini: [{"role": "user"|"assistant", "content": "..."}, ...]

    System messages are never returned — they belong in system_instruction, not
    contents.
    """
    def _query():
        # Pull DESC + limit, then reverse — gives us the *last* N messages.
        return (
            supabase_admin.table("ai_messages")
            .select("role, content")
            .eq("conversation_id", conversation_id)
            .in_("role", ["user", "assistant"])
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )

    try:
        result = await asyncio.to_thread(_query)
        rows = list(result.data or [])
        rows.reverse()  # oldest first
        return [
            {"role": r["role"], "content": r["content"] or ""}
            for r in rows
        ]
    except Exception as exc:
        logger.warning("get_conversation_history failed for conv=%s: %s", conversation_id, exc)
        return []


async def save_message(
    conversation_id: str,
    user_id: str,
    role: str,
    content: str,
    model_used: str = "llama-3.3-70b-versatile",
    input_tokens: int = 0,
    output_tokens: int = 0,
    message_type: str = "text",
) -> None:
    """
    Persist a single message to ai_messages.

    `role` MUST be 'user' or 'assistant' (never 'model' — that's a Gemini
    internal name; we always store the canonical 'assistant').
    """
    if role not in ("user", "assistant"):
        raise ValueError(f"save_message: invalid role={role!r} (must be 'user' or 'assistant')")

    payload = {
        "conversation_id": conversation_id,
        "user_id": user_id,
        "role": role,
        "content": content,
        "message_type": message_type,
        "model_used": model_used,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
    }

    def _insert():
        supabase_admin.table("ai_messages").insert(payload).execute()
        # Keep conversation updated_at current so list ordering stays correct.
        supabase_admin.table("ai_conversations").update(
            {"updated_at": datetime.now(timezone.utc).isoformat()}
        ).eq("id", conversation_id).execute()

    try:
        await asyncio.to_thread(_insert)
    except Exception as exc:
        logger.warning("save_message failed for conv=%s: %s", conversation_id, exc)


# Memory -> prompt formatting

async def format_memory_for_prompt(user_id: str) -> str:
    """
    Build a one-line preference summary for injection into agent prompts.
    Returns '' if the user has no saved preferences.
    """
    prefs = await get_user_memory(user_id)
    if not prefs:
        return ""

    return (
        "User preferences: "
        f"home city={prefs.get('origin_city')}, "
        f"preferred class={prefs.get('preferred_class')}, "
        f"travel style={prefs.get('travel_style')}, "
        f"companion type={prefs.get('companion_type')}, "
        f"budget style={prefs.get('budget_style')}, "
        f"past destinations={prefs.get('past_destinations')}"
    )
