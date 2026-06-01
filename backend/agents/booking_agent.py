from __future__ import annotations
# =============================================================================
# PURPOSE: Booking confirmation & execution layer for the multi-agent system.
#
#   - extract_booking_from_history : uses Gemini to pull booking intent from chat
#   - format_booking_summary       : formats summary + payment choice prompt
#   - present_booking_summary      : Gemini-formatted summary
#   - execute_booking              : creates booking + fires confirmation email
#   - handle_cancellation          : cancels booking + friendly message
# =============================================================================

import logging
from datetime import date, datetime
from typing import Any

from services.booking_service import create_booking, cancel_booking
from services.email_service import send_booking_confirmation
from services.llm_service import generate_text, generate_json, GeminiError
from prompts.booking import BOOKING_SYSTEM, BOOKING_CONFIRMATION_PROMPT

logger = logging.getLogger(__name__)

# ── Booking intent extraction ────────────────────────────────────────────────

_EXTRACTION_SYSTEM = """You are a booking data extractor for a Pakistan travel app.
Extract structured booking details from conversation history. Return ONLY valid JSON."""

_EXTRACTION_PROMPT = """The user wants to book something. Analyze the conversation and extract what they want to book.

Conversation (latest last):
{history}

User's booking request: "{user_message}"

Extract the SPECIFIC option the user selected (e.g. if they said "flight 1", find which flight was listed as #1).

Return JSON:
{{
  "booking_type": "flight | train | hotel | null",
  "origin": "city name or null",
  "destination": "city name or null",
  "travel_date": "YYYY-MM-DD or null",
  "departure_time": "HH:MM 24h format or null",
  "arrival_time": "HH:MM 24h format or null",
  "flight_number": "e.g. G9848, PK302, or null",
  "train_name": "e.g. Tezgam Express or null",
  "check_in": "YYYY-MM-DD or null",
  "check_out": "YYYY-MM-DD or null",
  "travelers": 1,
  "total_price_pkr": number or null,
  "selected_option": "brief description e.g. G9 Flight G9848 8:15 AM",
  "airline_or_train_name": "airline or train name or null",
  "hotel_name": "name or null",
  "confidence": 0.0 to 1.0
}}"""


async def extract_booking_from_history(
    user_message: str,
    conversation_history: list[dict],
) -> dict | None:
    """
    Use Gemini to extract what the user wants to book from conversation context.
    Returns a structured dict or None if intent is unclear (confidence < 0.5).
    """
    history_text = "\n".join(
        f"{m['role'].upper()}: {str(m.get('content', ''))[:600]}"
        for m in (conversation_history or [])[-12:]
    )

    messages = [
        {"role": "system", "content": _EXTRACTION_SYSTEM},
        {"role": "user", "content": _EXTRACTION_PROMPT.format(
            history=history_text,
            user_message=user_message,
        )},
    ]

    try:
        data = await generate_json(messages, temperature=0.1, max_output_tokens=512)
        if isinstance(data, dict) and float(data.get("confidence", 0)) >= 0.45:
            data.pop("confidence", None)
            return data
        return None
    except Exception as exc:
        logger.warning("extract_booking_from_history failed: %s", exc)
        return None


def format_booking_summary(booking_data: dict) -> str:
    """
    Build the booking summary message that includes the two payment-choice buttons
    as clearly labelled options the Flutter app will render as action buttons.
    """
    bt = booking_data.get("booking_type", "trip")
    price = booking_data.get("total_price_pkr")
    option = booking_data.get("selected_option", "your selected option")

    lines = ["**Booking Summary**\n"]

    if bt == "flight":
        lines.append(f"✈️  **Flight:** {booking_data.get('origin', '—')} → {booking_data.get('destination', '—')}")
        if booking_data.get("travel_date"):
            lines.append(f"📅  **Date:** {booking_data['travel_date']}")
        if booking_data.get("airline_or_train_name"):
            lines.append(f"🛫  **Airline:** {booking_data['airline_or_train_name']}")
    elif bt == "train":
        lines.append(f"🚂  **Train:** {booking_data.get('origin', '—')} → {booking_data.get('destination', '—')}")
        if booking_data.get("travel_date"):
            lines.append(f"📅  **Date:** {booking_data['travel_date']}")
        if booking_data.get("airline_or_train_name"):
            lines.append(f"🚆  **Train:** {booking_data['airline_or_train_name']}")
    elif bt == "hotel":
        lines.append(f"🏨  **Hotel:** {booking_data.get('hotel_name') or booking_data.get('destination', '—')}")
        if booking_data.get("check_in"):
            lines.append(f"📅  **Check-in:** {booking_data['check_in']}")
        if booking_data.get("check_out"):
            lines.append(f"📅  **Check-out:** {booking_data['check_out']}")
    else:
        lines.append(f"🧳  **Trip:** {option}")

    lines.append(f"👥  **Passengers:** {booking_data.get('travelers', 1)}")

    if price:
        lines.append(f"\n💰  **Total: PKR {int(price):,}**")
    else:
        lines.append("\n💰  **Total: As quoted above**")

    lines.append("\n\nHow would you like to pay?")
    lines.append("• **Pay with Card** — Proceed to the secure in-app payment screen")
    lines.append("• **Pay Later** — Save this booking and pay when you're ready")

    return "\n".join(lines)


