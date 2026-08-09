from __future__ import annotations
# PURPOSE: Persistence layer for the multi-agent system.
#
#   - user_preferences  : long-lived per-user travel profile (read/write/upsert)
#   - ai_conversations  : conversation lifecycle
#   - ai_messages       : chat history (user/assistant only — never system)
#
# All Supabase calls are wrapped in asyncio.to_thread because supabase-py v2 is
# synchronous and we don't want to block the event loop in async agent code.

import asyncio
import logging
from datetime import datetime, timedelta, timezone
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

class ConversationHistoryUnavailable(Exception):
    """
    The history read itself failed — a network/DB error, not "no messages
    yet". Deliberately distinct from a genuine empty result: a caller that
    treats both the same cannot tell a brand-new conversation apart from an
    existing one whose history just failed to load, which is exactly the
    trap a trip-planner selection turn ("Flight 2, Hotel 3, Transfer 1") can
    fall into — see process_message_agentic.
    """


async def get_conversation_history(
    conversation_id: str,
    limit: int = 20,
) -> list[dict[str, str]]:
    """
    Return the last `limit` messages in chronological (ASC) order, formatted for
    Gemini: [{"role": "user"|"assistant", "content": "..."}, ...]

    System messages are never returned — they belong in system_instruction, not
    contents.

    Raises ConversationHistoryUnavailable if the read itself fails, rather than
    silently standing in a genuine empty history — every existing caller in
    this codebase already wraps this call in whatever handling it wants
    (process_message keeps the old swallow-to-[] behaviour locally;
    process_message_agentic distinguishes the two cases). This function no
    longer decides that on their behalf.
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
    except Exception as exc:
        logger.warning("get_conversation_history failed for conv=%s: %s", conversation_id, exc)
        raise ConversationHistoryUnavailable(str(exc)) from exc
    rows = list(result.data or [])
    rows.reverse()  # oldest first
    return [
        {"role": r["role"], "content": r["content"] or ""}
        for r in rows
    ]


async def save_message(
    conversation_id: str,
    user_id: str,
    role: str,
    content: str,
    model_used: str = "llama-3.3-70b-versatile",
    input_tokens: int = 0,
    output_tokens: int = 0,
    message_type: str = "text",
    created_at: str | None = None,
) -> None:
    """
    Persist a single message to ai_messages.

    `role` MUST be 'user' or 'assistant' (never 'model' — that's a Gemini
    internal name; we always store the canonical 'assistant').

    `created_at` (ISO-8601) may be passed to override the DB `NOW()` default.
    ai_messages has no monotonic ordering key, and history is replayed by
    `created_at` alone — so callers that persist a user+assistant pair must stamp
    explicit, strictly increasing values (see `save_turn`) to keep replay in order.
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
    if created_at is not None:
        payload["created_at"] = created_at

    def _insert_message():
        supabase_admin.table("ai_messages").insert(payload).execute()

    def _touch_conversation():
        # Keep conversation updated_at current so list ordering stays correct.
        supabase_admin.table("ai_conversations").update(
            {"updated_at": datetime.now(timezone.utc).isoformat()}
        ).eq("id", conversation_id).execute()

    # The message insert is the one write whose loss is unrecoverable — a
    # missing assistant turn here is exactly how a later selection ("Flight
    # 2, Hotel 3, Transfer 1") loses the option list it's answering. Most
    # failures at this layer are transient (a network blip, a brief
    # connection-pool hiccup), so one immediate retry recovers most of them.
    # Kept separate from the conversation-metadata touch below so a retry
    # here can never insert the message twice.
    try:
        await asyncio.to_thread(_insert_message)
    except Exception as exc:
        logger.warning(
            "save_message: ai_messages insert failed for conv=%s, retrying once: %s",
            conversation_id, exc,
        )
        try:
            await asyncio.to_thread(_insert_message)
        except Exception as exc2:
            logger.warning("save_message failed for conv=%s: %s", conversation_id, exc2)
            return

    try:
        await asyncio.to_thread(_touch_conversation)
    except Exception as exc:
        logger.warning("save_message failed for conv=%s: %s", conversation_id, exc)


