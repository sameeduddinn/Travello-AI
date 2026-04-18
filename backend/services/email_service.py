# =============================================================================
# FILE: services/email_service.py
# PURPOSE: Booking confirmation email templates and dispatch logic.
#          Called after payment is verified to send a rich HTML email to the
#          user's contact_email address.
#
# Uses core.email.send_email() which talks to the Resend API.
# =============================================================================

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from core.email import send_email
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Fetch booking + passengers for email rendering
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Template helpers
# ---------------------------------------------------------------------------

_BRAND_COLOR = "#1a73e8"
_BRAND_DARK  = "#0d47a1"

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
        name = f"{p.get('title','')} {p.get('first_name','')} {p.get('last_name','')}".strip()
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


# ---------------------------------------------------------------------------
# Email templates
# ---------------------------------------------------------------------------

def _flight_email_html(b: dict) -> str:
    pnr = b.get("pnr", "—")
    origin = b.get("origin", "—")
    destination = b.get("destination", "—")
    dep = _fmt_dt(b.get("departure_at"))
    arr = _fmt_dt(b.get("arrival_at"))
    amount = _fmt_amount(b.get("total_amount", 0), b.get("currency", "PKR"))
    booking_id = b.get("booking_id", "—")
    passengers = b.get("passengers", [])

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
      <div class="pnr-value">{pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title">Flight Details</div>
      <div class="info-row"><span class="label">Route</span>
        <span class="value">{origin} → {destination}</span></div>
      <div class="info-row"><span class="label">Departure</span>
        <span class="value">{dep}</span></div>
      <div class="info-row"><span class="label">Arrival</span>
        <span class="value">{arr}</span></div>
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
      <div class="info-row"><span class="label">Train</span>
        <span class="value">{train_name} ({train_number})</span></div>
      <div class="info-row"><span class="label">Route</span>
        <span class="value">{origin} → {destination}</span></div>
      <div class="info-row"><span class="label">Departure</span>
        <span class="value">{dep}</span></div>
      <div class="info-row"><span class="label">Arrival</span>
        <span class="value">{arr}</span></div>
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
    guests = raw.get("guests", "—")
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
      <div class="pnr-value">{pnr}</div>
      <div style="font-size:12px;color:#555;margin-top:6px">{booking_id}</div>
    </div>
    <div class="section">
      <div class="section-title">Reservation Details</div>
      <div class="info-row"><span class="label">Hotel</span>
        <span class="value">{hotel_name}</span></div>
      <div class="info-row"><span class="label">City</span>
        <span class="value">{city}</span></div>
      <div class="info-row"><span class="label">Check-in</span>
        <span class="value">{check_in}</span></div>
      <div class="info-row"><span class="label">Check-out</span>
        <span class="value">{check_out}</span></div>
      <div class="info-row"><span class="label">Nights</span>
        <span class="value">{nights_str}</span></div>
      <div class="info-row"><span class="label">Guests</span>
        <span class="value">{guests}</span></div>
      <div class="info-row"><span class="label">Rooms</span>
        <span class="value">{rooms}</span></div>
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


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def send_booking_confirmation(booking_uuid: str) -> dict:
    """
    Fetch booking from DB and send the appropriate HTML confirmation email.
    Called by POST /email/booking-confirmation and after payment verification.
    Always returns a dict — never raises.
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
