from __future__ import annotations
# PURPOSE: ONE consolidated confirmation email for a Trip Planner package.
#
# A package is several booking rows the traveller bought once. Sending each
# row's own confirmation lands three near-identical emails for a single trip,
# none of which states the real grand total or the shape of the journey. This
# renders the whole trip once instead: every component with its own reference,
# the money broken down, and a short narrative of the order things happen in.
#
# Everything here is copied from the component rows. Nothing is inferred — no
# activities, meals, facilities or timings the bookings don't actually carry.
# It lives beside email_service rather than inside it because it is keyed on a
# PACKAGE, not a booking, and reads its components through payment_service.

import logging
from datetime import datetime
from html import escape

from core.email import send_email

logger = logging.getLogger(__name__)


def _esc(value) -> str:
    return escape(str(value or ""))


def _nights_between(check_in, check_out) -> int:
    """Whole nights between two ISO dates, or 0 when either is missing."""
    try:
        start = datetime.fromisoformat(str(check_in)[:10])
        end = datetime.fromisoformat(str(check_out)[:10])
    except (TypeError, ValueError):
        return 0
    return max((end - start).days, 0)


def _transport_of(components: list[dict]) -> dict | None:
    return next(
        (c for c in components if (c.get("booking_type") or "") in ("flight", "train")),
        None,
    )


def _hotel_of(components: list[dict]) -> dict | None:
    return next((c for c in components if (c.get("booking_type") or "") == "hotel"), None)


def build_narrative(components: list[dict]) -> str:
    """
    A plain description of the trip, in the order it happens.

    Built ONLY from what the component bookings carry: the route actually
    booked, the transfer actually attached, the stay actually reserved. No
    sightseeing, no meals, no times that aren't in the data.
    """
    transport = _transport_of(components)
    hotel = _hotel_of(components)
    parts: list[str] = []

    if transport:
        mode = "flight" if transport.get("booking_type") == "flight" else "train"
        origin = str(transport.get("origin") or "").strip()
        destination = str(transport.get("destination") or "").strip()
        if origin and destination:
            parts.append(f"Your trip begins with your {mode} from {origin} to {destination}.")
        else:
            parts.append(f"Your trip begins with your {mode}.")

    raw = (transport or {}).get("raw_payload") or {}
    vehicle = str(raw.get("transferVehicleType") or "").strip()
    dropoff = str(raw.get("transferDropoffLocation") or "").strip()
    if vehicle and dropoff:
        hub = str((transport or {}).get("destination") or "").strip()
        from_part = f"from {hub} " if hub else ""
        parts.append(f"Your {vehicle} transfer will then take you {from_part}to {dropoff}.")

    if hotel:
        name = str(hotel.get("hotel_name") or "your hotel").strip()
        nights = _nights_between(hotel.get("check_in"), hotel.get("check_out"))
        if nights:
            parts.append(f"You'll stay at {name} for {nights} night{'s' if nights != 1 else ''}.")
        else:
            parts.append(f"You'll stay at {name}.")
    return " ".join(parts)


