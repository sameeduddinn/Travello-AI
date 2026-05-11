# =============================================================================
# PREFIX: /notifications
# =============================================================================

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from core.auth import CurrentUser
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/notifications", tags=["Notifications"])


class NotificationOut(BaseModel):
    id: str
    user_id: str
    title: str
    body: str
    type: str
    is_read: bool
    data: dict[str, Any]
    created_at: str | None = None


# GET /notifications

@router.get("", response_model=list[NotificationOut])
async def list_notifications(user: CurrentUser):
    """
    Return all notifications for the authenticated user.
    Unread notifications appear first, then sorted by newest.
    """
    result = (
        supabase_admin.table("notifications")
        .select("*")
        .eq("user_id", user.id)
        .order("is_read", desc=False)    # unread (false) first
        .order("created_at", desc=True)
        .limit(50)
        .execute()
    )

    return [
        NotificationOut(
            id=str(r["id"]),
            user_id=str(r["user_id"]),
            title=r.get("title", ""),
            body=r.get("body", ""),
            type=r.get("type", "system"),
            is_read=bool(r.get("is_read", False)),
            data=r.get("data") or {},
            created_at=str(r.get("created_at", "")),
        )
        for r in (result.data or [])
    ]


# PUT /notifications/{notification_id}/read

@router.put("/{notification_id}/read", response_model=NotificationOut)
async def mark_as_read(notification_id: str, user: CurrentUser):
    """Mark a single notification as read."""
    result = (
        supabase_admin.table("notifications")
        .update({"is_read": True})
        .eq("id", notification_id)
        .eq("user_id", user.id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )

    r = result.data[0]
    return NotificationOut(
        id=str(r["id"]),
        user_id=str(r["user_id"]),
        title=r.get("title", ""),
        body=r.get("body", ""),
        type=r.get("type", "system"),
        is_read=True,
        data=r.get("data") or {},
        created_at=str(r.get("created_at", "")),
    )


# PUT /notifications/read-all

@router.put("/read-all")
async def mark_all_as_read(user: CurrentUser):
    """Mark all unread notifications as read for the authenticated user."""
    supabase_admin.table("notifications").update({"is_read": True}).eq(
        "user_id", user.id
    ).eq("is_read", False).execute()

    return {"success": True, "message": "All notifications marked as read."}
