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

# Written dates. Nobody answering "what are your travel dates?" types ISO — the
# observed reply was "14 August 2026 to 25 August 2026", which left travel_date
# and return_date blank and took the package planner's stay length with them.
_MONTHS = {
    "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3,
    "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
    "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9,
    "oct": 10, "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12,
}
_MONTH_ALT = "|".join(sorted(_MONTHS, key=len, reverse=True))
_ORDINAL = r"(?:st|nd|rd|th)?"
# "14 August 2026" / "Aug 14th" / "14 August"
_TEXT_DATE_RE = re.compile(
    rf"\b(?:(?P<d1>\d{{1,2}}){_ORDINAL}\s+(?P<m1>{_MONTH_ALT})"
    rf"|(?P<m2>{_MONTH_ALT})\s+(?P<d2>\d{{1,2}}){_ORDINAL})"
    rf"(?:[\s,]+(?P<y>\d{{4}}))?\b",
    re.I,
)
# "may" and "march" are ordinary English words as well as months, and both
# happily follow a number: "we are 4 may be 5 people" read as 4 May, silently
# setting a travel date nobody gave. Those two alone have to be anchored by a
# year or a date word before they count as a month.
_AMBIGUOUS_MONTHS = {"may", "march"}
_DATE_CUE_RE = re.compile(
    r"\b(?:on|from|to|till|until|by|between|after|before|leav(?:e|ing)|depart(?:ing|ure)?|"
    r"return(?:ing)?|back|arriv(?:e|ing|al)|travell?(?:ing)?|fly(?:ing)?|start(?:ing)?|"
    r"begin(?:ning)?|check[\s-]?(?:in|out)|dates?|nights?\s+from)\W{0,3}$",
    re.I,
)
# "14 to 25 August 2026" / "14-25 Aug" — one month shared by both days.
_DAY_RANGE_RE = re.compile(
    rf"\b(?P<a>\d{{1,2}}){_ORDINAL}\s*(?:-|–|to|until|till)\s*(?P<b>\d{{1,2}}){_ORDINAL}"
    rf"\s+(?P<m>{_MONTH_ALT})(?:[\s,]+(?P<y>\d{{4}}))?\b",
    re.I,
)