# Public API

async def present_booking_summary(booking_details: dict[str, Any]) -> str:
    """
    Use Gemini to format a booking summary the user can review before paying.
    The response ends with the payment-preference question.
    Returns a plain-text fallback string if Gemini fails — never raises.
    """
    user_name  = booking_details.get("user_name")  or "there"
    user_email = booking_details.get("user_email") or "your email"

    prompt = BOOKING_CONFIRMATION_PROMPT.format(
        booking_details=booking_details,
        user_name=user_name,
        user_email=user_email,
    )

    payment_question = (
        "\n\nHow would you like to pay?\n"
        "  • **Pay with Card** — Proceed to the secure in-app payment screen\n"
        "  • **Pay Later** — Save this booking and pay when you're ready"
    )

    messages = [
        {"role": "system", "content": BOOKING_SYSTEM},
        {"role": "user", "content": prompt},
    ]

    try:
        summary = await generate_text(messages, temperature=0.3, max_output_tokens=768)
        return (summary.rstrip() + payment_question) if summary else _fallback_summary(booking_details, payment_question)
    except GeminiError as exc:
        logger.warning("booking_agent summary failed: %s", exc)
        return _fallback_summary(booking_details, payment_question)
    except Exception as exc:
        logger.warning("booking_agent summary unexpected error: %s", exc)
        return _fallback_summary(booking_details, payment_question)


async def execute_booking(
    user_id: str,
    booking_type: str,             # 'flight' | 'train' | 'hotel'
    contact_email: str,
    total_amount: float,
    raw_payload: dict,
    origin: str | None = None,
    destination: str | None = None,
    departure_at: datetime | None = None,
    arrival_at: datetime | None = None,
    hotel_name: str | None = None,
    check_in: date | None = None,
    check_out: date | None = None,
) -> dict[str, Any]:
    """
    DEPRECATED / UNUSED — do not call in the current flow.

    The live booking flow is: agent shows a payment_choice summary →
    Flutter calls POST /agent/book (creates a PENDING booking) → POST /payments/
    initiate completes payment and sends the confirmation email. This function
    instead creates a booking AND emails immediately (pre-payment), which would
    confirm an unpaid booking. Kept only for reference; no caller invokes it.

    Email-send failure is logged but does NOT roll back the booking.
    """
    booking = await create_booking(
        user_id=user_id,
        booking_type=booking_type,
        contact_email=contact_email,
        total_amount=total_amount,
        raw_payload=raw_payload,
        origin=origin,
        destination=destination,
        departure_at=departure_at,
        arrival_at=arrival_at,
        hotel_name=hotel_name,
        check_in=check_in,
        check_out=check_out,
    )

    try:
        await send_booking_confirmation(booking.id)
    except Exception as exc:
        logger.warning(
            "Booking %s created but confirmation email failed: %s",
            booking.booking_id, exc,
        )

    return {
        "pnr": booking.pnr,
        "booking_id": booking.booking_id,
        "status": booking.status,
        "total_amount": booking.total_amount,
    }


async def handle_cancellation(booking_uuid: str, user_id: str) -> str:
    """
    Cancel a booking and return a user-facing confirmation message.
    Returns a friendly error message on failure — never raises.
    """
    try:
        booking = await cancel_booking(booking_uuid, user_id)
    except Exception as exc:
        logger.warning("handle_cancellation failed for booking=%s: %s", booking_uuid, exc)
        return (
            "I couldn't cancel that booking. Please check the booking ID "
            "and try again, or contact support if the issue persists."
        )

    return (
        f"✅ Your booking **{booking.booking_id}** has been cancelled successfully. "
        f"If a refund applies, it will be processed within 5-7 business days "
        "and you'll receive a confirmation email shortly."
    )


# Internal helpers

def _fallback_summary(booking_details: dict[str, Any], payment_question: str) -> str:
    """Plain-text booking summary used when Gemini is unavailable."""
    lines = ["**Booking Summary**", ""]
    for k, v in booking_details.items():
        if v is None or k in ("user_name", "user_email"):
            continue
        label = k.replace("_", " ").title()
        lines.append(f"- {label}: {v}")
    lines.append("")
    lines.append("Please confirm to proceed with this booking, or let me know if you'd like to change anything.")
    return "\n".join(lines) + payment_question