def build_html(package_id: str, components: list[dict]) -> str:
    """The consolidated package confirmation body."""
    blocks: list[str] = []
    money: list[tuple[str, float]] = []
    grand_total = 0.0

    for component in components:
        kind = str(component.get("booking_type") or "").lower()
        reference = _esc(component.get("pnr") or component.get("booking_id"))
        amount = float(component.get("total_amount") or 0)
        grand_total += amount
        raw = component.get("raw_payload") or {}

        if kind in ("flight", "train"):
            carrier = _esc(raw.get("flight_number") or raw.get("train_name") or kind.title())
            route = f"{_esc(component.get('origin'))} &rarr; {_esc(component.get('destination'))}"
            when = _esc(str(component.get("departure_at") or "").replace("T", " ")[:16])
            heading = "Flight" if kind == "flight" else "Train"
            blocks.append(
                f"<h3 style='margin:18px 0 6px'>{heading}</h3>"
                f"<p style='margin:0;line-height:1.6'>{carrier}<br>{route}<br>{when}<br>"
                f"<b>Reference:</b> {reference}</p>"
            )
            money.append((heading, amount))

            # The hub transfer rides on the transport booking's payload — it is
            # part of this package's price, not a separate booking.
            vehicle = _esc(raw.get("transferVehicleType"))
            if vehicle:
                pickup = _esc(raw.get("transferPickupLocation")) or "&mdash;"
                dropoff = _esc(raw.get("transferDropoffLocation")) or "&mdash;"
                blocks.append(
                    "<h3 style='margin:18px 0 6px'>Transfer</h3>"
                    f"<p style='margin:0;line-height:1.6'>{vehicle}<br>"
                    f"<b>Pickup:</b> {pickup}<br><b>Drop-off:</b> {dropoff}</p>"
                )
        elif kind == "hotel":
            nights = _nights_between(component.get("check_in"), component.get("check_out"))
            stars = raw.get("hotel_stars")
            star_line = (
                f"{int(stars)} star<br>" if isinstance(stars, (int, float)) and stars else ""
            )
            breakfast = "Breakfast included<br>" if raw.get("breakfast_included") else ""
            blocks.append(
                "<h3 style='margin:18px 0 6px'>Hotel</h3>"
                f"<p style='margin:0;line-height:1.6'>{_esc(component.get('hotel_name'))}<br>"
                f"{star_line}{nights} night{'s' if nights != 1 else ''}<br>{breakfast}"
                f"<b>Reference:</b> {reference}</p>"
            )
            money.append(("Hotel", amount))

    breakdown = "".join(
        f"<tr><td style='padding:4px 0'>{_esc(label)}</td>"
        f"<td style='padding:4px 0;text-align:right'>PKR {value:,.0f}</td></tr>"
        for label, value in money
    )
    hotel = _hotel_of(components)
    destination = _esc((hotel or {}).get("destination") or (hotel or {}).get("hotel_name"))
    destination_line = f"<br><b>Destination:</b> {destination}" if destination else ""

    return f"""
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:620px;margin:0 auto;color:#1a1a1a">
      <h2 style="margin:0 0 4px">Trip Package Confirmed</h2>
      <p style="margin:0 0 16px;color:#666">
        <b>Package Reference:</b> {_esc(package_id)}{destination_line}
      </p>
      <p style="margin:0 0 16px;padding:12px;background:#f6f6f6;border-radius:6px">
        {_esc(build_narrative(components))}
      </p>
      {''.join(blocks)}
      <h3 style="margin:22px 0 6px">Payment</h3>
      <table style="width:100%;border-collapse:collapse">
        {breakdown}
        <tr><td style="padding:8px 0;border-top:1px solid #ddd"><b>Grand Total</b></td>
            <td style="padding:8px 0;border-top:1px solid #ddd;text-align:right">
              <b>PKR {grand_total:,.0f}</b></td></tr>
        <tr><td style="padding:4px 0">Payment status</td>
            <td style="padding:4px 0;text-align:right">Confirmed</td></tr>
      </table>
      <p style="margin:22px 0 0;color:#888;font-size:12px">
        This is one trip package. The references above identify each part of it.
      </p>
    </div>
    """


async def send_package_confirmation(package_id: str, user_id: str) -> dict:
    """
    ONE confirmation email for a whole Trip Planner package.

    Replaces — never accompanies — the per-component confirmations: the
    payments router calls this INSTEAD of send_booking_confirmation whenever a
    payment carries a package_id, which is what keeps a package to exactly one
    email while standalone bookings keep theirs unchanged.
    """
    # Imported here rather than at module scope: payment_service imports the
    # email layer for the standalone path, and a top-level import both ways
    # would be circular.
    from services.payment_service import get_package_components

    components = await get_package_components(package_id, user_id)
    if not components:
        logger.error("send_package_confirmation: package %s has no components", package_id)
        return {"sent": False, "reason": "package_not_found"}

    contact_email = next(
        (c.get("contact_email") for c in components if c.get("contact_email")), None
    )
    if not contact_email:
        logger.error("send_package_confirmation: package %s has no contact email", package_id)
        return {"sent": False, "reason": "no_contact_email"}

    result = await send_email(
        to=contact_email,
        subject=f"Trip Package Confirmed - {package_id}",
        html=build_html(package_id, components),
    )
    sent = result.get("id") not in ("disabled", "failed", "skipped", None)
    return {
        "sent": sent,
        "to": contact_email,
        "package_id": package_id,
        "components": len(components),
    }