# "for 2 people", "2 adults", "we are 3", "3 passengers", "4 guests"
_PAX_RE = re.compile(
    r"\b(?:for\s+)?(\d{1,2})\s*(?:adults?|persons?|people|passengers?|pax|travell?ers?|guests?)\b"
    r"|\bfor\s+(\d{1,2})\s*(?:of\s+us)?\b",
    re.I,
)
# "2 adults and 2 children" is FOUR seats. _PAX_RE stops at the first match, so
# it read that party as 2 — and the fare is per-seat x passengers, so the whole
# package was priced for half the group.
_KIDS = r"(?:child(?:ren)?|kids?|infants?)"
_ADULTS_KIDS_RE = re.compile(
    rf"\b(\d{{1,2}})\s*adults?\b[^\n.]{{0,24}}?\b(\d{{1,2}})\s*{_KIDS}\b"
    rf"|\b(\d{{1,2}})\s*{_KIDS}\b[^\n.]{{0,24}}?\b(\d{{1,2}})\s*adults?\b",
    re.I,
)
_ROOMS_RE = re.compile(r"\b(\d{1,2})\s*rooms?\b", re.I)
_NIGHTS_RE = re.compile(r"\b(\d{1,2})\s*nights?\b", re.I)
# "budget 150000", "under 50k", "PKR 80,000", "80000 rupees"
_BUDGET_RE = re.compile(
    # The filler between the keyword and the number matters: "my budget IS
    # 300,000" and "Budget: 300,000" are how people actually write it, and
    # allowing only "of" meant both parsed as no budget at all — which silently
    # switched off every budget comparison downstream.
    r"\b(?:budget|under|below|within|max(?:imum)?|around|about|upto|up\s+to)\s*"
    r"(?:is|of|are|=|:|~)?\s*(?:around\s+|about\s+)?(?:pkr|rs\.?|rupees)?\s*([\d,]{3,12})\s*(k\b)?"
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
    # The transport the user EXPLICITLY asked for — "train" | "flight" | "".
    # Separate from `mode` because `mode` goes blank the moment a message names
    # more than one thing, and a Trip Planner message almost always names a
    # hotel alongside the transport ("by train, 4 star hotel"). That blanking is
    # right for `mode` (which drives prompt wording) and wrong for enforcement:
    # it silently discarded the one preference that decides which hub, and
    # therefore which transfer fare, the whole trip is priced on.
    transport_mode: str = ""
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


def _canonical_city(name: str) -> str:
    """The app's own canonical name for a city.

    "Naran" and "Kaghan" are ONE place, not two — as are Hunza/Karimabad and
    Swat/Mingora. Matching the raw alias made "Plan trip for Naran and Kaghan"
    read as a two-city route and set origin=Naran, destination=Kaghan: both
    ends of the same valley. Reuses CITY_ALIASES, the same mapping hotel
    search already canonicalises with.
    """
    return CITY_ALIASES.get(name.lower(), name.title())


def _cities_in(text: str) -> list[str]:
    """The DISTINCT places named in `text`, canonical and in order."""
    if not _CITY_RE or not text:
        return []
    seen: list[str] = []
    for m in _CITY_RE.finditer(text):
        name = _canonical_city(m.group(1))
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
    origin, destination = _canonical_city(from_m.group(1)), _canonical_city(to_m.group(1))
    # Canonical, so "from Naran to Kaghan" is correctly seen as one place and
    # falls through rather than becoming a route to itself.
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
    combined = _ADULTS_KIDS_RE.search(text or "")
    if combined:
        left = _int_or_none(combined.group(1) or combined.group(3))
        right = _int_or_none(combined.group(2) or combined.group(4))
        total = (left or 0) + (right or 0)
        if 1 <= total <= 12:
            return total
    for m in _PAX_RE.finditer(text or ""):
        value = _int_or_none(m.group(1) or m.group(2))
        if value and 1 <= value <= 10:
            return value
    return None


# ── Numbered answers to numbered questions ───────────────────────────────────
#
# The Trip Planner opens by asking for everything at once as a numbered list,
# and users answer it the same way. "4. 300,000" carries no keyword at all —
# only its POSITION says it's the budget, so the plain scanners can't see it
# and the package planner's budget verdict never ran.

_NUMBERED_ITEM_RE = re.compile(r"^\s*(\d{1,2})\s*[.)]\s*(.+?)\s*$", re.M)
_BUDGET_QUESTION_RE = re.compile(r"\bbudget|how much.*(?:spend|cost)|spend.*trip\b", re.I)
_BARE_AMOUNT_RE = re.compile(r"([\d][\d,]{2,11})\s*(k\b)?", re.I)


def _numbered_items(text: str) -> dict[int, str]:
    """The numbered rows of a list, keyed by their number."""
    return {
        int(number): body
        for number, body in _NUMBERED_ITEM_RE.findall(text or "")
        if number.isdigit()
    }


def _aligned_budget(question_text: str, answer_text: str) -> int | None:
    """The budget from a numbered answer whose numbered QUESTION asked for one."""
    questions = _numbered_items(question_text)
    answers = _numbered_items(answer_text)
    if not questions or not answers:
        return None
    for number, question in questions.items():
        if not _BUDGET_QUESTION_RE.search(question):
            continue
        answer = answers.get(number)
        if not answer:
            continue
        m = _BARE_AMOUNT_RE.search(answer)
        if not m:
            continue
        value = _int_or_none(m.group(1))
        if value is None:
            continue
        if m.group(2):        # "300k"
            value *= 1000
        # Same floor the keyword scanner uses: a real PKR trip budget is never
        # three digits, so a stray "300" can't become one.
        if value >= 1000:
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


def _resolve_year(day: int, month: int, year: int | None, today: date | None) -> date | None:
    """A written date as a real date — rolling a bare "14 August" to the next
    time it actually occurs rather than to a month already gone."""
    if year:
        try:
            return date(year, month, day)
        except ValueError:
            return None
    anchor = today or date.today()
    for candidate_year in (anchor.year, anchor.year + 1):
        try:
            parsed = date(candidate_year, month, day)
        except ValueError:
            continue
        if parsed >= anchor:
            return parsed
    return None


def _future_text_dates(text: str, today: date | None = None) -> list[str]:
    """Written dates in `text` that haven't already passed, in order."""
    out: list[str] = []

    def _keep(parsed: date | None) -> None:
        if not parsed or (today and parsed < today):
            return
        iso = parsed.isoformat()
        if iso not in out:
            out.append(iso)

    # "14 to 25 August" first: its leading day has no month of its own, so the
    # single-date pass would see only "25 August" and lose the check-in.
    consumed: list[tuple[int, int]] = []
    for m in _DAY_RANGE_RE.finditer(text or ""):
        month = _MONTHS.get(m.group("m").lower())
        year = int(m.group("y")) if m.group("y") else None
        if not month:
            continue
        _keep(_resolve_year(int(m.group("a")), month, year, today))
        _keep(_resolve_year(int(m.group("b")), month, year, today))
        consumed.append(m.span())

    for m in _TEXT_DATE_RE.finditer(text or ""):
        if any(start <= m.start() < end for start, end in consumed):
            continue
        month_name = m.group("m1") or m.group("m2")
        day_raw = m.group("d1") or m.group("d2")
        month = _MONTHS.get((month_name or "").lower())
        if not month or not day_raw:
            continue
        year = int(m.group("y")) if m.group("y") else None
        if (month_name or "").lower() in _AMBIGUOUS_MONTHS and not year:
            if not _DATE_CUE_RE.search((text or "")[:m.start()]):
                continue
        _keep(_resolve_year(int(day_raw), month, year, today))
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
    # Each user turn paired with the assistant turn it is answering, so a reply
    # that only makes sense against the question ("4. 300,000") can be read.
    answered_questions: list[str] = []
    pending = ""
    for m in messages:
        role = (m.get("role") or "").lower()
        content = m.get("content") or ""
        if role == "assistant":
            pending = content if isinstance(content, str) else ""
        elif role == "user":
            answered_questions.append(pending)
            pending = ""
    assistant_texts = [
        m.get("content") or "" for m in messages
        if (m.get("role") or "").lower() == "assistant"
    ]

    # Oldest first, so later statements overwrite earlier ones.
    for index, text in enumerate(user_texts):
        if not isinstance(text, str):
            continue
        question = answered_questions[index] if index < len(answered_questions) else ""
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
        # Transport is resolved on its OWN, so a hotel preference in the same
        # sentence can't erase it. Still ambiguous when BOTH are named — that's
        # a comparison ("flight or train?"), not a choice, so nothing is set and
        # the traveller is asked rather than guessed at. An earlier explicit
        # choice survives a later message that mentions no transport at all.
        transport_named = {
            name for name, rx in (("train", _TRAIN_MODE_RE), ("flight", _FLIGHT_MODE_RE))
            if rx.search(text)
        }
        if len(transport_named) == 1:
            state.transport_mode = next(iter(transport_named))
        cities = _cities_in(text)
        if len(cities) >= 2:
            routed = _origin_destination_in(text)
            state.origin, state.destination = routed or (cities[0], cities[1])
        elif len(cities) == 1 and not state.destination:
            state.destination = cities[0]
        # ISO first — it's unambiguous, and the written-date pass is only ever
        # needed for the turns where the user didn't type one.
        dates = _future_iso_dates(text, today) or _future_text_dates(text, today)
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
        budget = _budget_in(text) or _aligned_budget(question, text)
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


def transport_preference(
    user_message: str = "",
    history: list[dict] | None = None,
) -> str:
    """
    The transport the traveller EXPLICITLY asked for — "train", "flight", or ""
    when they haven't said or are comparing both.

    Deliberately not rendered into the prompt: the model already has the user's
    own words. This exists so the deterministic layer can ENFORCE the choice,
    which is what stops a Hunza train trip from being priced off the Gilgit
    hub (PKR 7,000) when it must leave from Rawalpindi (PKR 38,000).
    """
    return derive_state(history, user_message).transport_mode
