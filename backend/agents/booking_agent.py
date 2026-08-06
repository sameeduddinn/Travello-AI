from __future__ import annotations
# =============================================================================
# PURPOSE: Booking confirmation & execution layer for the multi-agent system.
#
#   - extract_booking_from_history : uses Gemini to pull booking intent from chat
#   - format_booking_summary       : formats summary + payment choice prompt
#   - present_booking_summary      : Gemini-formatted summary
#   - handle_cancellation          : cancels booking + friendly message
#
# NOTE: the live booking flow is agent summary -> POST /agent/book (pending) ->
# POST /payments/initiate (pays + emails). There is intentionally NO function
# here that creates a booking and emails before payment.

import logging
import re
from datetime import date
from typing import Any

from services.booking_service import cancel_booking
from services.llm_service import generate_text, generate_json, GeminiError
from prompts.booking import BOOKING_SYSTEM, BOOKING_CONFIRMATION_PROMPT

logger = logging.getLogger(__name__)


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
    Returns a structured dict or None if intent is unclear (confidence < 0.45).
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


def _as_int(value, default: int = 0) -> int:
    """Best-effort int for a display-only field — never raises."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _as_float(value: Any, default: float | None = None) -> float | None:
    """Best-effort float for a display-only field — never raises."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _stay_nights(check_in, check_out) -> int:
    """Nights between two YYYY-MM-DD strings, or 0 if either is unusable."""
    try:
        ci = date.fromisoformat(str(check_in))
        co = date.fromisoformat(str(check_out))
    except (TypeError, ValueError):
        return 0
    return max((co - ci).days, 0)


def _price_breakdown(bd: dict) -> str | None:
    total = _as_float(bd.get("total_price_pkr"))
    if total is None or total <= 0:
        return None

    # A car transfer is a flat add-on already inside the total and is NOT
    # charged per traveler, so take it out before dividing.
    transfer = _as_float(bd.get("transfer_pkr"), 0.0) or 0.0
    base = round(total - transfer)
    if base <= 0:
        return None

    if bd.get("booking_type") == "hotel":
        nights = _stay_nights(bd.get("check_in"), bd.get("check_out"))
        rooms = max(_as_int(bd.get("rooms"), 1), 1)
        units = nights * rooms
        if units <= 1:
            return None
        per = round(base / units)
        if per * units != base:
            return None
        parts = [f"PKR {per:,}/night", f"{nights} night(s)"]
        if rooms > 1:
            parts.append(f"{rooms} rooms")
        return " × ".join(parts)

    pax = _as_int(bd.get("travelers"), 0) or (
        _as_int(bd.get("adults"), 0)
        + _as_int(bd.get("children"), 0)
        + _as_int(bd.get("infants"), 0)
    )
    if pax <= 1:
        return None
    per = round(base / pax)
    if per * pax != base:
        return None
    return f"PKR {per:,} per person × {pax} passengers"


