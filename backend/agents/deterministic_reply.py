from __future__ import annotations
# =============================================================================
# PURPOSE: Write the user-facing answer for a SIMPLE search turn in code, from
#          the tool results we already verified — no second LLM call.
#
# WHY IT EXISTS
#   1. COST. A search turn costs two provider calls: one to decide the tool, one
#      to write the answer from its results. The second call carries the whole
#      tool payload back up, so it is the more expensive of the two. On Groq's
#      free tier that doubled the number of turns per day. Rendering the list in
#      code halves it.
#   2. FIDELITY. Everything here is safety-critical to state exactly: prices,
#      flight numbers, airline names, hospital phone numbers. Rendering them in
#      code makes it impossible for the model to round a fare, translate "PA"
#      into the wrong airline, or add a hospital that wasn't in the results —
#      the three failures this codebase has actually had to fix.
#   3. ROBUSTNESS. It still produces a full answer when every provider is out of
#      quota, as long as the search itself succeeded.
#
# WHEN IT DOES *NOT* APPLY (see can_render): anything needing judgement — a
# budget verdict, multi-day planning, a package, an error result, or a mixed set
# of tools. Those keep the LLM, because summarising them is genuine reasoning,
# not formatting. `should_render` is the caller's gate.
# =============================================================================

import json
import re
from typing import Any

# Tools whose output is a plain list we can format without judgement.
_RENDERABLE = {"search_flights", "search_trains", "search_hotels",
               "get_weather", "find_healthcare"}

# Words that mean the user wants prose, not a table: planning, comparison,
# recommendation, or an explanation. Those stay with the model.
_NEEDS_PROSE_RE = re.compile(
    r"\b(plan|planning|itinerary|recommend|suggest|advice|advise|best|better|"
    r"compare|comparison|versus|vs\b|why|how\s+(?:should|do|can)|what\s+should|"
    r"worth\s+it|opinion|think|package|bundle|budget)\b",
    re.I,
)

_MAX_ROWS = 6


def _rows(payload: dict, key: str) -> list[dict]:
    items = payload.get(key)
    return [i for i in items if isinstance(i, dict)] if isinstance(items, list) else []


def _money(value: Any) -> str | None:
    try:
        num = float(value)
    except (TypeError, ValueError):
        return None
    if num != num or num in (float("inf"), float("-inf")) or num <= 0:
        return None
    return f"PKR {int(round(num)):,}"


def _parse(result: str) -> dict | None:
    try:
        data = json.loads(result)
    except (json.JSONDecodeError, TypeError):
        return None
    return data if isinstance(data, dict) else None


def can_render(tool_name: str, result: str) -> bool:
    """True when this single tool result is something we can format in code."""
    if tool_name not in _RENDERABLE:
        return False
    data = _parse(result)
    if data is None or data.get("error"):
        return False
    if tool_name == "search_flights":
        return bool(_rows(data, "flights")) or bool(data.get("note"))
    if tool_name == "search_trains":
        return bool(_rows(data, "trains")) or bool(data.get("note"))
    if tool_name == "search_hotels":
        return bool(_rows(data, "hotels")) or bool(data.get("note"))
    if tool_name == "get_weather":
        # A "weather_available: false" payload is still renderable — saying we
        # don't have live weather is exactly the honest answer required.
        return bool(data.get("weather") or data.get("weather_available") is False)
    if tool_name == "find_healthcare":
        return "hospitals" in data or "pharmacies" in data
    return False


def should_render(
    gathered: list[tuple[str, str]],
    user_message: str,
    *,
    has_budget_note: bool = False,
    has_pick_hint: bool = False,
) -> bool:
    """
    Whether this turn is simple enough to answer without the LLM.

    Deliberately strict. A turn qualifies only when:
      - one or two tools ran, all of them renderable and all successful;
      - two tools means the SAME tool twice, i.e. the two legs of a round trip
        (a flight + hotel pair is a package and needs prose);
      - no budget verdict is outstanding (that needs stating in words);
      - the user isn't picking an option (that turn books, it doesn't list);
      - the message isn't asking for advice, comparison or a plan.
    """
    if not gathered or len(gathered) > 2 or has_budget_note or has_pick_hint:
        return False
    names = [name for name, _ in gathered]
    if len(gathered) == 2 and names[0] != names[1]:
        return False
    if not all(can_render(name, result) for name, result in gathered):
        return False
    return not _NEEDS_PROSE_RE.search(user_message or "")


# ── Renderers ─────────────────────────────────────────────────────────────────

def _multiplies_exactly(unit, count: int, total) -> bool:
    """
    Does `unit × count` really come to `total`, in whole rupees?

    It often doesn't. The services round the party total, and the per-unit
    figure is then derived as round(total / count) — two independent roundings
    that need not reconcile. A live example: Tezgam AC Standard for 3 came back
    as total 8,378 with a per-seat of 2,793, and 2,793 × 3 is 8,379.

    One rupee is nothing to pay and everything to read. The total is the
    server-verified amount that gets charged, so the arithmetic on screen is
    what has to give — see _price_breakdown in booking_agent, which has taken
    the same line since the booking summary was written: a breakdown that
    doesn't add up on screen is worse than no breakdown at all.
    """
    try:
        return round(float(unit)) * int(count) == round(float(total))
    except (TypeError, ValueError):
        return False


