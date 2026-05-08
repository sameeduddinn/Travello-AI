# =============================================================================
# FILE: routers/support.py
# /support
# =============================================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

from core.auth import CurrentUser
from core.config import settings
from core.email import send_email
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/support", tags=["Support"])


# ---------------------------------------------------------------------------
# GET /support/messages  — authenticated user fetches their own messages
# ---------------------------------------------------------------------------

@router.get("/messages")
async def get_support_messages(user: CurrentUser):
    """Return all support messages belonging to the authenticated user."""
    result = (
        supabase_admin.table("support_messages")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", desc=True)
        .execute()
    )
    return result.data or []


# ---------------------------------------------------------------------------
# DELETE /support/messages  — authenticated user deletes their own messages
# Only replied/closed messages can be deleted; pending ones are ignored.
# ---------------------------------------------------------------------------

@router.delete("/messages")
async def delete_support_messages(payload: DeleteMessagesRequest, user: CurrentUser):
    """Delete specific replied/closed support messages belonging to the authenticated user."""
    if not payload.ids:
        return {"deleted": 0}

    supabase_admin.table("support_messages").delete().in_(
        "id", payload.ids
    ).eq("user_id", user.id).in_("status", ["replied", "closed"]).execute()

    return {"deleted": len(payload.ids)}


# ---------------------------------------------------------------------------
# POST /support/reply  — admin only (protected by ADMIN_SECRET_KEY)
# ---------------------------------------------------------------------------

class ReplyRequest(BaseModel):
    message_id: str
    reply_text: str
    admin_key: str


class DeleteMessagesRequest(BaseModel):
    ids: list[str]


@router.post("/reply")
async def admin_reply(payload: ReplyRequest):
    """
    Admin posts a reply to a support message.
    Requires ADMIN_SECRET_KEY in the request body.
    Updates DB status to 'replied' and emails the user.
    """
    if not settings.ADMIN_SECRET_KEY or payload.admin_key != settings.ADMIN_SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin key.",
        )

    # Fetch the message
    msg_result = (
        supabase_admin.table("support_messages")
        .select("*")
        .eq("id", payload.message_id)
        .execute()
    )
    if not msg_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Support message not found.",
        )

    message = msg_result.data[0]
    replied_at = datetime.now(timezone.utc).isoformat()

    # Update DB
    supabase_admin.table("support_messages").update({
        "admin_reply": payload.reply_text,
        "status":      "replied",
        "replied_at":  replied_at,
    }).eq("id", payload.message_id).execute()

    # Email user if we have their email
    user_email = message.get("user_email", "").strip()
    if user_email:
        html = _build_reply_email(message, payload.reply_text)
        await send_email(
            to=user_email,
            subject=f"Re: {message['subject']} — Travello AI Support",
            html=html,
        )
        logger.info("Reply email sent to %s for message %s", user_email, payload.message_id)

    return {"success": True, "message_id": payload.message_id}


# ---------------------------------------------------------------------------
# GET /support/reply-form  — admin opens this link from the notification email
# ---------------------------------------------------------------------------