def format_booking_summary(booking_data: dict) -> str:
    """
    Build the booking summary message that includes the two payment-choice buttons
    as clearly labelled options the Flutter app will render as action buttons.
    """
    booking_data = booking_data if isinstance(booking_data, dict) else {}
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
        # The class sets the fare — show it so the user can verify what they're
        # paying for. cabin_class is stored uppercase ("ECONOMY"); title-case it.
        if booking_data.get("cabin_class"):
            lines.append(f"💺  **Class:** {str(booking_data['cabin_class']).title()}")
    elif bt == "train":
        lines.append(f"🚂  **Train:** {booking_data.get('origin', '—')} → {booking_data.get('destination', '—')}")
        if booking_data.get("travel_date"):
            lines.append(f"📅  **Date:** {booking_data['travel_date']}")
        if booking_data.get("airline_or_train_name"):
            lines.append(f"🚆  **Train:** {booking_data['airline_or_train_name']}")
        # train_class drives the price (Economy vs AC Standard vs AC Business),
        # so the summary must state which one — it's already a display label.
        if booking_data.get("train_class"):
            lines.append(f"💺  **Class:** {booking_data['train_class']}")
    elif bt == "hotel":
        lines.append(f"🏨  **Hotel:** {booking_data.get('hotel_name') or booking_data.get('destination', '—')}")
        if booking_data.get("check_in"):
            lines.append(f"📅  **Check-in:** {booking_data['check_in']}")
        if booking_data.get("check_out"):
            lines.append(f"📅  **Check-out:** {booking_data['check_out']}")
    else:
        lines.append(f"🧳  **Trip:** {option}")

    if bt == "hotel":
        guests = booking_data.get("guests") or booking_data.get("travelers", 1)
        rooms = booking_data.get("rooms", 1)
        lines.append(f"👥  **Guests:** {guests}  ·  **Rooms:** {rooms}")
        if booking_data.get("room_type"):
            lines.append(f"🛏️  **Room type:** {booking_data['room_type']}")
    else:
        adults = booking_data.get("adults")
        if adults:
            parts = [f"{adults} adult(s)"]
            if booking_data.get("children"):
                parts.append(f"{booking_data['children']} child(ren)")
            if booking_data.get("infants"):
                parts.append(f"{booking_data['infants']} infant(s)")
            lines.append(f"👥  **Passengers:** {', '.join(parts)}")
        else:
            lines.append(f"👥  **Passengers:** {booking_data.get('travelers', 1)}")

    if booking_data.get("transfer_vehicle_type"):
        pickup = booking_data.get("transfer_pickup_location") or "pickup to be confirmed"
        dropoff = booking_data.get("transfer_dropoff_location")
        route = f"{pickup} → {dropoff}" if dropoff else pickup
        # transfer_pkr is set by _add_transfer_fare during repricing and is already
        # inside the total below — show it so the total adds up on screen.
        fare = booking_data.get("transfer_pkr")
        fare_part = f" (PKR {int(fare):,})" if fare else ""
        lines.append(
            f"🚗  **Car transfer:** {booking_data['transfer_vehicle_type']}{fare_part} — {route}"
        )

    if price:
        # Show HOW the total was reached whenever it covers more than one seat
        # or night — the bare total alone read as if the party size had been
        # ignored, even though it never was.
        breakdown = _price_breakdown(booking_data)
        suffix = f"  _({breakdown})_" if breakdown else ""
        lines.append(f"\n💰  **Total: PKR {int(price):,}**{suffix}")
    else:
        lines.append("\n💰  **Total: As quoted above**")

    lines.append("\n\nNext, tap **Add Passenger Details** to fill in traveler information "
                 "on a secure form — then choose how to pay:")
    lines.append("• **Pay with Card** — Proceed to the secure in-app payment screen")
    lines.append("• **Pay Later** — Save this booking and pay when you're ready")

    # Multi-part trips only. The model's own prose is discarded on the booking
    # turn (the app renders THIS summary instead), and no chat turn happens
    # during passenger-details/payment — so without this line a package would
    # silently dead-end after its first piece.
    nxt = sanitize_next_step(booking_data.get("next_step"))
    if nxt:
        lines.append(f"\n\n➡️  **After this:** {nxt}")

    return "\n".join(lines)


_COMPONENT_LABELS = {
    "flight": ("✈️", "Flight"),
    "train": ("🚂", "Train"),
    "hotel": ("🏨", "Hotel"),
}


def build_package_data(components: list[dict]) -> dict:
    """
    Bundle 2+ already-repriced booking components into one package payload.

    Every component in `components` has ALREADY been through the same required-field,
    party-size, date and transfer gates as a single booking, and had its price
    re-derived server-side by reprice_booking. So the package total here is a sum of
    server-verified numbers — it is never a figure the model produced, which is what
    lets a single payment cover the whole package safely.

    The per-component dicts are passed through untouched so the app can commit each
    one through the existing /agent/book + /passengers + /payments/initiate path.
    """
    if not isinstance(components, (list, tuple)):
        components = []
    safe = [c for c in components if isinstance(c, dict)]
    total = 0.0
    for c in safe:
        try:
            price = float(c.get("total_price_pkr") or 0)
        except (TypeError, ValueError):
            continue
        # A NaN/inf price would survive float() and then blow up in round() —
        # this figure is what a single payment charges, so a non-finite value is
        # dropped rather than allowed anywhere near a total.
        if price != price or price in (float("inf"), float("-inf")):
            continue
        total += price
    return {
        "booking_type": "package",
        "components": safe,
        "total_price_pkr": round(total),
        "component_count": len(safe),
    }


