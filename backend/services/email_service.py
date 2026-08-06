# =============================================================================
# PURPOSE: Booking confirmation email templates and dispatch logic.
#          Called after payment is verified to send a rich HTML email to the
#          user's contact_email address.
#
# Uses core.email.send_email() which sends via Gmail SMTP.
# =============================================================================

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from core.email import send_email
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)


# Fetch booking + passengers for email rendering

async def _fetch_booking_data(booking_uuid: str) -> dict[str, Any] | None:
    """Load a booking row with its passengers from Supabase (admin client).
    Returns None on error instead of raising."""
    try:
        booking_res = (
            supabase_admin.table("bookings")
            .select("*")
            .eq("id", booking_uuid)
            .single()
            .execute()
        )
    except Exception as exc:
        logger.error("_fetch_booking_data error for %s: %s", booking_uuid, exc)
        return None

    if not booking_res.data:
        logger.error("Booking %s not found for email", booking_uuid)
        return None

    booking = booking_res.data

    try:
        passengers_res = (
            supabase_admin.table("passengers")
            .select("*")
            .eq("booking_id", booking_uuid)
            .execute()
        )
        booking["passengers"] = passengers_res.data or []
    except Exception as exc:
        logger.warning("Could not fetch passengers for %s: %s", booking_uuid, exc)
        booking["passengers"] = []

    return booking


# Template helpers

_BRAND_COLOR = "#B09407FF"
_BRAND_DARK  = "#f9fb87"

_BASE_STYLE = """
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Helvetica Neue', Arial, sans-serif;
         background: #f0f4f8; color: #222; }
  .wrapper { max-width: 620px; margin: 30px auto; background: #fff;
             border-radius: 16px; overflow: hidden;
             box-shadow: 0 4px 20px rgba(0,0,0,0.10); }
  .header { background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%);
            padding: 32px 40px; }
  .header h1 { color: #fff; font-size: 26px; font-weight: 700; }
  .header p  { color: rgba(255,255,255,0.85); font-size: 14px; margin-top: 4px; }
  .body { padding: 32px 40px; }
  .section { margin-bottom: 28px; }
  .section-title { font-size: 13px; font-weight: 700; color: #1a73e8;
                   text-transform: uppercase; letter-spacing: 1px;
                   border-bottom: 2px solid #e8f0fe; padding-bottom: 6px;
                   margin-bottom: 14px; }
  .info-row { display: flex; justify-content: space-between; padding: 6px 0;
              font-size: 14px; border-bottom: 1px solid #f5f5f5; }
  .info-row .label { color: #666; }
  .info-row .value { font-weight: 600; color: #222; text-align: right; }
  .pnr-box { background: #e8f0fe; border: 2px dashed #1a73e8; border-radius: 10px;
             text-align: center; padding: 20px; margin: 20px 0; }
  .pnr-box .pnr-label { font-size: 12px; color: #555; text-transform: uppercase;
                         letter-spacing: 2px; }
  .pnr-box .pnr-value { font-size: 36px; font-weight: 800; color: #1a73e8;
                         letter-spacing: 8px; font-family: monospace; margin-top: 4px; }
  .passenger-card { background: #fafafa; border-radius: 8px; padding: 12px 16px;
                    margin-bottom: 10px; border-left: 4px solid #1a73e8; }
  .status-badge { display: inline-block; background: #34a853; color: #fff;
                  font-size: 12px; font-weight: 700; padding: 4px 12px;
                  border-radius: 20px; text-transform: uppercase; letter-spacing: 1px; }
  .status-badge-cancelled { display: inline-block; background: #d93025; color: #fff;
                  font-size: 12px; font-weight: 700; padding: 4px 12px;
                  border-radius: 20px; text-transform: uppercase; letter-spacing: 1px; }
  .amount-total { font-size: 28px; font-weight: 800; color: #1a73e8; }
  .footer { background: #f8f9fa; padding: 24px 40px; text-align: center;
            color: #888; font-size: 12px; border-top: 1px solid #eee; }
  .footer a { color: #1a73e8; text-decoration: none; }
  @media (max-width: 600px) {
    .body, .header, .footer { padding: 20px; }
  }
</style>
"""


def _fmt_dt(val: Any) -> str:
    if not val:
        return "—"
    if isinstance(val, datetime):
        return val.strftime("%d %b %Y, %I:%M %p")
    try:
        return datetime.fromisoformat(str(val)).strftime("%d %b %Y, %I:%M %p")
    except Exception:
        return str(val)


def _fmt_date(val: Any) -> str:
    if not val:
        return "—"
    try:
        from datetime import date
        if isinstance(val, date):
            return val.strftime("%d %b %Y")
        return str(val)[:10]
    except Exception:
        return str(val)


def _fmt_amount(amount: Any, currency: str = "PKR") -> str:
    try:
        return f"{currency} {float(amount):,.0f}"
    except Exception:
        return f"{currency} {amount}"


def _passenger_cards_html(passengers: list[dict]) -> str:
    if not passengers:
        return "<p style='color:#888;font-size:13px'>No passenger details recorded.</p>"
    cards = []
    for i, p in enumerate(passengers, 1):
        # Join only the parts that are actually present. `.get(k, "")` is not
        # enough: a stored-but-null title comes back as None, and an f-string
        # would render it literally as "None Firstname Lastname".
        name = " ".join(
            part for part in (
                (p.get("title") or "").strip(),
                (p.get("first_name") or "").strip(),
                (p.get("last_name") or "").strip(),
            ) if part
        ) or "—"
        ptype = p.get("passenger_type", "adult").title()
        seat = p.get("seat_number") or "To be assigned"
        cnic = p.get("cnic") or p.get("passport_number") or "—"
        cards.append(f"""
        <div class="passenger-card">
          <strong>Passenger {i}: {name}</strong> &nbsp;
          <span style="font-size:12px;color:#666">({ptype})</span><br>
          <span style="font-size:13px;color:#555">Seat: {seat} &nbsp;|&nbsp; ID: {cnic}</span>
        </div>""")
    return "".join(cards)


