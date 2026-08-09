from __future__ import annotations
# PURPOSE: Turn this turn's raw search results into COMPLETE trip packages —
#          transport + hotel + hub transfer, priced and compared — instead of a
#          bare list of flights for the traveller to assemble themselves.
#
# Why this is code and not a prompt rule: a package total is money. Every other
# money path in this app is derived server-side precisely because a model asked
# to add up four figures will eventually get one wrong, quote a hotel's nightly
# rate as its stay total, or pair a price with the wrong row. The same reasoning
# that produced agents/deterministic_reply.py applies here, only more so — there
# the model was retyping one list, here it would be combining three.
#
# Everything shown is copied from a search result or computed from it. Nothing
# is inferred: a package never claims a star rating, an amenity or a breakfast
# the payload didn't carry, and the transfer leg only appears for a destination
# that genuinely has no airport/station of its own.

import json
import re
from dataclasses import dataclass, field

from services.northern_routes import (
    canonical_destination,
    hub_options_for,
    price_for_route,
)

# Mirrors the capacities quoted everywhere else in the app (Sedan 1-3, SUV 1-5,
# Van 6-9). Vehicle follows PARTY SIZE, not package tier — selling a family of
# four a Sedan to make a "budget" tier look cheaper would be selling them a car
# they don't fit in.
_VEHICLE_FOR_PAX = ((3, "Sedan"), (5, "SUV"), (9, "Van"))

_TIER_NAMES = ("Budget", "Standard", "Premium")
_MAX_ROWS = 6


def _vehicle_for(passengers: int) -> str:
    for limit, vehicle in _VEHICLE_FOR_PAX:
        if passengers <= limit:
            return vehicle
    return "Van"


def _num(value) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _money(value) -> str:
    return f"PKR {int(round(_num(value))):,}"


@dataclass
class TripPackage:
    """One complete, priced itinerary. Every figure traces to a search row."""

    tier: str
    transport: dict                 # a flight or train row, verbatim
    transport_kind: str             # "flight" | "train"
    transport_pkr: int
    hotel: dict                     # a hotel row, verbatim
    hotel_pkr: int
    nights: int
    transfer: dict | None = None    # {"vehicle","hub","destination","fare_pkr"}
    highlights: list[str] = field(default_factory=list)
    # The traveller's OPTIONAL return leg (hub -> origin) — set only once they
    # explicitly pick one from trip_selection.render_return_options; a plan
    # with no return_transport is exactly today's one-way trip, unchanged.
    # Unlike `transport` above (the RAW search row), this holds the FORMATTED
    # row (trip_selection._flight_rows/_train_rows output) — the same shape
    # trip_selection.confirmation_booking_payloads already reads for the
    # outbound leg via `options["transport"][pick]`, so no new field-mapping
    # is needed to build its booking payload, and its precomputed "label" is
    # reused as-is below rather than reconstructed from raw airline/flight
    # fields the formatted row doesn't carry.
    return_transport: dict | None = None
    return_transport_kind: str = ""
    return_transport_pkr: int = 0

    @property
    def total_pkr(self) -> int:
        transfer = int(self.transfer["fare_pkr"]) if self.transfer else 0
        return_pkr = int(self.return_transport_pkr or 0)
        return int(self.transport_pkr) + int(self.hotel_pkr) + transfer + return_pkr

    @property
    def transport_label(self) -> str:
        row = self.transport
        if self.transport_kind == "train":
            name = str(row.get("train_name") or "Train").strip()
            number = str(row.get("train_number") or "").strip()
            return f"{name} ({number})" if number else name
        airline = str(row.get("airline") or "").strip()
        number = str(row.get("flight_number") or "").strip()
        # Never translate a carrier code into a name — same rule as everywhere.
        return f"{airline} {number}".strip() or number or "Flight"

    @property
    def return_transport_label(self) -> str:
        return str((self.return_transport or {}).get("label") or "Return").strip()


# ── Reading the search payloads ──────────────────────────────────────────────

def _parse(result: str) -> dict | None:
    try:
        payload = json.loads(result)
    except (TypeError, ValueError):
        return None
    return payload if isinstance(payload, dict) else None