@router.get("/reply-form", response_class=HTMLResponse)
async def reply_form(message_id: str, secret: str):
    """
    Serves an HTML reply form for the admin.
    Link is embedded in every support notification email.
    Validates the secret before showing any message content.
    """
    if not settings.ADMIN_SECRET_KEY or secret != settings.ADMIN_SECRET_KEY:
        return HTMLResponse(
            content="<h2 style='font-family:sans-serif;color:red'>❌ Invalid or missing admin key.</h2>",
            status_code=403,
        )

    msg_result = (
        supabase_admin.table("support_messages")
        .select("*")
        .eq("id", message_id)
        .execute()
    )
    if not msg_result.data:
        return HTMLResponse(
            content="<h2 style='font-family:sans-serif;color:red'>❌ Message not found.</h2>",
            status_code=404,
        )

    msg = msg_result.data[0]
    topic       = msg.get("topic", "")
    subject     = msg.get("subject", "")
    description = msg.get("description", "")
    user_email  = msg.get("user_email", "")
    current_status = msg.get("status", "pending")
    existing_reply = msg.get("admin_reply") or ""

    status_color = {"pending": "#d97706", "replied": "#16a34a", "closed": "#6b7280"}.get(current_status, "#888")

    base_url = settings.BACKEND_BASE_URL.rstrip("/")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reply to Support Message - Travello AI</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: #f0f2f5; min-height: 100vh; padding: 32px 16px; }}
    .card {{ background: #fff; border-radius: 16px; padding: 32px;
             max-width: 600px; margin: 0 auto;
             box-shadow: 0 4px 20px rgba(0,0,0,0.1); }}
    .logo {{ color: #C9A84C; font-size: 24px; font-weight: 800; margin-bottom: 4px; }}
    .subtitle {{ color: #888; font-size: 13px; margin-bottom: 24px; }}
    .meta {{ display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 20px; }}
    .meta-item label {{ font-size: 10px; font-weight: 700; color: #999;
                        text-transform: uppercase; letter-spacing: 0.6px; display: block; margin-bottom: 3px; }}
    .meta-item span {{ font-size: 14px; color: #222; font-weight: 500; }}
    .status-badge {{ display: inline-block; padding: 2px 10px; border-radius: 20px;
                     font-size: 12px; font-weight: 700; background: {status_color}22;
                     color: {status_color}; border: 1px solid {status_color}44; }}
    .section-label {{ font-size: 10px; font-weight: 700; color: #999;
                      text-transform: uppercase; letter-spacing: 0.6px; margin-bottom: 6px; }}
    .msg-box {{ background: #fafafa; border-left: 4px solid #C9A84C;
                border-radius: 6px; padding: 14px 16px; font-size: 14px;
                color: #444; line-height: 1.7; white-space: pre-wrap; margin-bottom: 20px; }}
    textarea {{ width: 100%; border: 1.5px solid #e5e7eb; border-radius: 10px;
                padding: 14px 16px; font-size: 14px; line-height: 1.7; resize: vertical;
                font-family: inherit; color: #222; outline: none; transition: border 0.2s; }}
    textarea:focus {{ border-color: #C9A84C; }}
    .btn {{ width: 100%; padding: 14px; background: #C9A84C; color: #fff;
            border: none; border-radius: 10px; font-size: 16px; font-weight: 700;
            cursor: pointer; margin-top: 16px; transition: background 0.2s; }}
    .btn:hover {{ background: #b8973d; }}
    .btn:disabled {{ background: #ccc; cursor: not-allowed; }}
    #result {{ margin-top: 14px; padding: 12px 16px; border-radius: 10px;
               font-size: 14px; font-weight: 600; display: none; }}
    .success {{ background: #f0fdf4; color: #16a34a; border: 1px solid #bbf7d0; }}
    .error   {{ background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }}
    .divider {{ border: none; border-top: 1px solid #f0f0f0; margin: 20px 0; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">Travello AI</div>
    <div class="subtitle">Admin Reply Panel</div>

    <div class="meta">
      <div class="meta-item">
        <label>Topic</label>
        <span>{topic}</span>
      </div>
      <div class="meta-item">
        <label>Status</label>
        <span class="status-badge">{current_status.capitalize()}</span>
      </div>
      <div class="meta-item" style="grid-column: 1 / -1;">
        <label>Subject</label>
        <span>{subject}</span>
      </div>
      <div class="meta-item" style="grid-column: 1 / -1;">
        <label>User Email</label>
        <span>{user_email or '—'}</span>
      </div>
    </div>

    <div class="section-label">User's Message</div>
    <div class="msg-box">{description}</div>

    <hr class="divider">

    <div class="section-label">Your Reply</div>
    <textarea id="replyText" rows="6" placeholder="Type your reply here…">{existing_reply}</textarea>

    <button class="btn" id="submitBtn" onclick="sendReply()">
      {'Update Reply' if existing_reply else 'Send Reply'}
    </button>

    <div id="result"></div>
  </div>

  <script>
    async function sendReply() {{
      const text = document.getElementById('replyText').value.trim();
      if (!text) {{ alert('Please enter a reply.'); return; }}

      const btn = document.getElementById('submitBtn');
      const result = document.getElementById('result');
      btn.disabled = true;
      btn.textContent = 'Sending…';
      result.style.display = 'none';

      try {{
        const res = await fetch('{base_url}/support/reply', {{
          method: 'POST',
          headers: {{ 'Content-Type': 'application/json' }},
          body: JSON.stringify({{
            message_id: '{message_id}',
            reply_text: text,
            admin_key: '{secret}'
          }})
        }});
        const data = await res.json();
        if (res.ok && data.success) {{
          result.className = 'success';
          result.textContent = '✅ Reply sent! The user has been notified by email and the app will show the reply.';
          btn.textContent = 'Reply Sent ✓';
        }} else {{
          throw new Error(data.detail || 'Unknown error');
        }}
      }} catch (e) {{
        result.className = 'error';
        result.textContent = '❌ Failed: ' + e.message;
        btn.disabled = false;
        btn.textContent = 'Retry';
      }}
      result.style.display = 'block';
    }}
  </script>
</body>
</html>"""

    return HTMLResponse(content=html)


# ---------------------------------------------------------------------------
# Email template — reply notification to user
# ---------------------------------------------------------------------------

def _build_reply_email(message: dict, reply_text: str) -> str:
    subject   = message.get("subject", "")
    topic     = message.get("topic", "")
    original  = message.get("description", "")

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body {{ font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 24px; }}
        .card {{ background: #fff; border-radius: 12px; padding: 28px 32px;
                 max-width: 560px; margin: 0 auto;
                 box-shadow: 0 2px 10px rgba(0,0,0,0.09); }}
        .logo {{ color: #C9A84C; font-size: 22px; font-weight: bold; margin-bottom: 4px; }}
        .badge {{ display: inline-block; background: #FFF8E7; color: #C9A84C;
                  border: 1px solid #E6C86A; border-radius: 20px;
                  padding: 4px 14px; font-size: 13px; font-weight: 600;
                  margin-bottom: 16px; }}
        .label {{ font-size: 11px; font-weight: 700; color: #999;
                  text-transform: uppercase; letter-spacing: 0.6px; margin-bottom: 4px; }}
        .reply-box {{ background: #F0FDF4; border-left: 4px solid #16a34a;
                      border-radius: 6px; padding: 16px 18px;
                      font-size: 14px; color: #15803d; line-height: 1.7;
                      white-space: pre-wrap; margin-top: 4px; }}
        .original-box {{ background: #FAFAFA; border-left: 4px solid #d1d5db;
                         border-radius: 6px; padding: 14px 18px;
                         font-size: 13px; color: #6b7280; line-height: 1.6;
                         white-space: pre-wrap; margin-top: 4px; }}
        .footer {{ color: #aaa; font-size: 12px; text-align: center; margin-top: 28px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">Travello AI</div>
        <p style="color:#777;font-size:13px;margin-top:2px;">Support team replied to your message</p>
        <div class="badge">&#9989; {topic}</div>

        <div class="label">Your Subject</div>
        <div style="font-size:15px;color:#222;margin-bottom:16px;">{subject}</div>

        <div class="label">Reply from Support Team</div>
        <div class="reply-box">{reply_text}</div>

        <div style="margin-top:20px;">
          <div class="label">Your Original Message</div>
          <div class="original-box">{original}</div>
        </div>

        <p style="font-size:13px;color:#555;margin-top:20px;">
          Open the <strong>Travello AI</strong> app and go to
          <strong>Updates → Messages</strong> to view this reply in the app.
        </p>

        <div class="footer">&copy; Travello AI &mdash; Support Team</div>
      </div>
    </body>
    </html>
    """