def _price_pair(row: dict, payload: dict) -> str:
    """
    'PKR 16,341 per person × 2 = **PKR 32,682 total**' when there are 2+
    travellers, otherwise the single fare.

    The multiplication is shown for a party wherever it is exact, because a bare
    total sitting next to "2 passengers" reads as though the head count was
    ignored — the exact complaint that produced this rule. Where it is NOT
    exact, both figures still appear (the head count stays visible) but the
    per-person fare is marked approximate instead of asserting a sum that a
    reader checking it would find wrong.
    """
    total = _money(row.get("total_price_pkr"))
    per_seat = _money(row.get("price_per_seat_pkr"))
    try:
        pax = int(payload.get("passengers") or 1)
    except (TypeError, ValueError):
        pax = 1
    if pax > 1 and per_seat and total:
        if _multiplies_exactly(row.get("price_per_seat_pkr"), pax,
                               row.get("total_price_pkr")):
            return f"{per_seat} per person × {pax} = **{total} total**"
        return f"**{total} total** for {pax} (≈ {per_seat} each)"
    return f"**{total}**" if total else (per_seat or "price on request")


def _render_flights(payload: dict, label: str = "") -> str:
    rows = _rows(payload, "flights")[:_MAX_ROWS]
    if not rows:
        return str(payload.get("note") or "").strip()
    head = f"**{label}**" if label else ""
    lines = [head] if head else []
    for i, f in enumerate(rows, start=1):
        airline = str(f.get("airline") or "").strip()
        number = str(f.get("flight_number") or "").strip()
        # Never translate a 2-letter code into a carrier name — if the listing
        # carries no airline, the flight number stands alone.
        name = f"{airline} {number}".strip() or number or "Flight"
        depart = str(f.get("depart") or "").strip()
        if " " in depart:
            depart = depart.split(" ", 1)[1]
        arrive = str(f.get("arrive") or "").strip()
        when = f" · {depart} → {arrive}" if depart and arrive else (f" · {depart}" if depart else "")
        seats = f.get("seats_left")
        seats_txt = f" · {seats} seat(s) left" if isinstance(seats, int) and 0 < seats <= 9 else ""
        lines.append(f"{i}. **{name}**{when} — {_price_pair(f, payload)}{seats_txt}")
    return "\n".join(lines)


def _render_trains(payload: dict, label: str = "") -> str:
    rows = _rows(payload, "trains")[:_MAX_ROWS]
    if not rows:
        return str(payload.get("note") or "").strip()
    lines = [f"**{label}**"] if label else []
    for i, t in enumerate(rows, start=1):
        name = str(t.get("train_name") or t.get("name") or "Train").strip()
        number = str(t.get("train_number") or "").strip()
        title = f"{name} ({number})" if number else name
        depart = str(t.get("depart") or t.get("departure_time") or "").strip()
        arrive = str(t.get("arrive") or t.get("arrival_time") or "").strip()
        when = f" · {depart} → {arrive}" if depart and arrive else (f" · {depart}" if depart else "")
        lines.append(f"{i}. **{title}**{when}")
        # _serialize_trains names the fare class "class"; each class carries its
        # own total_price_pkr, so the class list IS the price list for a train.
        classes = [c for c in (t.get("classes") or []) if isinstance(c, dict)]
        for cls in classes[:4]:
            label_txt = cls.get("class") or cls.get("class_name") or "Class"
            lines.append(f"   · {label_txt} — {_price_pair(cls, payload)}")
        if not classes:
            lines[-1] += f" — {_price_pair(t, payload)}"
    return "\n".join(lines)


def _render_hotels(payload: dict, label: str = "") -> str:
    rows = _rows(payload, "hotels")[:_MAX_ROWS]
    if not rows:
        return str(payload.get("note") or "").strip()
    try:
        nights = int(payload.get("nights") or 0)
    except (TypeError, ValueError):
        nights = 0
    lines = [f"**{label}**"] if label else []
    for i, h in enumerate(rows, start=1):
        name = str(h.get("name") or h.get("hotel_name") or "Hotel").strip()
        stars = h.get("stars")
        star_txt = f" {int(stars)}★" if isinstance(stars, (int, float)) and stars else ""
        per_night = _money(h.get("price_per_night_pkr"))
        # total_stay_pkr is quoted verbatim — it is exactly what will be charged.
        total = _money(h.get("total_stay_pkr"))
        if per_night and total and nights > 1:
            # Same rule as the fares above: a nightly rate that doesn't multiply
            # back to the stay total is shown as approximate, never as a sum.
            if _multiplies_exactly(h.get("price_per_night_pkr"), nights,
                                   h.get("total_stay_pkr")):
                price = f"{per_night}/night × {nights} nights = **{total}**"
            else:
                price = f"**{total}** for {nights} nights (≈ {per_night}/night)"
        elif total:
            price = f"**{total}** total"
        else:
            price = per_night or "price on request"
        lines.append(f"{i}. **{name}**{star_txt} — {price}")
    return "\n".join(lines)