def _rows(payload: dict, key: str) -> list[dict]:
    rows = payload.get(key)
    return [r for r in rows if isinstance(r, dict)][:_MAX_ROWS] if isinstance(rows, list) else []


def _train_price(row: dict) -> int:
    """A train's price lives on its fare CLASSES; the cheapest is the quote."""
    classes = [c for c in (row.get("classes") or []) if isinstance(c, dict)]
    prices = [_num(c.get("total_price_pkr")) for c in classes]
    prices = [p for p in prices if p > 0]
    if prices:
        return int(round(min(prices)))
    return int(round(_num(row.get("total_price_pkr"))))


def _transport_price(row: dict, kind: str) -> int:
    if kind == "train":
        return _train_price(row)
    return int(round(_num(row.get("total_price_pkr"))))


def _collect(gathered: list[tuple[str, str]]) -> tuple[list[dict], str, dict, list[dict], dict]:
    """Pull the transport rows, hotel rows and their payloads out of a turn."""
    transport: list[dict] = []
    transport_kind = ""
    transport_payload: dict = {}
    hotels: list[dict] = []
    hotel_payload: dict = {}
    for name, result in gathered or []:
        payload = _parse(result)
        if not payload:
            continue
        if name == "search_flights" and not transport:
            rows = _rows(payload, "flights")
            if rows:
                transport, transport_kind, transport_payload = rows, "flight", payload
        elif name == "search_trains" and not transport:
            rows = _rows(payload, "trains")
            if rows:
                transport, transport_kind, transport_payload = rows, "train", payload
        elif name == "search_hotels" and not hotels:
            rows = _rows(payload, "hotels")
            if rows:
                hotels, hotel_payload = rows, payload
    return transport, transport_kind, transport_payload, hotels, hotel_payload


def missing_for_package(gathered: list[tuple[str, str]], destination: str) -> list[str]:
    """
    What a trip-planner turn still needs before packages can be built — [] when
    it needs nothing, or when this isn't a trip-planner turn at all.

    Used to push the model back for the search it skipped. Searching only
    flights is exactly what makes the Trip Planner behave like the flight
    module: the turn then has nothing to combine, so it falls back to listing
    parts. This names the gap instead of letting that happen silently.
    """
    if hub_options_for(destination) is None:
        return []
    transport, _, _, hotels, _ = _collect(gathered)
    if not transport and not hotels:
        return []                      # nothing searched yet — not our business
    missing = []
    if not transport:
        missing.append("transport to the hub (search_flights or search_trains)")
    if not hotels:
        missing.append(f"hotels in {canonical_destination(destination)} (search_hotels)")
    return missing


def can_build(gathered: list[tuple[str, str]], destination: str) -> bool:
    """
    True when this turn holds everything a complete package needs: a recognised
    trip-planner destination, at least one transport option, and at least one
    hotel. Anything less is not a package and must not be rendered as one.
    """
    if hub_options_for(destination) is None:
        return False
    transport, _, _, hotels, _ = _collect(gathered)
    return bool(transport and hotels)


# ── Composition ──────────────────────────────────────────────────────────────

def _transfer_for(destination: str, passengers: int, mode: str = "") -> dict | None:
    """The hub->destination car leg, when the destination has no airport of its
    own. Priced from the real route table, never estimated.

    The hub must match how they're TRAVELLING: Naran's flight hub is Islamabad
    but its train hub is Rawalpindi, and a train traveller collected from the
    airport they never landed at is a driver sent to the wrong city.
    """
    hubs = hub_options_for(destination)
    if not hubs:                      # None = not northern; [] = has its own airport
        return None
    canonical = canonical_destination(destination)
    vehicle = _vehicle_for(passengers)
    # Hubs for this mode first, then any as a fallback.
    ordered = [h for h in hubs if h.mode == mode] + [h for h in hubs if h.mode != mode]
    for hub in ordered:
        fare = price_for_route(hub.hub_city, canonical, vehicle)
        if fare:
            return {
                "vehicle": vehicle,
                "hub": hub.hub_city,
                "destination": canonical,
                "fare_pkr": int(fare),
            }
    return None


def _stars(hotel: dict) -> float:
    return _num(hotel.get("stars"))


