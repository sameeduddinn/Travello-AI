from __future__ import annotations
# PURPOSE: A small, deterministic summary of what this conversation has already
#          established — transport mode, route, dates, party size, budget, which
#          options were shown, and which pieces have been prepared.


import re
from dataclasses import dataclass, field
from datetime import date

from agents.clarification_agent import CITY_TO_IATA
from services.hotel_service import CITY_ALIASES

# Every city name the app recognises, longest first so "dera ghazi khan" wins
# over "khan" and multi-word names aren't split.
_KNOWN_CITIES: list[str] = sorted(
    {c.lower() for c in CITY_TO_IATA} | {c.lower() for c in CITY_ALIASES},
    key=len, reverse=True,
)
_CITY_RE = re.compile(
    r"\b(" + "|".join(re.escape(c) for c in _KNOWN_CITIES) + r")\b", re.I
) if _KNOWN_CITIES else None
# "from <city>" / "to <city>" — lets derive_state tell origin from destination
# by preposition rather than by which one happens to be typed first ("trip to
# Naran from Karachi" names the destination before the origin).
_FROM_CITY_RE = re.compile(
    r"\bfrom\s+(" + "|".join(re.escape(c) for c in _KNOWN_CITIES) + r")\b", re.I
) if _KNOWN_CITIES else None
_TO_CITY_RE = re.compile(
    r"\bto\s+(" + "|".join(re.escape(c) for c in _KNOWN_CITIES) + r")\b", re.I
) if _KNOWN_CITIES else None

_ISO_DATE_RE = re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b")
# "for 2 people", "2 adults", "we are 3", "3 passengers", "4 guests"
_PAX_RE = re.compile(
    r"\b(?:for\s+)?(\d{1,2})\s*(?:adults?|persons?|people|passengers?|pax|travell?ers?|guests?)\b"
    r"|\bfor\s+(\d{1,2})\s*(?:of\s+us)?\b",
    re.I,
)
_ROOMS_RE = re.compile(r"\b(\d{1,2})\s*rooms?\b", re.I)
_NIGHTS_RE = re.compile(r"\b(\d{1,2})\s*nights?\b", re.I)
# "budget 150000", "under 50k", "PKR 80,000", "80000 rupees"
_BUDGET_RE = re.compile(
    r"\b(?:budget|under|below|within|max(?:imum)?|around|about|upto|up\s+to)\s*"
    r"(?:of\s+)?(?:pkr|rs\.?|rupees)?\s*([\d,]{3,12})\s*(k\b)?"
    r"|\b(?:pkr|rs\.?)\s*([\d,]{3,12})\b",
    re.I,
)

_TRAIN_MODE_RE = re.compile(
    r"\b(train|trains|rail|railway|railways|tezgam|khyber|green\s?line|"
    r"business\s?express|awam|jaffar|bogie|berth|coach)\b", re.I)
_FLIGHT_MODE_RE = re.compile(
    r"\b(flight|flights|fly|flying|flew|plane|air\s?line|airline|"
    r"pia|airblue|air\s?sial|serene|jazeera|boarding|air\s?ticket)\b", re.I)
_HOTEL_MODE_RE = re.compile(
    r"\b(hotel|hotels|room|rooms|stay|staying|accommodation|lodging|lodge|"
    r"guest\s?house|resort|check\s?in|check\s?out)\b", re.I)

# Markers the app's OWN summary writer emits — the most reliable signal that a
# component was actually prepared, because only format_booking_summary /
# format_package_summary produce them.
_PREPARED_MARKERS = (
    ("flight", re.compile(r"\*\*Flight:\*\*", re.I)),
    ("train", re.compile(r"\*\*Train:\*\*", re.I)),
    ("hotel", re.compile(r"\*\*Hotel:\*\*", re.I)),
    ("car", re.compile(r"\*\*Car transfer:\*\*|Car Booking Summary", re.I)),
)

_MAX_STATE_CHARS = 400


@dataclass
class TripState:
    """What the conversation has already pinned down. All fields optional."""

    mode: str = ""  # "train" | "flight" | "hotel" | ""
    origin: str = ""
    destination: str = ""
    travel_date: str = ""
    return_date: str = ""
    passengers: int | None = None
    rooms: int | None = None
    nights: int | None = None
    budget_pkr: int | None = None
    prepared: list[str] = field(default_factory=list)

    def is_empty(self) -> bool:
        return not any((
            self.mode, self.origin, self.destination, self.travel_date,
            self.return_date, self.passengers, self.rooms, self.nights,
            self.budget_pkr, self.prepared,
        ))

    def render(self) -> str:
        """One compact line for the model, or '' when nothing is established."""
        if self.is_empty():
            return ""
        parts: list[str] = []
        if self.mode:
            parts.append(f"{self.mode.upper()} search")
        if self.origin and self.destination:
            parts.append(f"{self.origin} -> {self.destination}")
        elif self.destination:
            parts.append(f"to {self.destination}")
        elif self.origin:
            parts.append(f"from {self.origin}")
        if self.travel_date and self.return_date:
            parts.append(f"{self.travel_date} returning {self.return_date}")
        elif self.travel_date:
            parts.append(self.travel_date)
        if self.passengers:
            parts.append(f"{self.passengers} traveller(s)")
        if self.rooms:
            parts.append(f"{self.rooms} room(s)")
        if self.nights:
            parts.append(f"{self.nights} night(s)")
        if self.budget_pkr:
            parts.append(f"budget PKR {self.budget_pkr:,}")
        if self.prepared:
            parts.append("already prepared: " + ", ".join(self.prepared))
        if not parts:
            return ""
        return (
            "TRIP DETAILS ALREADY ESTABLISHED IN THIS CONVERSATION (reuse these "
            "instead of re-asking; confirm rather than assume if the user seems to "
            "be starting something new): " + " · ".join(parts)
        )[:_MAX_STATE_CHARS]


