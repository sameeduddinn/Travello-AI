from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import Response
from pydantic import BaseModel

from core.auth import CurrentUser
from core.supabase_client import supabase_admin
from agents.master_agent import process_message_agentic
from agents.memory_agent import start_new_conversation
from services.booking_service import create_booking
from services.weather_service import get_weather
from services.llm_service import generate_text

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/agent", tags=["AI Agent"])


# Pydantic models

class ChatRequest(BaseModel):
    message: str
    conversation_id: str | None = None


class AgentBookRequest(BaseModel):
    booking_type: str          # flight | train | hotel
    conversation_id: str
    origin: str | None = None
    destination: str | None = None
    travel_date: str | None = None
    departure_time: str | None = None   # HH:MM — e.g. "08:15"
    arrival_time: str | None = None     # HH:MM — e.g. "10:00"
    flight_number: str | None = None    # e.g. "G9848"
    train_name: str | None = None       # e.g. "Tezgam Express"
    check_in: str | None = None
    check_out: str | None = None
    travelers: int = 1
    total_amount: float = 0.0
    hotel_name: str | None = None
    passenger_name: str | None = None
    description: str = "Agent-initiated booking"


class AgentBookResponse(BaseModel):
    booking_id: str
    pnr: str
    total_amount: float
    status: str


class ChatResponse(BaseModel):
    response: str
    conversation_id: str
    action: str | None = None
    booking_data: dict | None = None


# Helpers — wrap sync Supabase calls in to_thread

def _count_today_messages(user_id: str, today_midnight: str) -> int:
    result = (
        supabase_admin.table("ai_messages")
        .select("id")
        .eq("user_id", user_id)
        .eq("role", "user")
        .gte("created_at", today_midnight)
        .limit(51)          # only need to know if >= 50; never loads unbounded rows
        .execute()
    )
    return len(result.data or [])


def _get_conversations(user_id: str):
    return (
        supabase_admin.table("ai_conversations")
        .select("id, title, is_active, created_at, updated_at")
        .eq("user_id", user_id)
        .eq("is_active", True)
        .order("updated_at", desc=True)
        .execute()
    )


def _verify_conversation_owner(conversation_id: str, user_id: str):
    return (
        supabase_admin.table("ai_conversations")
        .select("id")
        .eq("id", conversation_id)
        .eq("user_id", user_id)
        .execute()
    )


def _get_messages(conversation_id: str):
    return (
        supabase_admin.table("ai_messages")
        .select("id, role, content, message_type, created_at")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)
        .execute()
    )


def _soft_delete_conversation(conversation_id: str, user_id: str):
    return (
        supabase_admin.table("ai_conversations")
        .update({"is_active": False})
        .eq("id", conversation_id)
        .eq("user_id", user_id)
        .execute()
    )


# Endpoints

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, user: CurrentUser):
    """
    Send a message to the AI agent and receive a response.
    Enforces a daily limit of 50 user messages per account.
    """
    # Rate-limit check
    today_midnight = (
        datetime.now(timezone.utc)
        .replace(hour=0, minute=0, second=0, microsecond=0)
        .isoformat()
    )
    count = await asyncio.to_thread(_count_today_messages, user.id, today_midnight)
    if count >= 50:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily message limit of 50 reached. Try again tomorrow.",
        )

    # Resolve or create conversation
    if not request.conversation_id:
        conversation_id = await start_new_conversation(
            user.id, title=request.message[:50]
        )
    else:
        # Verify the conversation belongs to this user before trusting it.
        # supabase_admin bypasses RLS, so we must enforce ownership here.
        conv = await asyncio.to_thread(
            _verify_conversation_owner, request.conversation_id, user.id
        )
        if not conv.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Conversation not found.",
            )
        conversation_id = request.conversation_id

    try:
        result = await asyncio.wait_for(
            process_message_agentic(user.id, conversation_id, request.message),
            timeout=60.0,
        )
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="The AI agent took too long to respond. Please try again.",
        )
    return ChatResponse(
        response=result["response"],
        conversation_id=result["conversation_id"],
        action=result.get("action"),
        booking_data=result.get("booking_data"),
    )


@router.get("/conversations")
async def list_conversations(user: CurrentUser):
    """Return all active conversations for the current user, newest first."""
    result = await asyncio.to_thread(_get_conversations, user.id)
    return result.data or []


@router.get("/conversations/{conversation_id}/messages")
async def get_messages(conversation_id: str, user: CurrentUser):
    """Return all messages in a conversation (ownership verified)."""
    conv = await asyncio.to_thread(_verify_conversation_owner, conversation_id, user.id)
    if not conv.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )
    result = await asyncio.to_thread(_get_messages, conversation_id)
    return result.data or []


@router.delete("/conversations/{conversation_id}", status_code=204)
async def delete_conversation(conversation_id: str, user: CurrentUser):
    """Soft-delete a conversation (sets is_active = false)."""
    conv = await asyncio.to_thread(_verify_conversation_owner, conversation_id, user.id)
    if not conv.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )
    await asyncio.to_thread(_soft_delete_conversation, conversation_id, user.id)
    return Response(status_code=204)