def _highlights(pkg: TripPackage, cheapest_total: int, best_stars: float) -> list[str]:
    """Only facts the payload actually carries."""
    out: list[str] = []
    if pkg.total_pkr == cheapest_total:
        out.append("Lowest total")
    stars = _stars(pkg.hotel)
    if stars and stars >= best_stars:
        out.append(f"Highest-rated stay ({stars:g}★)")
    score = pkg.hotel.get("review_score")
    if isinstance(score, (int, float)) and score:
        # review_score arrives on whichever scale its provider uses — Google
        # Places rates out of 5, Booking-style feeds out of 10 — so a fixed
        # "/10" printed a 4.3/5 hotel (excellent) as 4.3/10 (dire), steering
        # travellers away from the package they should pick. Read the scale off
        # the value rather than asserting one.
        out.append(f"Guest score {score:g}/{5 if score <= 5 else 10}")
    if pkg.hotel.get("breakfast_included"):
        out.append("Breakfast included")
    return out[:3]


def build(gathered: list[tuple[str, str]], destination: str) -> list[TripPackage]:
    """
    Compose up to three complete packages, cheapest first.

    Tiers are assigned by TOTAL COST POSITION (cheapest / middle / dearest of
    the real combinations available), so the label always describes something
    true about the price rather than a quality claim the data can't support.
    The "why" lines beside each are separate, and are only ever copied facts.
    """
    transport, kind, transport_payload, hotels, hotel_payload = _collect(gathered)
    if not transport or not hotels:
        return []

    passengers = int(_num(transport_payload.get("passengers")) or _num(hotel_payload.get("guests")) or 1)
    nights = int(_num(hotel_payload.get("nights")))
    transfer = _transfer_for(destination, passengers, kind)

    combos: list[TripPackage] = []
    for t_row in transport:
        t_price = _transport_price(t_row, kind)
        if t_price <= 0:
            continue
        for h_row in hotels:
            h_price = int(round(_num(h_row.get("total_stay_pkr"))))
            if h_price <= 0:
                continue
            combos.append(TripPackage(
                tier="", transport=t_row, transport_kind=kind, transport_pkr=t_price,
                hotel=h_row, hotel_pkr=h_price, nights=nights,
                transfer=dict(transfer) if transfer else None,
            ))
    if not combos:
        return []

    combos.sort(key=lambda p: p.total_pkr)
    # Cheapest, dearest, and the one nearest the midpoint — three genuinely
    # different itineraries rather than three near-identical ones.
    chosen: list[TripPackage] = [combos[0]]
    if len(combos) > 1:
        chosen.append(combos[-1])
    if len(combos) > 2:
        midpoint = (combos[0].total_pkr + combos[-1].total_pkr) / 2
        middle = min(combos[1:-1], key=lambda p: abs(p.total_pkr - midpoint))
        chosen.append(middle)
    chosen.sort(key=lambda p: p.total_pkr)

    cheapest_total = chosen[0].total_pkr
    best_stars = max((_stars(p.hotel) for p in chosen), default=0.0)
    for tier, pkg in zip(_TIER_NAMES, chosen):
        pkg.tier = tier
        pkg.highlights = _highlights(pkg, cheapest_total, best_stars)
    return chosen


# ── Rendering ────────────────────────────────────────────────────────────────

def _recommendation(packages: list[TripPackage], budget_pkr) -> str:
    """Compare the packages to the stated budget, and say WHY."""
    budget = _num(budget_pkr)
    if budget <= 0:
        cheapest = packages[0]
        return (
            f"My pick is **{cheapest.tier}** at {_money(cheapest.total_pkr)} — "
            "it covers the whole trip for the least. Tell me your budget and I'll "
            "narrow it down properly."
        )
    within = [p for p in packages if p.total_pkr <= budget]
    if within:
        best = within[-1]        # the most the budget genuinely affords
        line = (
            f"Against your budget of {_money(budget)}, **{best.tier}** is my pick at "
            f"{_money(best.total_pkr)} — the most complete option that still fits, "
            f"leaving {_money(budget - best.total_pkr)} spare."
        )
        over = [p for p in packages if p.total_pkr > budget]
        if over:
            line += " " + "; ".join(
                f"{p.tier} is over by {_money(p.total_pkr - budget)}" for p in over
            ) + "."
        return line
    closest = packages[0]
    others = "; ".join(
        f"{p.tier} by {_money(p.total_pkr - budget)}" for p in packages[1:]
    )
    line = (
        f"None of these fit a budget of {_money(budget)}. **{closest.tier}** comes "
        f"closest at {_money(closest.total_pkr)} — over by "
        f"{_money(closest.total_pkr - budget)}."
    )
    if others:
        line += f" The others are further out: {others}."
    return line