# ── Interactive Trip Planner structured state ─────────────────────────────────
#
# The planner's active options+picks, stored as a role="system" ai_messages
# row rather than through save_message (which only ever accepts "user"/
# "assistant" — deliberately left untouched here, so no ordinary caller can
# accidentally start writing system rows). get_conversation_history() already
# filters to role IN ("user", "assistant"), so this row is invisible to the
# LLM-facing conversation and never competes with its limit=20 window —
# confirmed by reading that query, not assumed. Retrieval is a targeted,
# single-row, conversation_id-scoped lookup, independent of any window size.

async def save_planner_state(conversation_id: str, user_id: str, state: dict) -> None:
    """
    Persist the Trip Planner's current options+picks for this conversation.

    Same never-raises, log-and-swallow posture as save_message: a failed
    write here must never surface as a turn failure — the caller
    (process_message_agentic) already falls back to the existing
    find_options(history) text parser whenever structured state is absent,
    and a failed write is indistinguishable from "never written" to that
    fallback, which is exactly the safe behaviour wanted.
    """
    payload = {
        "conversation_id": conversation_id,
        "user_id": user_id,
        "role": "system",
        "content": "[trip planner state]",  # never displayed — role="system" is
                                             # excluded from get_conversation_history
        "message_type": "text",
        "metadata": state,
    }

    def _insert():
        supabase_admin.table("ai_messages").insert(payload).execute()

    try:
        await asyncio.to_thread(_insert)
    except Exception as exc:
        logger.warning("save_planner_state failed for conv=%s: %s", conversation_id, exc)


async def get_active_planner_state(conversation_id: str) -> dict | None:
    """
    The most recently saved structured Trip Planner state for this
    conversation, or None if none exists or the read itself fails.

    A targeted, single-row query — NOT get_conversation_history(), and not
    bounded by its limit=20, so this survives arbitrarily long conversations.
    Filtered on conversation_id AND role="system" together, so a state row
    can never be returned for — or leak into — a different conversation.

    Deliberately does not distinguish "no state yet" from "read failed": both
    return None, and the caller already has one safe response to that —
    fall back to find_options(history) — so there is nothing a second signal
    would let it do differently.
    """
    def _query():
        return (
            supabase_admin.table("ai_messages")
            .select("metadata")
            .eq("conversation_id", conversation_id)
            .eq("role", "system")
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )

    try:
        result = await asyncio.to_thread(_query)
    except Exception as exc:
        logger.warning("get_active_planner_state failed for conv=%s: %s", conversation_id, exc)
        return None
    rows = list(result.data or [])
    if not rows:
        return None
    metadata = rows[0].get("metadata")
    return metadata if isinstance(metadata, dict) else None


async def save_turn(
    conversation_id: str,
    user_id: str,
    user_message: str,
    assistant_message: str,
    model_used: str = "llama-3.3-70b-versatile",
    user_type: str = "text",
    assistant_type: str = "text",
) -> None:
    """
    Persist one user turn + the assistant reply with GUARANTEED replay ordering.

    ai_messages has only a random-UUID primary key and `created_at DEFAULT NOW()`.
    Saving the pair concurrently (asyncio.gather) let the two rows race on NOW(),
    so on reload the assistant row could tie with — or land *before* — the user
    row, scrambling the conversation (e.g. a "Book PK448" turn showing out of
    place). We stamp explicit timestamps here, the assistant strictly 1ms after
    the user, so history always replays as user-then-assistant.
    """
    base = datetime.now(timezone.utc)
    await asyncio.gather(
        save_message(
            conversation_id, user_id, "user", user_message,
            message_type=user_type, created_at=base.isoformat(),
        ),
        save_message(
            conversation_id, user_id, "assistant", assistant_message,
            model_used=model_used, message_type=assistant_type,
            created_at=(base + timedelta(milliseconds=1)).isoformat(),
        ),
    )


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