def _component_line(index: int, component: dict) -> str:
    """One '1. ✈️ Flight: Lahore → Islamabad — PKR 24,974' row."""
    bt = component.get("booking_type", "trip")
    icon, label = _COMPONENT_LABELS.get(bt, ("🧳", "Trip"))
    if bt == "hotel":
        where = component.get("hotel_name") or component.get("destination") or "—"
        detail = f"{where}"
        if component.get("check_in") and component.get("check_out"):
            detail += f", {component['check_in']} → {component['check_out']}"
    else:
        detail = f"{component.get('origin', '—')} → {component.get('destination', '—')}"
        if component.get("travel_date"):
            detail += f", {component['travel_date']}"
    price = component.get("total_price_pkr")
    money = f"PKR {int(price):,}" if price else "as quoted"
    # Same reason as format_booking_summary: a package line showing only the
    # multiplied total looks like the party size was never applied.
    breakdown = _price_breakdown(component) if price else None
    tail = f"  _({breakdown})_" if breakdown else ""
    return f"{index}. {icon}  **{label}:** {detail} — **{money}**{tail}"


def format_package_summary(package_data: dict) -> str:
    """
    Build the package summary the app renders above ONE passenger form and ONE
    payment button. Deliberately mirrors format_booking_summary's shape so the
    chat reads consistently, but states the combined total and makes it explicit
    that passenger details and payment are collected once for everything.
    """
    package_data = package_data if isinstance(package_data, dict) else {}
    components = package_data.get("components") or []
    total = package_data.get("total_price_pkr")

    lines = ["**Your Package**\n"]
    for i, component in enumerate(components, start=1):
        lines.append(_component_line(i, component))

    # A car transfer rides along on whichever component carries it, and its fare is
    # already inside that component's repriced total — surface it so the sum adds up.
    for component in components:
        if component.get("transfer_vehicle_type"):
            pickup = component.get("transfer_pickup_location") or "pickup to be confirmed"
            dropoff = component.get("transfer_dropoff_location")
            route = f"{pickup} → {dropoff}" if dropoff else pickup
            fare = component.get("transfer_pkr")
            fare_part = f" (PKR {int(fare):,})" if fare else ""
            lines.append(
                f"🚗  **Car transfer:** {component['transfer_vehicle_type']}"
                f"{fare_part} — {route}"
            )
            break

    if total:
        lines.append(f"\n💰  **Package total: PKR {int(total):,}**")
    else:
        lines.append("\n💰  **Package total: As quoted above**")

    lines.append(
        "\n\nEverything above is booked together. Tap **Add Passenger Details** once "
        "— the same travelers are used for every part — then choose how to pay:"
    )
    lines.append("• **Pay for Package** — one payment covers all of the above")
    lines.append("• **Pay Later** — save the whole package and pay when you're ready")

    return "\n".join(lines)


# Anything a model writes that reaches the user unedited needs a deterministic
# gate. next_step is descriptive only — it must never carry a reference number or
# imply this booking is already done.
_NEXT_STEP_BANNED = re.compile(
    r"\b(pnr|booking reference|reference number|confirmation number|confirmed|"
    r"booked|paid|ticket number)\b",
    re.IGNORECASE,
)


def sanitize_next_step(raw) -> str:
    """
    Return a safe one-line 'what's left in this trip' hint, or '' to drop it.

    Dropped entirely if it claims a booking is confirmed or carries any kind of
    reference number — a fabricated PNR is the one thing this surface must never
    be able to print, and the prompt asking nicely is not a guarantee.
    """
    if not isinstance(raw, str):
        return ""
    # Collapse to a single line so it can't fake headings or extra card sections.
    text = " ".join(raw.split()).strip()
    if not text or _NEXT_STEP_BANNED.search(text):
        return ""
    return text[:160].rstrip()


def format_car_booking_summary(car_data: dict) -> str:
    """
    Build the standalone-car summary that precedes the single confirm button the
    Flutter app renders (action: car_booking_choice). Unlike the flight/train/
    hotel summary there is no payment step — the driver is assigned instantly on
    the user's confirm tap, matching the manual Car-tab flow.
    """
    vehicle = car_data.get("vehicle_type", "Car")
    price = car_data.get("price_pkr")

    lines = ["**Car Booking Summary**\n"]
    lines.append(f"🚗  **Vehicle:** {vehicle}")
    lines.append(f"📍  **Pickup:** {car_data.get('pickup_location', '—')}")
    lines.append(f"🏁  **Drop-off:** {car_data.get('dropoff_location', '—')}")
    if car_data.get("pickup_datetime"):
        lines.append(f"🕒  **Pickup time:** {car_data['pickup_datetime']}")
    if price:
        lines.append(f"\n💰  **Fare: PKR {int(price):,}**  (paid to the driver — no card needed)")

    lines.append("\n\nTap **Confirm Car Booking** to assign a driver — you'll get the "
                 "driver's details and a verification code right after.")

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