def _cities_in(text: str) -> list[str]:
    if not _CITY_RE or not text:
        return []
    seen: list[str] = []
    for m in _CITY_RE.finditer(text):
        name = m.group(1).title()
        if name not in seen:
            seen.append(name)
    return seen


def _origin_destination_in(text: str) -> tuple[str, str] | None:
    """Preposition-aware route, or None if 'from'/'to' don't both name a city.

    Falls back to appearance order in the caller when this returns None — but
    when both are present it wins even if 'to' is typed before 'from' (e.g.
    "trip to Naran from Karachi" must not swap origin/destination just because
    the destination was named first).
    """
    if not _FROM_CITY_RE or not _TO_CITY_RE or not text:
        return None
    from_m = _FROM_CITY_RE.search(text)
    to_m = _TO_CITY_RE.search(text)
    if not from_m or not to_m:
        return None
    origin, destination = from_m.group(1).title(), to_m.group(1).title()
    if origin == destination:
        return None
    return origin, destination


def _int_or_none(raw: str | None) -> int | None:
    if not raw:
        return None
    try:
        value = int(raw.replace(",", ""))
    except (TypeError, ValueError):
        return None
    return value or None


def _budget_in(text: str) -> int | None:
    m = _BUDGET_RE.search(text or "")
    if not m:
        return None
    raw = m.group(1) or m.group(3)
    value = _int_or_none(raw)
    if value is None:
        return None
    if m.group(2):        # "50k"
        value *= 1000
    # A three-digit "budget" is almost always a fragment of something else
    # (a flight number, a year); a real PKR trip budget starts in the thousands.
    return value if value >= 1000 else None


def _pax_in(text: str) -> int | None:
    for m in _PAX_RE.finditer(text or ""):
        value = _int_or_none(m.group(1) or m.group(2))
        if value and 1 <= value <= 10:
            return value
    return None


def _future_iso_dates(text: str, today: date | None = None) -> list[str]:
    """ISO dates in `text` that haven't already passed, in order of appearance."""
    out: list[str] = []
    for m in _ISO_DATE_RE.finditer(text or ""):
        try:
            parsed = date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            continue
        if today and parsed < today:
            continue
        iso = parsed.isoformat()
        if iso not in out:
            out.append(iso)
    return out


def derive_state(
    history: list[dict] | None,
    user_message: str = "",
    *,
    today: date | None = None,
) -> TripState:
    """
    Build a TripState from the conversation.

    Reads the USER's own words for intent (route, party size, budget) and the
    ASSISTANT's rendered summaries for what has actually been prepared. The
    newest statement wins, so a corrected party size or a changed date replaces
    the earlier one rather than sitting alongside it.
    """
    state = TripState()
    messages = list(history or [])
    if user_message:
        messages = messages + [{"role": "user", "content": user_message}]

    user_texts = [
        m.get("content") or "" for m in messages
        if (m.get("role") or "").lower() == "user"
    ]
    assistant_texts = [
        m.get("content") or "" for m in messages
        if (m.get("role") or "").lower() == "assistant"
    ]

    # Oldest first, so later statements overwrite earlier ones.
    for text in user_texts:
        if not isinstance(text, str):
            continue
        modes_named = {
            name for name, rx in (
                ("train", _TRAIN_MODE_RE),
                ("flight", _FLIGHT_MODE_RE),
                ("hotel", _HOTEL_MODE_RE),
            ) if rx.search(text)
        }
        # Only act on an UNAMBIGUOUS mention. A message naming two modes at once
        # ("flight and hotel package") says nothing about which one replaces the
        # other, so it's safer to leave whatever was already established alone.
        if len(modes_named) == 1:
            state.mode = next(iter(modes_named))
        cities = _cities_in(text)
        if len(cities) >= 2:
            routed = _origin_destination_in(text)
            state.origin, state.destination = routed or (cities[0], cities[1])
        elif len(cities) == 1 and not state.destination:
            state.destination = cities[0]
        dates = _future_iso_dates(text, today)
        if dates:
            state.travel_date = dates[0]
            if len(dates) > 1:
                state.return_date = dates[1]
        pax = _pax_in(text)
        if pax:
            state.passengers = pax
        rooms_m = _ROOMS_RE.search(text)
        if rooms_m:
            rooms = _int_or_none(rooms_m.group(1))
            if rooms and 1 <= rooms <= 5:
                state.rooms = rooms
        nights_m = _NIGHTS_RE.search(text)
        if nights_m:
            nights = _int_or_none(nights_m.group(1))
            if nights and 1 <= nights <= 60:
                state.nights = nights
        budget = _budget_in(text)
        if budget:
            state.budget_pkr = budget

    # The assistant's own summary cards are the only trustworthy record of what
    # was actually prepared — the model's prose is not.
    for text in assistant_texts:
        if not isinstance(text, str) or "Booking Summary" not in text and "Your Package" not in text \
                and "Car Booking Summary" not in text:
            continue
        for label, pattern in _PREPARED_MARKERS:
            if pattern.search(text) and label not in state.prepared:
                state.prepared.append(label)

    return state


def state_hint(
    history: list[dict] | None,
    user_message: str = "",
    *,
    today: date | None = None,
) -> str:
    """The rendered TripState line, or '' when nothing has been established."""
    return derive_state(history, user_message, today=today).render()