def _render_weather(payload: dict) -> str:
    """
    _exec_weather returns {"city", "weather": {...}} on success, or
    {"city", "weather_available": False, "note"} when only the synthetic
    fallback record exists. The second shape must NEVER produce a temperature —
    that placeholder 27°C reading is what the honesty rule exists to suppress.
    """
    city = str(payload.get("city") or "").strip()
    weather = payload.get("weather")
    if payload.get("weather_available") is False or not isinstance(weather, dict):
        return (f"I don't have live weather for {city or 'that place'} right now, "
                f"so I'd rather not guess at a temperature. Anything else I can help "
                f"with for the trip?")
    temp = weather.get("temperature_current")
    if temp is None:
        temp = weather.get("temperature")
    condition = str(weather.get("condition") or weather.get("description") or "").strip()
    bits = []
    if temp is not None:
        bits.append(f"{temp}°C")
    if condition:
        bits.append(condition)
    if not bits:
        return (f"I don't have live weather for {city or 'that place'} right now, "
                f"so I'd rather not guess at a temperature.")
    line = f"**{city.title() or 'Current weather'}** — {', '.join(bits)}."
    feels = weather.get("feels_like")
    if feels is not None:
        line += f" Feels like {feels}°C."
    warning = str(weather.get("travel_warning") or weather.get("warning") or "").strip()
    if warning:
        line += f"\n\n⚠️ {warning}"
    return line


def _facility_rows(payload: dict, key: str, heading: str) -> list[str]:
    rows = _rows(payload, key)[:_MAX_ROWS]
    if not rows:
        return []
    lines = [f"**{heading}**"]
    for i, f in enumerate(rows, start=1):
        name = str(f.get("name") or "Facility").strip()
        row = f"{i}. **{name}**"
        distance = f.get("distance_km")
        if isinstance(distance, (int, float)):
            row += f" · {distance} km"
        phone = str(f.get("phone") or "").strip()
        if phone:
            row += f" · {phone}"
        address = str(f.get("address") or "").strip()
        if address and address != "Address unavailable":
            row += f"\n   {address}"
        lines.append(row)
    return lines


def _render_healthcare(payload: dict) -> str:
    """
    Facilities EXACTLY as returned — never supplemented from model knowledge.
    A wrong medical phone number is dangerous, which is why this is rendered in
    code rather than summarised by a model.
    """
    where = str(payload.get("location") or payload.get("city") or "").strip()
    lines: list[str] = []
    lines += _facility_rows(payload, "hospitals", f"Hospitals{f' near {where}' if where else ''}")
    pharmacy_lines = _facility_rows(payload, "pharmacies", "Pharmacies nearby")
    if pharmacy_lines:
        if lines:
            lines.append("")
        lines += pharmacy_lines
    if not lines:
        lines.append(
            f"I couldn't find any listed facilities{f' near {where}' if where else ''} "
            f"right now, so I won't name one from memory."
        )
    numbers = payload.get("emergency_numbers")
    lines.append("")
    lines.append(
        numbers.strip() if isinstance(numbers, str) and numbers.strip()
        else "Emergency numbers — Rescue 1122 · Ambulance 115 · Police 15"
    )
    return "\n".join(lines)


_RENDERERS = {
    "search_flights": _render_flights,
    "search_trains": _render_trains,
    "search_hotels": _render_hotels,
}


def render(gathered: list[tuple[str, str]]) -> str:
    """
    Format one or two verified tool results into the final chat reply.

    Two results of the same search tool are rendered as two clearly labelled
    numbered lists (Outbound, then Return) — the shape the booking rules require
    so a round-trip pick can be mapped back to a leg by position.
    """
    if not gathered:
        return ""
    payloads = [(name, _parse(result)) for name, result in gathered]
    if any(p is None for _, p in payloads):
        return ""

    if len(payloads) == 2 and payloads[0][0] == payloads[1][0]:
        name = payloads[0][0]
        renderer = _RENDERERS.get(name)
        if renderer is None:
            return ""
        outbound = renderer(payloads[0][1] or {}, "Outbound")
        inbound = renderer(payloads[1][1] or {}, "Return")
        if not outbound or not inbound:
            return ""
        return (
            f"{outbound}\n\n{inbound}\n\n"
            "Tell me which one you'd like for each leg (for example \"1 for outbound "
            "and 2 for return\") and I'll set the booking up — both legs together, "
            "one payment."
        )

    name, payload = payloads[0]
    payload = payload or {}
    if name == "get_weather":
        return _render_weather(payload)
    if name == "find_healthcare":
        return _render_healthcare(payload)
    renderer = _RENDERERS.get(name)
    if renderer is None:
        return ""
    body = renderer(payload, "")
    if not body:
        return ""
    rows = (_rows(payload, "flights") or _rows(payload, "trains")
            or _rows(payload, "hotels"))
    if not rows:
        return body  # a "no availability" note stands on its own
    tail = "\n\nJust tell me the number of the one you want and I'll set it up."
    return body + tail