@router.post("/book", response_model=AgentBookResponse, status_code=status.HTTP_201_CREATED)
async def agent_book(payload: AgentBookRequest, user: CurrentUser):
    """
    Create a booking initiated by the AI agent conversation.

    Called by Flutter after the user chooses 'Pay with Card' in the agent chat.
    Creates the booking record in pending state — Flutter then calls
    POST /payments/initiate to complete payment.
    """
    from datetime import datetime as dt

    def _parse_date(s: str | None):
        if not s:
            return None
        try:
            return dt.strptime(s, "%Y-%m-%d").date()
        except ValueError:
            return None

    def _parse_datetime(s: str | None):
        if not s:
            return None
        try:
            return dt.strptime(s, "%Y-%m-%d")
        except ValueError:
            return None

    # Fetch user profile (full name) from profiles table
    def _get_profile():
        try:
            # profiles columns: full_name, phone, avatar_url — NOT cnic/name/email
            r = supabase_admin.table("profiles").select("full_name").eq("id", user.id).single().execute()
            d = r.data or {}
            name = d.get("full_name") or payload.passenger_name or ""
            return user.email or "", name
        except Exception:
            return user.email or "", payload.passenger_name or ""

    contact_email, passenger_name = await asyncio.to_thread(_get_profile)

    # Build the actual departure datetime from date + time components
    departure_at = None
    arrival_at = None
    if payload.travel_date:
        base_date = _parse_date(payload.travel_date)
        if base_date:
            if payload.departure_time:
                try:
                    h, m = [int(x) for x in payload.departure_time.split(":")]
                    departure_at = dt(base_date.year, base_date.month, base_date.day, h, m)
                except Exception:
                    departure_at = dt(base_date.year, base_date.month, base_date.day, 0, 0)
            else:
                departure_at = dt(base_date.year, base_date.month, base_date.day, 0, 0)

            if payload.arrival_time:
                try:
                    h, m = [int(x) for x in payload.arrival_time.split(":")]
                    arrival_at = dt(base_date.year, base_date.month, base_date.day, h, m)
                except Exception:
                    pass

    raw_payload = {
        "agent_initiated": True,
        "conversation_id": payload.conversation_id,
        "description": payload.description,
        "travelers": payload.travelers,
        "flight_number": payload.flight_number,
        "train_name": payload.train_name,
        "passenger_name": passenger_name,
    }

    booking = await create_booking(
        user_id=user.id,
        booking_type=payload.booking_type,
        contact_email=contact_email,
        total_amount=payload.total_amount,
        raw_payload=raw_payload,
        origin=payload.origin,
        destination=payload.destination,
        departure_at=departure_at,
        arrival_at=arrival_at,
        hotel_name=payload.hotel_name,
        check_in=_parse_date(payload.check_in),
        check_out=_parse_date(payload.check_out),
    )

    return AgentBookResponse(
        booking_id=str(booking.id),
        pnr=booking.pnr or "",
        total_amount=float(booking.total_amount),
        status=booking.status,
    )


@router.get("/proactive-alert")
async def proactive_alert(user: CurrentUser):
    """
    Returns a proactive AI message if the user has an upcoming trip within 7 days.
    Flutter calls this once when the AI screen opens on a fresh session.
    Returns {"alert": "message"} or {"alert": null}.
    """
    from datetime import datetime, timezone, timedelta

    now = datetime.now(timezone.utc)
    window_end = (now + timedelta(days=7)).isoformat()

    def _fetch_upcoming():
        return (
            supabase_admin.table("bookings")
            .select("booking_id, pnr, booking_type, origin, destination, departure_at, status")
            .eq("user_id", user.id)
            .in_("status", ["paid", "confirmed"])
            .gte("departure_at", now.isoformat())
            .lte("departure_at", window_end)
            .order("departure_at", desc=False)
            .limit(1)
            .execute()
        )

    try:
        result = await asyncio.to_thread(_fetch_upcoming)
        bookings = result.data or []
    except Exception:
        return {"alert": None}

    if not bookings:
        return {"alert": None}

    trip = bookings[0]
    destination = trip.get("destination") or trip.get("origin") or ""
    dep_raw = trip.get("departure_at") or ""
    booking_type = trip.get("booking_type", "trip")
    pnr = trip.get("pnr") or trip.get("booking_id") or ""

    # Parse departure date for human-readable format
    days_away = 0
    dep_label = ""
    try:
        dep_dt = datetime.fromisoformat(dep_raw.replace("Z", "+00:00"))
        delta = dep_dt - now
        days_away = max(0, delta.days)
        dep_label = dep_dt.strftime("%-d %B")  # e.g. "15 June"
    except Exception:
        dep_label = dep_raw[:10]

    # Fetch live weather for the destination
    weather_summary = ""
    try:
        city = destination.split("(")[0].strip()   # strip IATA code if present
        weather_data = await get_weather(city)
        temp = weather_data.get("temperature_current") or weather_data.get("temperature")
        condition = weather_data.get("condition") or weather_data.get("description") or ""
        if temp:
            weather_summary = f"Current weather: {temp}°C, {condition}."
    except Exception:
        pass

    # Generate personalized message via Gemini
    days_text = "today" if days_away == 0 else f"in {days_away} day{'s' if days_away != 1 else ''}"
    context = (
        f"The user has an upcoming {booking_type} trip to {destination} departing {days_text} ({dep_label}). "
        f"Booking reference: {pnr}. {weather_summary} "
        "Write a short, warm, proactive travel tip message (2-3 sentences max). "
        "Include the destination and departure info. Mention 1 practical travel tip. "
        "End with an encouraging line. Use relevant emoji. No markdown headers."
    )

    try:
        alert = await generate_text(
            [{"role": "user", "content": context}],
            temperature=0.7,
            max_output_tokens=200,
        )
    except Exception:
        # Fallback without Gemini
        alert = (
            f"🗺️ Your trip to {destination} is {days_text}! "
            f"{weather_summary} "
            "Double-check your documents and have a wonderful journey! ✈️"
        )

    return {"alert": alert.strip() if alert else None}