def render(packages: list[TripPackage], destination: str, budget_pkr=None) -> str:
    """
    The traveller-facing package list.

    Deliberately a NUMBERED list with prices: that is the shape the rest of the
    pipeline recognises as selectable offers (prompt_builder._looks_like_offer_list),
    so "2" or "package 2" flows into the ordinary pick path. Each line also names
    the flight number and hotel by name, so the pick can be turned back into
    real booking components.
    """
    if not packages:
        return ""
    canonical = canonical_destination(destination) or destination
    lines = [
        f"Here {'is' if len(packages) == 1 else 'are'} "
        f"{len(packages)} complete package{'' if len(packages) == 1 else 's'} "
        f"for {canonical} — each one covers everything end to end:"
    ]
    for i, pkg in enumerate(packages, start=1):
        lines.append("")
        lines.append(f"{i}. **{pkg.tier} — {_money(pkg.total_pkr)} total**")
        lines.append(
            f"   ✈️ {pkg.transport_label} — {_money(pkg.transport_pkr)}"
            if pkg.transport_kind == "flight" else
            f"   🚆 {pkg.transport_label} — {_money(pkg.transport_pkr)}"
        )
        name = str(pkg.hotel.get("name") or "Hotel").strip()
        stars = _stars(pkg.hotel)
        star_txt = f" {stars:g}★" if stars else ""
        nights_txt = f" · {pkg.nights} night{'s' if pkg.nights != 1 else ''}" if pkg.nights else ""
        lines.append(f"   🏨 {name}{star_txt}{nights_txt} — {_money(pkg.hotel_pkr)}")
        if pkg.transfer:
            t = pkg.transfer
            lines.append(
                f"   🚗 {t['hub']} → {t['destination']} by {t['vehicle']} — "
                f"{_money(t['fare_pkr'])}"
            )
        if pkg.highlights:
            lines.append(f"   _{' · '.join(pkg.highlights)}_")
    lines.append("")
    lines.append(_recommendation(packages, budget_pkr))
    lines.append("")
    lines.append(
        "Tell me which package number you'd like and I'll set the whole trip up "
        "as one booking with a single payment."
    )
    return "\n".join(lines)


# ── Reading a rendered package list back ─────────────────────────────────────
#
# When the traveller answers "package 2", that pick has to become the RIGHT
# flight, the RIGHT hotel and the RIGHT transfer. Left to the model, this is
# where a package quietly turns back into a parts list: it re-reads its own
# prose, picks a neighbouring row, drops the car leg, or re-prices from memory.
#
# So the pick is resolved the same way confirmed_components resolves a paid
# booking — by parsing OUR OWN rendered text, whose shape we control, rather
# than trusting a re-reading of it. The components then go to the model as a
# flat instruction, and the existing atomic package + completeness gates make
# sure all of them reach one checkout together.

_PKG_HEAD_RE = re.compile(r"^\s*(\d{1,2})\.\s+\*\*(.+?)\s+—\s+PKR\s+([\d,]+)\s+total\*\*", re.M)
_PKG_TRANSPORT_RE = re.compile(r"(✈️|🚆)\s*(.+?)\s+—\s+PKR\s+([\d,]+)")
_PKG_HOTEL_RE = re.compile(
    r"🏨\s*(.+?)(?:\s+([\d.]+)★)?(?:\s+·\s+(\d+)\s+nights?)?\s+—\s+PKR\s+([\d,]+)")
_PKG_TRANSFER_RE = re.compile(r"🚗\s*(.+?)\s+→\s+(.+?)\s+by\s+(\w+)\s+—\s+PKR\s+([\d,]+)")
# A flight code as it appears inside a carrier label ("Airblue PA911" -> PA911).
_FLIGHT_CODE_RE = re.compile(r"\b([A-Z]{2}\s?-?\d{2,4})\b")