# Email templates

def _flight_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    origin = b.get("origin", "—")
    destination = b.get("destination", "—")
    dep = _fmt_dt(b.get("departure_at"))
    arr = _fmt_dt(b.get("arrival_at"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    passengers = b.get("passengers", [])
    # Cabin class the passenger paid for. Stored uppercase ("ECONOMY") in
    # raw_payload; title-cased here, and only rendered when present so older
    # rows without it don't print an empty "Class: —".
    raw = b.get("raw_payload") or {}
    cabin_class = raw.get("cabin_class")
    class_row = (
        f'\n      <div class="info-row"><span class="label">Class: </span>'
        f'<span class="value"> {str(cabin_class).title()}</span></div>'
        if cabin_class else ""
    )

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}</head>
<body><div class="wrapper">
  <div class="header">
    <h1>✈ Flight Booking Confirmed</h1>
    <p>Your booking is confirmed. Have a safe flight!</p>
  </div>
  <div class="body">
    <div style="text-align:center;margin-bottom:20px">
      <span class="status-badge">Confirmed</span>
    </div>
    <div class="pnr-box">
      <div class="pnr-label">Booking Reference / PNR</div>
      <div class="pnr-value">{ pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{ booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title">Flight Details</div>
      <div class="info-row"><span class="label">Route: </span>
        <span class="value"> { origin} → {destination}</span></div>{class_row}
      <div class="info-row"><span class="label">Departure: </span>
        <span class="value"> { dep}</span></div>
      <div class="info-row"><span class="label">Arrival: </span>
        <span class="value"> { arr}</span></div>
    </div>
    <div class="section">
      <div class="section-title">Passengers</div>
      {_passenger_cards_html(passengers)}
    </div>
    <div class="section">
      <div class="section-title">Payment</div>
      <div style="text-align:right;margin-top:8px">
        <span class="amount-total">{amount}</span>
        <div style="font-size:12px;color:#34a853;margin-top:4px">✓ Payment Received</div>
      </div>
    </div>
  </div>
  <div class="footer">
    <p>Thank you for choosing <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact us at
       <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


def _train_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    origin = b.get("origin", "—")
    destination = b.get("destination", "—")
    dep = _fmt_dt(b.get("departure_at"))
    arr = _fmt_dt(b.get("arrival_at"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    passengers = b.get("passengers", [])
    raw = b.get("raw_payload") or {}
    train_name = raw.get("train_name", "Pakistan Railways Train")
    train_number = raw.get("train_number", "")
    # The class the passenger paid for (Economy / AC Standard / AC Business). Only
    # rendered when present so older rows without it don't print an empty "Class: —".
    train_class = raw.get("train_class")
    class_row = (
        f'\n      <div class="info-row"><span class="label">Class: </span>'
        f'<span class="value"> {train_class}</span></div>'
        if train_class else ""
    )

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}</head>
<body><div class="wrapper">
  <div class="header">
    <h1>🚂 Train Booking Confirmed</h1>
    <p>Your train ticket is ready. Bon voyage!</p>
  </div>
  <div class="body">
    <div style="text-align:center;margin-bottom:20px">
      <span class="status-badge">Confirmed</span>
    </div>
    <div class="pnr-box">
      <div class="pnr-label">PNR / Booking Reference</div>
      <div class="pnr-value">{pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title">Train Details</div>
      <div class="info-row"><span class="label">Train: </span>
        <span class="value">{ train_name} ({train_number})</span></div>
      <div class="info-row"><span class="label">Route:</span>
        <span class="value">{ origin} → {destination}</span></div>{class_row}
      <div class="info-row"><span class="label">Departure: </span>
        <span class="value">{ dep}</span></div>
      <div class="info-row"><span class="label">Arrival: </span>
        <span class="value">{ arr}</span></div>
    </div>
    <div class="section">
      <div class="section-title">Passengers</div>
      {_passenger_cards_html(passengers)}
    </div>
    <div class="section">
      <div class="section-title">Payment</div>
      <div style="text-align:right;margin-top:8px">
        <span class="amount-total">{amount}</span>
        <div style="font-size:12px;color:#34a853;margin-top:4px">✓ Payment Received</div>
      </div>
    </div>
  </div>
  <div class="footer">
    <p>Thank you for choosing <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact: <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


def _hotel_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    hotel_name = b.get("hotel_name", "—")
    check_in  = _fmt_date(b.get("check_in"))
    check_out = _fmt_date(b.get("check_out"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    raw = b.get("raw_payload") or {}
    city = raw.get("city", b.get("destination", "—"))
    # Agent-initiated hotel bookings store the party size as `travelers` (guests
    # and travelers are the same thing for a hotel) and never set a separate
    # `guests` key — so without this fallback the emailed ticket printed
    # "Guests: —" even though the summary card correctly showed the count.
    guests = raw.get("guests") or raw.get("travelers") or "—"
    rooms = raw.get("rooms", "—")

    # Calculate nights
    nights_str = "—"
    try:
        from datetime import date
        ci = date.fromisoformat(str(b.get("check_in", ""))[:10])
        co = date.fromisoformat(str(b.get("check_out", ""))[:10])
        nights_str = str((co - ci).days)
    except Exception:
        pass

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}</head>
<body><div class="wrapper">
  <div class="header">
    <h1>🏨 Hotel Booking Confirmed</h1>
    <p>Your hotel reservation is confirmed. Enjoy your stay!</p>
  </div>
  <div class="body">
    <div style="text-align:center;margin-bottom:20px">
      <span class="status-badge">Confirmed</span>
    </div>
    <div class="pnr-box">
      <div class="pnr-label">Reservation Number</div>
      <div class="pnr-value">{ pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px"> { booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title">Reservation Details</div>
      <div class="info-row"><span class="label">Hotel: </span>
        <span class="value"> { hotel_name}</span></div>
      <div class="info-row"><span class="label">City: </span>
        <span class="value"> { city}</span></div>
      <div class="info-row"><span class="label">Check-in: </span>
        <span class="value"> { check_in}</span></div>
      <div class="info-row"><span class="label">Check-out: </span>
        <span class="value"> { check_out}</span></div>
      <div class="info-row"><span class="label">Nights: </span>
        <span class="value"> { nights_str}</span></div>
      <div class="info-row"><span class="label">Guests: </span>
        <span class="value"> { guests}</span></div>
      <div class="info-row"><span class="label">Rooms: </span>
        <span class="value"> { rooms}</span></div>
    </div>
    <div class="section">
      <div class="section-title">Payment</div>
      <div style="text-align:right;margin-top:8px">
        <span class="amount-total">{amount}</span>
        <div style="font-size:12px;color:#34a853;margin-top:4px">✓ Payment Received</div>
      </div>
    </div>
  </div>
  <div class="footer">
    <p>Thank you for choosing <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact: <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


# Public API

async def send_booking_confirmation(booking_uuid: str) -> dict:
    """
    Fetch booking from DB and send the appropriate HTML confirmation email.
    Called by POST /email/booking-confirmation and after payment verification.
    """
    booking = await _fetch_booking_data(booking_uuid)

    if booking is None:
        logger.error("send_booking_confirmation: booking %s not found", booking_uuid)
        return {"sent": False, "reason": "booking_not_found"}

    booking_type = booking.get("booking_type", "flight")
    contact_email = booking.get("contact_email")
    booking_ref = booking.get("booking_id", booking_uuid)

    if not contact_email:
        logger.error("Booking %s has no contact email", booking_uuid)
        return {"sent": False, "reason": "no_contact_email"}

    # Choose template
    if booking_type == "flight":
        html = _flight_email_html(booking)
        subject = f"✈ Flight Booking Confirmed — {booking_ref}"
    elif booking_type == "train":
        html = _train_email_html(booking)
        subject = f"🚂 Train Ticket Confirmed — {booking_ref}"
    elif booking_type == "hotel":
        html = _hotel_email_html(booking)
        subject = f"🏨 Hotel Reservation Confirmed — {booking_ref}"
    else:
        html = _flight_email_html(booking)  # fallback
        subject = f"Booking Confirmed — {booking_ref}"

    result = await send_email(
        to=contact_email,
        subject=subject,
        html=html,
    )

    sent = result.get("id") not in ("disabled", "failed", "skipped", None)
    return {
        "sent": sent,
        "to": contact_email,
        "subject": subject,
        "resend_id": result.get("id"),
        "reason": result.get("reason"),
    }


# Cancellation email templates

_CANCEL_HEADER_STYLE = (
    "background: linear-gradient(135deg, #d93025 0%, #9b1c13 100%);"
)

def _flight_cancel_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    origin = b.get("origin", "—")
    destination = b.get("destination", "—")
    dep = _fmt_dt(b.get("departure_at"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    passengers = b.get("passengers", [])

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}</head>
<body><div class="wrapper">
  <div class="header" style="{_CANCEL_HEADER_STYLE}padding:32px 40px">
    <h1>✈ Flight Booking Cancelled</h1>
    <p>Your booking has been cancelled as requested.</p>
  </div>
  <div class="body">
    <div style="text-align:center;margin-bottom:20px">
      <span class="status-badge-cancelled">Cancelled</span>
    </div>
    <div class="pnr-box" style="background:#fde8e7;border-color:#d93025">
      <div class="pnr-label">Booking Reference / PNR</div>
      <div class="pnr-value" style="color:#d93025">{pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Flight Details</div>
      <div class="info-row"><span class="label">Route:</span>
        <span class="value">{origin} → {destination}</span></div>
      <div class="info-row"><span class="label">Departure:</span>
        <span class="value">{dep}</span></div>
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Passengers</div>
      {_passenger_cards_html(passengers)}
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Amount</div>
      <div style="text-align:right;margin-top:8px">
        <span class="amount-total" style="color:#d93025">{amount}</span>
        <div style="font-size:12px;color:#d93025;margin-top:4px">Booking Cancelled</div>
      </div>
    </div>
    <div style="background:#fff8e1;border-left:4px solid #f9a825;padding:14px 18px;border-radius:6px;font-size:13px;color:#555;margin-top:8px">
      If you paid for this booking, please allow 5–7 business days for any refund to reflect in your account.
      For assistance, contact <a href="mailto:support@travello.ai" style="color:#1a73e8">support@travello.ai</a>.
    </div>
  </div>
  <div class="footer">
    <p>Thank you for using <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact us at
       <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


def _train_cancel_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    origin = b.get("origin", "—")
    destination = b.get("destination", "—")
    dep = _fmt_dt(b.get("departure_at"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    passengers = b.get("passengers", [])
    raw = b.get("raw_payload") or {}
    train_name = raw.get("train_name", "Pakistan Railways Train")
    train_number = raw.get("train_number", "")

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}</head>
<body><div class="wrapper">
  <div class="header" style="{_CANCEL_HEADER_STYLE}padding:32px 40px">
    <h1>🚂 Train Booking Cancelled</h1>
    <p>Your train ticket has been cancelled.</p>
  </div>
  <div class="body">
    <div style="text-align:center;margin-bottom:20px">
      <span class="status-badge-cancelled">Cancelled</span>
    </div>
    <div class="pnr-box" style="background:#fde8e7;border-color:#d93025">
      <div class="pnr-label">PNR / Booking Reference</div>
      <div class="pnr-value" style="color:#d93025">{pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Train Details</div>
      <div class="info-row"><span class="label">Train:</span>
        <span class="value">{train_name} ({train_number})</span></div>
      <div class="info-row"><span class="label">Route:</span>
        <span class="value">{origin} → {destination}</span></div>
      <div class="info-row"><span class="label">Departure:</span>
        <span class="value">{dep}</span></div>
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Passengers</div>
      {_passenger_cards_html(passengers)}
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Amount</div>
      <div style="text-align:right;margin-top:8px">
        <span class="amount-total" style="color:#d93025">{amount}</span>
        <div style="font-size:12px;color:#d93025;margin-top:4px">Booking Cancelled</div>
      </div>
    </div>
    <div style="background:#fff8e1;border-left:4px solid #f9a825;padding:14px 18px;border-radius:6px;font-size:13px;color:#555;margin-top:8px">
      If you paid for this booking, please allow 5–7 business days for any refund to reflect in your account.
      For assistance, contact <a href="mailto:support@travello.ai" style="color:#1a73e8">support@travello.ai</a>.
    </div>
  </div>
  <div class="footer">
    <p>Thank you for using <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact: <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


def _hotel_cancel_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    hotel_name = b.get("hotel_name", "—")
    check_in  = _fmt_date(b.get("check_in"))
    check_out = _fmt_date(b.get("check_out"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    raw = b.get("raw_payload") or {}
    city = raw.get("city", b.get("destination", "—"))

    nights_str = "—"
    try:
        from datetime import date
        ci = date.fromisoformat(str(b.get("check_in", ""))[:10])
        co = date.fromisoformat(str(b.get("check_out", ""))[:10])
        nights_str = str((co - ci).days)
    except Exception:
        pass

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}</head>
<body><div class="wrapper">
  <div class="header" style="{_CANCEL_HEADER_STYLE}padding:32px 40px">
    <h1>🏨 Hotel Booking Cancelled</h1>
    <p>Your hotel reservation has been cancelled.</p>
  </div>
  <div class="body">
    <div style="text-align:center;margin-bottom:20px">
      <span class="status-badge-cancelled">Cancelled</span>
    </div>
    <div class="pnr-box" style="background:#fde8e7;border-color:#d93025">
      <div class="pnr-label">Reservation Number</div>
      <div class="pnr-value" style="color:#d93025">{pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Reservation Details</div>
      <div class="info-row"><span class="label">Hotel:</span>
        <span class="value">{hotel_name}</span></div>
      <div class="info-row"><span class="label">City:</span>
        <span class="value">{city}</span></div>
      <div class="info-row"><span class="label">Check-in:</span>
        <span class="value">{check_in}</span></div>
      <div class="info-row"><span class="label">Check-out:</span>
        <span class="value">{check_out}</span></div>
      <div class="info-row"><span class="label">Nights:</span>
        <span class="value">{nights_str}</span></div>
    </div>
    <div class="section">
      <div class="section-title" style="color:#d93025;border-color:#fde8e7">Amount</div>
      <div style="text-align:right;margin-top:8px">
        <span class="amount-total" style="color:#d93025">{amount}</span>
        <div style="font-size:12px;color:#d93025;margin-top:4px">Booking Cancelled</div>
      </div>
    </div>
    <div style="background:#fff8e1;border-left:4px solid #f9a825;padding:14px 18px;border-radius:6px;font-size:13px;color:#555;margin-top:8px">
      If you paid for this booking, please allow 5–7 business days for any refund to reflect in your account.
      For assistance, contact <a href="mailto:support@travello.ai" style="color:#1a73e8">support@travello.ai</a>.
    </div>
  </div>
  <div class="footer">
    <p>Thank you for using <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact: <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


async def send_cancellation_email(booking_uuid: str) -> dict:
    """
    Fetch booking from DB and send a cancellation HTML email to the user.
    Called after cancel_booking() successfully updates the status.
    """
    booking = await _fetch_booking_data(booking_uuid)

    if booking is None:
        logger.error("send_cancellation_email: booking %s not found", booking_uuid)
        return {"sent": False, "reason": "booking_not_found"}

    booking_type = booking.get("booking_type", "flight")
    contact_email = booking.get("contact_email")
    booking_ref = booking.get("booking_id", booking_uuid)

    if not contact_email:
        logger.error("Booking %s has no contact email for cancellation notice", booking_uuid)
        return {"sent": False, "reason": "no_contact_email"}

    if booking_type == "flight":
        html = _flight_cancel_email_html(booking)
        subject = f"✈ Flight Booking Cancelled — {booking_ref}"
    elif booking_type == "train":
        html = _train_cancel_email_html(booking)
        subject = f"🚂 Train Booking Cancelled — {booking_ref}"
    elif booking_type == "hotel":
        html = _hotel_cancel_email_html(booking)
        subject = f"🏨 Hotel Reservation Cancelled — {booking_ref}"
    else:
        html = _flight_cancel_email_html(booking)
        subject = f"Booking Cancelled — {booking_ref}"

    result = await send_email(
        to=contact_email,
        subject=subject,
        html=html,
    )

    sent = result.get("id") not in ("disabled", "failed", "skipped", None)
    logger.info(
        "Cancellation email for booking %s: sent=%s to=%s",
        booking_uuid, sent, contact_email,
    )
    return {
        "sent": sent,
        "to": contact_email,
        "subject": subject,
        "resend_id": result.get("id"),
        "reason": result.get("reason"),
    }


# =============================================================================
# Car transfer / driver assignment email
# =============================================================================

_TRANSFER_LABELS = {
    "departure":        "Departure Transfer — Your Location → Airport",
    "arrival":          "Arrival Transfer — Airport → Your Destination",
    "return_departure": "Return Transfer — Your Location → Airport",
    "return_arrival":   "Final Arrival Transfer — Airport → Your Home",
    "standalone":       "On-Demand Driver Booking",
}


def _car_booking_email_html(
    driver: dict,
    transfer_type: str,
    pickup_location: str,
    verification_code: str,
    booking: dict,
) -> str:
    transfer_label = _TRANSFER_LABELS.get(transfer_type, transfer_type.replace("_", " ").title())
    booking_ref    = booking.get("booking_id", "—")
    origin         = booking.get("origin", "—")
    destination    = booking.get("destination", "—")

    driver_name    = driver.get("name", "—")
    driver_phone   = driver.get("phone", "—")
    vehicle_make   = driver.get("vehicle_make", "")
    vehicle_model  = driver.get("vehicle_model", "")
    vehicle_plate  = driver.get("vehicle_plate", "—")
    vehicle_color  = driver.get("vehicle_color", "—")
    rating         = driver.get("rating", "—")
    vehicle_full   = f"{vehicle_make} {vehicle_model}".strip() or driver.get("vehicle_type", "—")

    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8">{_BASE_STYLE}
<style>
  .verify-box {{
    background: #1a73e8; border-radius: 12px; text-align: center;
    padding: 24px 20px; margin: 20px 0;
  }}
  .verify-box .v-label {{
    font-size: 12px; color: rgba(255,255,255,0.85); text-transform: uppercase;
    letter-spacing: 2px;
  }}
  .verify-box .v-code {{
    font-size: 52px; font-weight: 900; color: #fff; letter-spacing: 14px;
    font-family: monospace; margin-top: 6px;
  }}
  .verify-box .v-note {{
    font-size: 12px; color: rgba(255,255,255,0.75); margin-top: 8px;
  }}
  .driver-card {{
    background: #f8f9fa; border-radius: 10px; padding: 16px 20px;
    border-left: 4px solid #1a73e8; margin-bottom: 12px;
  }}
</style>
</head>
<body><div class="wrapper">
  <div class="header">
    <h1>🚗 Driver Assigned</h1>
    <p>{transfer_label}</p>
  </div>
  <div class="body">

    <div class="section">
      <div class="section-title">Trip Reference</div>
      <div class="info-row">
        <span class="label">Booking Ref: </span>
        <span class="value">{booking_ref}</span>
      </div>
      <div class="info-row">
        <span class="label">Route: </span>
        <span class="value">{origin} → {destination}</span>
      </div>
      <div class="info-row">
        <span class="label">Pickup Location: </span>
        <span class="value">{pickup_location}</span>
      </div>
    </div>

    <div class="section">
      <div class="section-title">Your Driver</div>
      <div class="driver-card">
        <div style="font-size:16px;font-weight:700;color:#222">{driver_name}</div>
        <div style="font-size:13px;color:#555;margin-top:4px">📞 {driver_phone}</div>
        <div style="font-size:13px;color:#555;margin-top:4px">
          🚘 {vehicle_full} &nbsp;|&nbsp; {vehicle_color} &nbsp;|&nbsp;
          <strong>{vehicle_plate}</strong>
        </div>
        <div style="font-size:13px;color:#f9a825;margin-top:4px">
          ★ {rating} &nbsp;<span style="color:#888">rating</span>
        </div>
      </div>
    </div>

    <div class="verify-box">
      <div class="v-label">Verification Code</div>
      <div class="v-code">{verification_code}</div>
      <div class="v-note">
        Show this code to your driver before boarding.<br>
        Your driver has the same code — always verify before getting in.
      </div>
    </div>

    <div style="background:#fff8e1;border-left:4px solid #f9a825;
                padding:14px 18px;border-radius:6px;font-size:13px;color:#555">
      <strong>How it works:</strong> Ask your driver for the 4-digit code above.
      If the code does not match, do not board and contact us at
      <a href="mailto:support@travello.ai" style="color:#1a73e8">support@travello.ai</a>.
    </div>

  </div>
  <div class="footer">
    <p>Thank you for choosing <strong>Travello AI</strong></p>
    <p style="margin-top:8px">Contact: <a href="mailto:support@travello.ai">support@travello.ai</a></p>
    <p style="margin-top:8px;color:#ccc">&copy; 2024 Travello AI</p>
  </div>
</div></body></html>"""


async def send_car_booking_email(
    contact_email: str,
    driver: dict,
    transfer_type: str,
    pickup_location: str,
    verification_code: str,
    booking: dict,
) -> dict:
    """Send a driver assignment email for one car transfer leg."""
    transfer_label = _TRANSFER_LABELS.get(transfer_type, transfer_type.replace("_", " ").title())
    booking_ref    = booking.get("booking_id", "")
    subject        = f"🚗 Driver Assigned — {transfer_label} ({booking_ref})"

    html = _car_booking_email_html(
        driver=driver,
        transfer_type=transfer_type,
        pickup_location=pickup_location,
        verification_code=verification_code,
        booking=booking,
    )

    result = await send_email(to=contact_email, subject=subject, html=html)
    sent   = result.get("id") not in ("disabled", "failed", "skipped", None)
    logger.info(
        "Car booking email: sent=%s to=%s transfer=%s code=%s",
        sent, contact_email, transfer_type, verification_code,
    )
    return {"sent": sent, "to": contact_email, "subject": subject}


# =============================================================================
# Internal admin notification — sent to Travello AI on every car booking
# =============================================================================

_INTERNAL_EMAIL = "travelloo.ai@gmail.com"


async def send_internal_car_notification(
    user_email: str,
    driver: dict,
    transfer_type: str,
    pickup_location: str,
    dropoff_location: str | None,
    vehicle_type: str,
    verification_code: str,
    booking_id: str,
    pickup_datetime: str | None = None,
    total_amount: int = 0,
) -> None:
    """
    Fire-and-forget internal email to Travello AI with full car booking details.
    Never raises — all errors are logged.
    """
    transfer_label = _TRANSFER_LABELS.get(transfer_type, transfer_type.replace("_", " ").title())
    subject = f"🚗 New Car Booking — {user_email} — {vehicle_type} ({transfer_label})"

    driver_name   = driver.get("name", "—")
    driver_phone  = driver.get("phone", "—")
    vehicle_full  = f"{driver.get('vehicle_color', '')} {driver.get('vehicle_make', '')} {driver.get('vehicle_model', '')}".strip()
    vehicle_plate = driver.get("vehicle_plate", "—")
    rating        = driver.get("rating", "—")
    dropoff_row   = f"<tr><td style='padding:6px 12px;color:#555;font-weight:600'>Dropoff</td><td style='padding:6px 12px'>{dropoff_location}</td></tr>" if dropoff_location else ""
    datetime_row  = f"<tr><td style='padding:6px 12px;color:#555;font-weight:600'>Pickup Time</td><td style='padding:6px 12px'>{pickup_datetime}</td></tr>" if pickup_datetime else ""
    amount_row    = f"<tr><td style='padding:6px 12px;color:#555;font-weight:600'>Fare</td><td style='padding:6px 12px'>PKR {total_amount:,}</td></tr>" if total_amount else ""

    html = f"""<!DOCTYPE html><html><body style="margin:0;padding:20px;font-family:Arial,sans-serif;background:#f5f5f5">
<div style="max-width:600px;margin:auto;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1)">
  <div style="background:#1a237e;padding:20px 24px">
    <h2 style="margin:0;color:#fff;font-size:18px">🚗 New Car Booking — Internal Notification</h2>
    <p style="margin:6px 0 0;color:rgba(255,255,255,.75);font-size:13px">{transfer_label}</p>
  </div>
  <div style="padding:24px">

    <h3 style="margin:0 0 12px;font-size:14px;color:#333;text-transform:uppercase;letter-spacing:.8px">Booking Info</h3>
    <table style="width:100%;border-collapse:collapse;margin-bottom:20px">
      <tr style="background:#f9f9f9"><td style="padding:6px 12px;color:#555;font-weight:600">Booking ID</td><td style="padding:6px 12px;font-family:monospace">{booking_id}</td></tr>
      <tr><td style="padding:6px 12px;color:#555;font-weight:600">User Email</td><td style="padding:6px 12px">{user_email}</td></tr>
      <tr style="background:#f9f9f9"><td style="padding:6px 12px;color:#555;font-weight:600">Type</td><td style="padding:6px 12px">{transfer_label}</td></tr>
      <tr><td style="padding:6px 12px;color:#555;font-weight:600">Pickup</td><td style="padding:6px 12px">{pickup_location}</td></tr>
      {dropoff_row}
      {datetime_row}
      {amount_row}
    </table>

    <h3 style="margin:0 0 12px;font-size:14px;color:#333;text-transform:uppercase;letter-spacing:.8px">Driver Info</h3>
    <table style="width:100%;border-collapse:collapse;margin-bottom:20px">
      <tr style="background:#f9f9f9"><td style="padding:6px 12px;color:#555;font-weight:600">Name</td><td style="padding:6px 12px">{driver_name}</td></tr>
      <tr><td style="padding:6px 12px;color:#555;font-weight:600">Phone</td><td style="padding:6px 12px">{driver_phone}</td></tr>
      <tr style="background:#f9f9f9"><td style="padding:6px 12px;color:#555;font-weight:600">Vehicle</td><td style="padding:6px 12px">{vehicle_full} ({vehicle_type})</td></tr>
      <tr><td style="padding:6px 12px;color:#555;font-weight:600">Plate</td><td style="padding:6px 12px;font-weight:700">{vehicle_plate}</td></tr>
      <tr style="background:#f9f9f9"><td style="padding:6px 12px;color:#555;font-weight:600">Rating</td><td style="padding:6px 12px">★ {rating}</td></tr>
    </table>

    <div style="background:#1565c0;border-radius:8px;padding:16px 20px;text-align:center">
      <p style="margin:0;color:rgba(255,255,255,.8);font-size:11px;letter-spacing:1.5px;text-transform:uppercase">Verification Code</p>
      <p style="margin:8px 0 4px;color:#fff;font-size:40px;font-weight:800;letter-spacing:10px;font-family:monospace">{verification_code}</p>
    </div>

  </div>
  <div style="background:#f5f5f5;padding:14px 24px;font-size:11px;color:#999;text-align:center">
    Travello AI · Internal Notification · Do not reply
  </div>
</div>
</body></html>"""

    try:
        await send_email(to=_INTERNAL_EMAIL, subject=subject, html=html)
        logger.info("Internal car notification sent: booking=%s user=%s", booking_id, user_email)
    except Exception as exc:
        logger.warning("Internal car notification failed: booking=%s error=%s", booking_id, exc)


async def send_consolidated_car_booking_email(
    contact_email: str,
    legs: list[dict],
    booking: dict,
) -> dict:
    """
    Send ONE email to the user covering all their car transfer legs for a booking.
    Each leg dict: transfer_type, vehicle_type, pickup_location, driver, code.
    """
    booking_ref = booking.get("booking_id", "—")
    origin      = booking.get("origin", "—")
    destination = booking.get("destination", "—")
    leg_count   = len(legs)
    subject     = f"🚗 Your Car Transfers Confirmed — {leg_count} Driver(s) Assigned ({booking_ref})"

    def _leg_block(leg: dict, index: int) -> str:
        transfer_label = _TRANSFER_LABELS.get(leg["transfer_type"], leg["transfer_type"].replace("_", " ").title())
        d = leg["driver"]
        vehicle_full = f"{d.get('vehicle_color', '')} {d.get('vehicle_make', '')} {d.get('vehicle_model', '')}".strip() or "—"
        dropoff = leg.get("dropoff_location")
        dropoff_line = (
            f'<p style="margin:2px 0 0;color:rgba(255,255,255,.75);font-size:12px">'
            f'🏁 {dropoff}</p>'
        ) if dropoff else ""
        return f"""
    <div style="margin-bottom:28px;border:1px solid #e0e0e0;border-radius:12px;overflow:hidden">
      <!-- Leg header -->
      <div style="background:#1565c0;padding:12px 18px">
        <p style="margin:0;color:#fff;font-size:13px;font-weight:700;letter-spacing:.5px">
          Transfer {index} of {leg_count} &nbsp;·&nbsp; {transfer_label}
        </p>
        <p style="margin:4px 0 0;color:rgba(255,255,255,.75);font-size:12px">
          📍 {leg["pickup_location"]}
        </p>
        {dropoff_line}
      </div>
      <!-- Verification code -->
      <div style="background:#e3f0ff;padding:14px 18px;text-align:center;border-bottom:1px solid #e0e0e0">
        <p style="margin:0;color:#1565c0;font-size:11px;font-weight:700;letter-spacing:1.8px;text-transform:uppercase">Verification Code</p>
        <p style="margin:8px 0 4px;color:#1565c0;font-size:46px;font-weight:800;letter-spacing:12px;font-family:monospace;line-height:1">{leg["code"]}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#555">Show this code to your driver before boarding</p>
      </div>
      <!-- Driver details -->
      <div style="padding:14px 18px">
        <table style="width:100%;border-collapse:collapse">
          <tr><td style="padding:5px 8px;color:#555;font-weight:600;width:38%;font-size:13px">Driver</td><td style="padding:5px 8px;font-size:13px">{d.get("name", "—")}</td></tr>
          <tr style="background:#f9f9f9"><td style="padding:5px 8px;color:#555;font-weight:600;font-size:13px">Phone</td><td style="padding:5px 8px;font-size:13px">📞 {d.get("phone", "—")}</td></tr>
          <tr><td style="padding:5px 8px;color:#555;font-weight:600;font-size:13px">Vehicle</td><td style="padding:5px 8px;font-size:13px">🚘 {vehicle_full} ({leg["vehicle_type"]})</td></tr>
          <tr style="background:#f9f9f9"><td style="padding:5px 8px;color:#555;font-weight:600;font-size:13px">Plate No.</td><td style="padding:5px 8px;font-size:13px;font-weight:700">{d.get("vehicle_plate", "—")}</td></tr>
          <tr><td style="padding:5px 8px;color:#555;font-weight:600;font-size:13px">Rating</td><td style="padding:5px 8px;font-size:13px;color:#f9a825">★ {d.get("rating", "—")}</td></tr>
        </table>
      </div>
    </div>"""

    legs_html = "".join(_leg_block(leg, i + 1) for i, leg in enumerate(legs))

    html = f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:Arial,sans-serif">
<div style="max-width:600px;margin:30px auto;background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,.10)">

  <!-- Header -->
  <div style="background:linear-gradient(135deg,#1a237e,#1565c0);padding:28px 28px 22px">
    <p style="margin:0;font-size:28px">🚗</p>
    <h1 style="margin:8px 0 4px;color:#fff;font-size:22px;font-weight:800">Your Drivers Are Ready!</h1>
    <p style="margin:0;color:rgba(255,255,255,.80);font-size:13px">
      {leg_count} car transfer(s) confirmed &nbsp;·&nbsp; {origin} → {destination}
    </p>
  </div>

  <!-- Booking ref -->
  <div style="background:#f9f9f9;padding:12px 28px;border-bottom:1px solid #eee">
    <p style="margin:0;font-size:12px;color:#888">Booking Reference</p>
    <p style="margin:2px 0 0;font-size:14px;font-weight:700;font-family:monospace;color:#333">{booking_ref}</p>
  </div>

  <!-- Transfer legs -->
  <div style="padding:24px 28px">
    <p style="margin:0 0 20px;font-size:14px;color:#555">
      Below are your assigned drivers for each transfer leg.
      <strong>Always verify the 4-digit code before getting in the vehicle.</strong>
    </p>
    {legs_html}
  </div>

  <!-- Safety note -->
  <div style="margin:0 28px 24px;background:#fff8e1;border-left:4px solid #f9a825;padding:14px 18px;border-radius:6px;font-size:13px;color:#555">
    <strong>🔒 Safety Tip:</strong> Ask your driver to confirm the same 4-digit code shown above.
    If codes don't match, do not board and contact us at
    <a href="mailto:support@travello.ai" style="color:#1a73e8">support@travello.ai</a>.
  </div>

  <!-- Footer -->
  <div style="background:#f5f5f5;padding:16px 28px;text-align:center;font-size:12px;color:#999">
    <p style="margin:0">Thank you for choosing <strong style="color:#1565c0">Travello AI</strong></p>
    <p style="margin:6px 0 0">&copy; 2024 Travello AI · <a href="mailto:support@travello.ai" style="color:#1a73e8">support@travello.ai</a></p>
  </div>

</div>
</body></html>"""

    result = await send_email(to=contact_email, subject=subject, html=html)
    sent   = result.get("id") not in ("disabled", "failed", "skipped", None)
    logger.info(
        "Consolidated car email: sent=%s to=%s legs=%d ref=%s",
        sent, contact_email, leg_count, booking_ref,
    )
    return {"sent": sent, "to": contact_email, "subject": subject}


async def send_internal_car_booking_summary(
    user_email: str,
    booking_ref: str,
    booking_route: str,
    legs: list[dict],
) -> None:
    """
    One consolidated internal email to Travello AI after a travel booking
    with car transfers. Covers all legs (up to 4) in a single email.
    Each leg dict: transfer_type, vehicle_type, pickup_location, driver, code.
    Never raises.
    """
    leg_count = len(legs)
    subject   = f"🚗 {leg_count} Car Transfer(s) Booked — {user_email} — Ref: {booking_ref}"

    def _leg_html(leg: dict) -> str:
        transfer_label = _TRANSFER_LABELS.get(leg["transfer_type"], leg["transfer_type"].replace("_", " ").title())
        d = leg["driver"]
        vehicle_full = f"{d.get('vehicle_color', '')} {d.get('vehicle_make', '')} {d.get('vehicle_model', '')}".strip()
        dropoff = leg.get("dropoff_location")
        dropoff_row = (
            f'<tr style="background:#f9f9f9"><td style="padding:4px 10px;color:#555;'
            f'font-weight:600">Dropoff</td><td style="padding:4px 10px">{dropoff}</td></tr>'
        ) if dropoff else ""
        return f"""
        <div style="border:1px solid #e0e0e0;border-radius:8px;padding:16px;margin-bottom:16px">
          <p style="margin:0 0 10px;font-size:13px;font-weight:700;color:#1a237e;text-transform:uppercase;letter-spacing:.6px">{transfer_label}</p>
          <table style="width:100%;border-collapse:collapse">
            <tr><td style="padding:4px 10px;color:#555;font-weight:600;width:40%">Pickup</td><td style="padding:4px 10px">{leg["pickup_location"]}</td></tr>
            {dropoff_row}
            <tr style="background:#f9f9f9"><td style="padding:4px 10px;color:#555;font-weight:600">Vehicle</td><td style="padding:4px 10px">{leg["vehicle_type"]} — {vehicle_full}</td></tr>
            <tr><td style="padding:4px 10px;color:#555;font-weight:600">Plate</td><td style="padding:4px 10px;font-weight:700">{d.get("vehicle_plate", "—")}</td></tr>
            <tr style="background:#f9f9f9"><td style="padding:4px 10px;color:#555;font-weight:600">Driver</td><td style="padding:4px 10px">{d.get("name", "—")} · {d.get("phone", "—")} · ★ {d.get("rating", "—")}</td></tr>
            <tr><td style="padding:4px 10px;color:#555;font-weight:600">Code</td><td style="padding:4px 10px;font-size:20px;font-weight:800;font-family:monospace;letter-spacing:6px;color:#1565c0">{leg["code"]}</td></tr>
          </table>
        </div>"""

    legs_html = "".join(_leg_html(leg) for leg in legs)

    html = f"""<!DOCTYPE html><html><body style="margin:0;padding:20px;font-family:Arial,sans-serif;background:#f5f5f5">
<div style="max-width:640px;margin:auto;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1)">
  <div style="background:#1a237e;padding:20px 24px">
    <h2 style="margin:0;color:#fff;font-size:18px">🚗 Car Transfers Summary — Internal</h2>
    <p style="margin:6px 0 0;color:rgba(255,255,255,.75);font-size:13px">{leg_count} transfer(s) confirmed for this booking</p>
  </div>
  <div style="padding:24px">
    <table style="width:100%;border-collapse:collapse;margin-bottom:20px">
      <tr><td style="padding:6px 12px;color:#555;font-weight:600;width:35%">Booking Ref</td><td style="padding:6px 12px;font-family:monospace">{booking_ref}</td></tr>
      <tr style="background:#f9f9f9"><td style="padding:6px 12px;color:#555;font-weight:600">Route</td><td style="padding:6px 12px">{booking_route}</td></tr>
      <tr><td style="padding:6px 12px;color:#555;font-weight:600">User</td><td style="padding:6px 12px">{user_email}</td></tr>
    </table>
    <h3 style="margin:0 0 14px;font-size:14px;color:#333;text-transform:uppercase;letter-spacing:.8px">Transfer Legs</h3>
    {legs_html}
  </div>
  <div style="background:#f5f5f5;padding:14px 24px;font-size:11px;color:#999;text-align:center">
    Travello AI · Internal Notification · Do not reply
  </div>
</div>
</body></html>"""

    try:
        await send_email(to=_INTERNAL_EMAIL, subject=subject, html=html)
        logger.info("Internal car summary sent: ref=%s legs=%d user=%s", booking_ref, leg_count, user_email)
    except Exception as exc:
        logger.warning("Internal car summary failed: ref=%s error=%s", booking_ref, exc)