def _int(text: str) -> int:
    try:
        return int(str(text).replace(",", "").strip())
    except (TypeError, ValueError):
        return 0


def parse_rendered(text: str) -> dict[int, dict]:
    """Recover {package_number: component detail} from a rendered package list."""
    text = text or ""
    heads = list(_PKG_HEAD_RE.finditer(text))
    if not heads:
        return {}
    out: dict[int, dict] = {}
    for i, head in enumerate(heads):
        # This package's block runs to the start of the next one.
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        block = text[head.end():end]
        pkg: dict = {
            "tier": head.group(2).strip(),
            "total_pkr": _int(head.group(3)),
        }
        transport = _PKG_TRANSPORT_RE.search(block)
        if transport:
            label = transport.group(2).strip()
            pkg["transport_kind"] = "flight" if transport.group(1) == "✈️" else "train"
            pkg["transport_label"] = label
            pkg["transport_pkr"] = _int(transport.group(3))
            code = _FLIGHT_CODE_RE.search(label)
            if pkg["transport_kind"] == "flight" and code:
                pkg["flight_number"] = code.group(1).replace(" ", "").replace("-", "")
            else:
                pkg["train_name"] = label
        hotel = _PKG_HOTEL_RE.search(block)
        if hotel:
            pkg["hotel_name"] = hotel.group(1).strip()
            if hotel.group(2):
                pkg["hotel_stars"] = hotel.group(2)
            if hotel.group(3):
                pkg["nights"] = _int(hotel.group(3))
            pkg["hotel_pkr"] = _int(hotel.group(4))
        transfer = _PKG_TRANSFER_RE.search(block)
        if transfer:
            pkg["transfer_hub"] = transfer.group(1).strip()
            pkg["transfer_destination"] = transfer.group(2).strip()
            pkg["transfer_vehicle"] = transfer.group(3).strip()
            pkg["transfer_pkr"] = _int(transfer.group(4))
        out[_int(head.group(1))] = pkg
    return out


def find_rendered(history: list[dict] | None) -> dict[int, dict]:
    """The most recent package list this conversation showed, parsed."""
    for m in reversed(list(history or [])):
        if (m.get("role") or "").lower() != "assistant":
            continue
        content = m.get("content")
        if not isinstance(content, str):
            continue
        packages = parse_rendered(content)
        if packages:
            return packages
    return {}


def selection_instruction(picked: dict) -> str:
    """
    The flat, unambiguous brief for booking ONE chosen package.

    Names every component and tells the model to prepare them in a single
    reply, because that is what makes them one checkout with one payment.
    """
    parts: list[str] = []
    if picked.get("flight_number"):
        parts.append(
            f"the FLIGHT {picked['flight_number']} (shown at PKR "
            f"{picked.get('transport_pkr', 0):,})"
        )
    elif picked.get("train_name"):
        parts.append(f"the TRAIN {picked['train_name']}")
    if picked.get("hotel_name"):
        nights = picked.get("nights")
        stay = f" for {nights} nights" if nights else ""
        parts.append(f"the HOTEL \"{picked['hotel_name']}\"{stay}")
    lines = [
        f"PACKAGE PICKED: \"{picked.get('tier', '')}\" — total PKR "
        f"{picked.get('total_pkr', 0):,}. This is ONE trip, not separate bookings.",
        "Call prepare_booking for " + " AND ".join(parts) + " in this SAME reply — "
        "one call each, together, so they become a single checkout with one "
        "passenger form and one payment.",
    ]
    if picked.get("transfer_vehicle"):
        lines.append(
            f"On the {'flight' if picked.get('flight_number') else 'train'} call "
            f"ALSO set transfer_vehicle_type=\"{picked['transfer_vehicle']}\" and "
            f"transfer_dropoff_location=\"{picked.get('transfer_destination', '')}\", "
            f"and ask the traveller only for the pickup address at "
            f"{picked.get('transfer_hub', 'the hub')} if you don't already have it. "
            "Do NOT use book_car — the car is part of this package."
        )
    lines.append(
        "Do not re-list options, do not re-price anything, and do not prepare "
        "only part of it."
    )
    return " ".join(lines)
