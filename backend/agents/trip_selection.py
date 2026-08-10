from __future__ import annotations
# PURPOSE: The INTERACTIVE Trip Planner — show the real flight/train, hotel and
#          transfer options, let the traveller choose each one, then compose
#          exactly those choices into a single priced trip.
#
# This replaces auto-composed Budget/Standard/Premium tiers as the primary flow.
# Tiers picked the flight, the hotel and the vehicle on the traveller's behalf
# to make a package; here every one of those is theirs to choose, and the app's
# job is to present real options, explain them, and add them up.
#
# Why this is code and not a prompt rule — the same reason as trip_package and
# deterministic_reply: the numbers are money. Every price shown is copied from a
# search row or the northern_routes fare table, the total is summed here, and
# the payment server re-verifies it. The model never re-prices, never picks a
# component, and never fills a gap it can't see.
#
# STATE. A selection spans several turns ("Flight 2" ... "Hotel 1" ... "SUV")
# and this app keeps no per-conversation scratch space. So the rendered block
# carries its own state: every option is written out, and the picks so far are
# written on a `_Selected:` line. Reading the last rendered block back recovers
# the whole selection exactly — the same render-then-parse-our-own-output trick
# trip_package.parse_rendered uses, which is what makes a pick survive a turn
# without trusting the model to remember it.

import re
from dataclasses import dataclass, field
from datetime import date, timedelta

from agents.clarification_agent import CITY_TO_IATA
from agents.trip_package import TripPackage, _collect, _num, _money
from services.northern_routes import (
    NORTHERN_DESTINATIONS,
    canonical_destination,
    fare_is_estimated,
    hub_options_for,
    names_destination,
    price_for_route,
)

# Shown beside any fare we cannot attribute to a source. Never hidden in a
# comment: a price the traveller is asked to pay has to say what it is.
_ESTIMATED_TAG = " (Estimated)"

# Capacities as quoted everywhere else in the app (agent_tools' book_car schema,
# the Flutter car form): Sedan 1-3, SUV 1-5, Van 6-9. A vehicle the party does
# not fit in is not an option, so it is never offered.
_VEHICLE_CAPACITY: tuple[tuple[str, int, int], ...] = (
    ("Sedan", 1, 3),
    ("SUV", 1, 5),
    ("Van", 6, 9),
)

_FLIGHTS_HEAD = "**AVAILABLE FLIGHTS**"
_TRAINS_HEAD = "**AVAILABLE TRAINS**"
_HOTELS_HEAD = "**AVAILABLE HOTELS**"
_TRANSFERS_HEAD = "**AVAILABLE TRANSFERS**"
_PLAN_HEAD = "**YOUR TRIP PLAN"
_SELECTED_LINE = "_Selected so far:"

_MAX_ROWS = 6


# ── Options ──────────────────────────────────────────────────────────────────

def vehicles_for(passengers: int) -> list[str]:
    """The vehicles that can actually carry this party, largest choice first.

    Offering a Sedan to five travellers is offering a car they cannot board;
    offering a Van to two is quoting a fare for space they aren't using. Both
    are filtered out rather than shown and later corrected.
    """
    pax = max(int(passengers or 1), 1)
    return [name for name, lo, hi in _VEHICLE_CAPACITY if lo <= pax <= hi]


def transfer_options(destination: str, passengers: int, mode: str = "") -> list[dict]:
    """
    The real hub->destination car options, priced from the route table.

    The hub must match how they are TRAVELLING. Gilgit has an airport but no
    railway station, so a train traveller collected at Gilgit is a driver sent
    to a platform that does not exist — hubs are filtered by mode first.
    """
    hubs = hub_options_for(destination)
    if not hubs:              # None = not northern; [] = has its own airport
        return []
    canonical = canonical_destination(destination)
    ordered = [h for h in hubs if h.mode == mode] or list(hubs)
    for hub in ordered:
        rows: list[dict] = []
        for vehicle in vehicles_for(passengers):
            fare = price_for_route(hub.hub_city, canonical, vehicle)
            if fare:
                rows.append({
                    "vehicle": vehicle,
                    "hub": hub.hub_city,
                    "destination": canonical,
                    "fare_pkr": int(fare),
                    "estimated": fare_is_estimated(hub.hub_city, canonical, vehicle),
                    "note": hub.duration_hint,
                })
        if rows:
            return rows
    return []


# Flight results carry AIRPORT codes ("KHI", "GIL") because that is what the
# search API speaks. Showing a traveller "KHI → GIL" asks them to know IATA to
# read their own itinerary. Display-only: the raw row is kept verbatim under
# "row", and nothing booked, priced or emailed reads this.
_IATA_TO_CITY = {code.upper(): city.title() for city, code in CITY_TO_IATA.items()}


def _place(value) -> str:
    name = str(value or "").strip()
    return _IATA_TO_CITY.get(name.upper(), name)


def _flight_rows(rows: list[dict]) -> list[dict]:
    out = []
    for r in rows[:_MAX_ROWS]:
        price = int(round(_num(r.get("total_price_pkr"))))
        if price <= 0:
            continue
        out.append({
            "kind": "flight",
            "label": f"{str(r.get('airline') or '').strip()} "
                     f"{str(r.get('flight_number') or '').strip()}".strip(),
            "flight_number": str(r.get("flight_number") or "").strip(),
            "origin": _place(r.get("from")),
            "destination": _place(r.get("to")),
            "depart": str(r.get("depart") or "").strip(),
            "arrive": str(r.get("arrive") or "").strip(),
            "cabin": str(r.get("cabin") or "").strip(),
            "price_pkr": price,
            "row": r,
        })
    return out


def _train_rows(rows: list[dict]) -> list[dict]:
    """One selectable row per train CLASS.

    A train's fare classes are genuinely different products at genuinely
    different prices, so collapsing them to the cheapest was choosing a class
    for the traveller. Each class is its own option instead.
    """
    out = []
    for r in rows[:_MAX_ROWS]:
        name = str(r.get("train_name") or "Train").strip()
        number = str(r.get("train_number") or "").strip()
        for cls in (r.get("classes") or []):
            if not isinstance(cls, dict):
                continue
            price = int(round(_num(cls.get("total_price_pkr"))))
            if price <= 0:
                continue
            out.append({
                "kind": "train",
                "label": f"{name} ({number})" if number else name,
                "train_name": name,
                "train_number": number,
                "travel_class": str(cls.get("class") or "").strip(),
                "origin": str(r.get("from") or "").strip(),
                "destination": str(r.get("to") or "").strip(),
                "depart": str(r.get("depart") or "").strip(),
                "arrive": str(r.get("arrive") or "").strip(),
                "price_pkr": price,
                "row": r,
            })
    return out[:_MAX_ROWS]


def _hotel_rows(rows: list[dict], nights: int) -> list[dict]:
    out = []
    for r in rows[:_MAX_ROWS]:
        price = int(round(_num(r.get("total_stay_pkr"))))
        if price <= 0:
            continue
        out.append({
            "kind": "hotel",
            "name": str(r.get("name") or "Hotel").strip(),
            "stars": _num(r.get("stars")),
            "nights": nights,
            "price_pkr": price,
            "row": r,
        })
    return out


_SEARCH_FOR_MODE = {"flight": "search_flights", "train": "search_trains"}


def _only_preferred_transport(gathered, preferred_mode: str):
    """
    This turn's results with the transport the traveller DIDN'T ask for removed.

    _collect takes whichever transport it meets first, and that order is the
    order the model happened to emit its calls — so with both modes present the
    same request could compose a flight trip or a train trip, off different
    hubs, at different prices. Filtering here means the mode is decided by the
    traveller and never by call order.
    """
    unwanted = {
        search for mode, search in _SEARCH_FOR_MODE.items()
        if mode != preferred_mode
    } if preferred_mode in _SEARCH_FOR_MODE else set()
    return [(n, r) for n, r in (gathered or []) if n not in unwanted]


def preferred_transport_missing(gathered, preferred_mode: str) -> str:
    """
    The mode that DOES have results when the requested one has none — or "".

    Answers the one question C exists for: may we switch? The answer is never
    "yes, silently". Returning the alternative lets the caller name it and ask.
    """
    if preferred_mode not in _SEARCH_FOR_MODE:
        return ""
    wanted, _, _, _, _ = _collect(_only_preferred_transport(gathered, preferred_mode))
    if wanted:
        return ""
    other = "train" if preferred_mode == "flight" else "flight"
    alternative, _, _, _, _ = _collect(_only_preferred_transport(gathered, other))
    return other if alternative else ""


def no_preferred_transport_message(preferred_mode: str, alternative: str) -> str:
    """Say the requested mode isn't there, and ASK — never switch on their behalf."""
    return (
        f"I don't have any {preferred_mode} options for this route right now.\n\n"
        f"I haven't switched you to a {alternative} automatically — that's your "
        f"call, not mine. Would you like me to search {alternative}s instead?"
    )


def build_options(
    gathered, destination: str, passengers: int = 0, preferred_mode: str = "",
) -> dict:
    """
    Everything this turn found, as selectable options — or {} when there is not
    enough to offer. Only categories that genuinely apply are included.

    `preferred_mode` is the transport the traveller explicitly asked for; the
    other mode's results are dropped before composition so they can never be
    picked up by accident. See _only_preferred_transport.
    """
    if hub_options_for(destination) is None:
        return {}
    gathered = _only_preferred_transport(gathered, preferred_mode)
    transport, kind, transport_payload, hotels, hotel_payload = _collect(gathered)
    if not transport or not hotels:
        return {}

    pax = int(
        passengers
        or _num(transport_payload.get("passengers"))
        or _num(hotel_payload.get("guests"))
        or 1
    )
    nights = int(_num(hotel_payload.get("nights")))
    options: dict = {
        "destination": canonical_destination(destination),
        "passengers": pax,
        "nights": nights,
        "transport_kind": kind,
        "transport": _flight_rows(transport) if kind == "flight" else _train_rows(transport),
        "hotels": _hotel_rows(hotels, nights),
        "transfers": transfer_options(destination, pax, kind),
        "picks": {},
    }
    if not options["transport"] or not options["hotels"]:
        return {}
    return options


def can_offer(gathered, destination: str, preferred_mode: str = "") -> bool:
    return bool(build_options(gathered, destination, preferred_mode=preferred_mode))


def merge_fresh_search(
    existing_options: dict, gathered, *, passengers: int = 0, preferred_mode: str = "",
) -> dict:
    """
    A turn that only refreshes ONE category — "I want business class
    flights" re-searches transport but never touches hotels, "only 5-star
    hotels" is the reverse — still has to end with a single, internally
    consistent options block. Without this, build_options() sees only
    THIS turn's gathered results, finds one category missing, and returns
    {} — so the deterministic renderer bows out and the model writes its
    own prose from the fresh data instead. That prose is accurate (real
    search results), but it never updates the SAVED planner state, which
    silently keeps offering the OLD category: the traveller reads fresh
    business-class prices and then books the economy fare underneath them.

    Layers this turn's fresh category (if any) onto a COPY of
    `existing_options` — the block already active for this destination —
    rather than requiring everything to be re-searched at once. Returns {}
    when there's nothing usable to merge (build_options() already handles
    the "everything is fresh" case; this only covers a partial refresh on
    top of an already-active block) or when `existing_options` itself is
    empty (nothing to refine).

    Picks are always cleared on a successful merge: a refreshed category's
    rows can renumber, and a stale pick pointing at what is now a
    different row would silently misbook — see master_agent.py's caller.
    """
    if not existing_options:
        return {}
    destination = existing_options.get("destination") or ""
    gathered = _only_preferred_transport(gathered, preferred_mode)
    transport, kind, transport_payload, hotels, hotel_payload = _collect(gathered)
    if not transport and not hotels:
        return {}
    merged = dict(existing_options)
    if transport:
        pax = int(
            passengers
            or _num(transport_payload.get("passengers"))
            or existing_options.get("passengers") or 1
        )
        merged["transport_kind"] = kind
        merged["transport"] = _flight_rows(transport) if kind == "flight" else _train_rows(transport)
        merged["passengers"] = pax
        # Transfers depend on transport kind/passengers, so a transport
        # refresh recomputes them too — the hub, vehicle set or fares could
        # all shift with a different mode or party size.
        merged["transfers"] = transfer_options(destination, pax, kind)
    if hotels:
        nights = int(_num(hotel_payload.get("nights"))) or existing_options.get("nights") or 0
        merged["nights"] = nights
        merged["hotels"] = _hotel_rows(hotels, nights)
    if not merged.get("transport") or not merged.get("hotels"):
        return {}
    merged["picks"] = {}
    return merged


# ── Rendering the options ────────────────────────────────────────────────────

def _pick_suffix(options: dict, category: str, index: int) -> str:
    return "  ← selected" if options.get("picks", {}).get(category) == index else ""


def render_options(options: dict) -> str:
    """The traveller-facing option lists. Numbered, priced, one per category."""
    if not options:
        return ""
    picks = options.get("picks") or {}
    dest = options.get("destination") or ""
    pax = options.get("passengers") or 1
    lines: list[str] = [
        f"Here's everything available for your {dest} trip — "
        f"{pax} traveller{'s' if pax != 1 else ''}. Pick one from each list:"
    ]

    transport = options.get("transport") or []
    if transport:
        is_flight = options.get("transport_kind") == "flight"
        lines += ["", _FLIGHTS_HEAD if is_flight else _TRAINS_HEAD]
        for i, row in enumerate(transport, start=1):
            route = f"{row['origin']} → {row['destination']}" if row.get("origin") else ""
            when = f"{row.get('depart', '')[-5:]} → {row.get('arrive', '')[-5:]}".strip(" →")
            extra = row.get("cabin") or row.get("travel_class") or ""
            parts = [p for p in (route, when, extra) if p]
            lines.append(
                f"{i}. {row['label']}"
                + (" · " + " · ".join(parts) if parts else "")
                + f" — {_money(row['price_pkr'])}"
                + _pick_suffix(options, "transport", i)
            )

    hotels = options.get("hotels") or []
    if hotels:
        lines += ["", _HOTELS_HEAD]
        for i, row in enumerate(hotels, start=1):
            stars = f" · {row['stars']:g}★" if row.get("stars") else ""
            nights = row.get("nights") or 0
            nights_txt = f" · {nights} night{'s' if nights != 1 else ''}" if nights else ""
            lines.append(
                f"{i}. {row['name']}{stars}{nights_txt} — {_money(row['price_pkr'])}"
                + _pick_suffix(options, "hotel", i)
            )

    transfers = options.get("transfers") or []
    if transfers:
        lines += ["", _TRANSFERS_HEAD]
        for i, row in enumerate(transfers, start=1):
            # The tag sits AFTER the amount, where _ROW_RE (which captures the
            # body up to "— PKR") never looks — so labelling costs no parsing
            # change and the flag is re-derived from route data on the way back.
            lines.append(
                f"{i}. {row['vehicle']} · {row['hub']} → {row['destination']}"
                f" — {_money(row['fare_pkr'])}"
                + (_ESTIMATED_TAG if row.get("estimated") else "")
                + _pick_suffix(options, "transfer", i)
            )
        if len(transfers) == 1:
            only = transfers[0]
            lines.append(
                f"   _{only['vehicle']} is the only vehicle that seats "
                f"{options.get('passengers', 1)} — the others don't fit your party._"
            )

    if picks:
        lines += ["", _selected_line(picks)]
    lines += ["", _next_prompt(options)]
    return "\n".join(lines)


def _selected_line(picks: dict) -> str:
    order = (("transport", "Transport"), ("hotel", "Hotel"), ("transfer", "Transfer"))
    named = [f"{label} {picks[key]}" for key, label in order if picks.get(key)]
    return f"{_SELECTED_LINE} {' · '.join(named)}_" if named else ""


def outstanding(options: dict, picks: dict | None = None) -> list[str]:
    """Categories that still need a choice, in the order they're asked for."""
    picks = options.get("picks") if picks is None else picks
    picks = picks or {}
    todo = []
    if options.get("transport") and not picks.get("transport"):
        todo.append("transport")
    if options.get("hotels") and not picks.get("hotel"):
        todo.append("hotel")
    if options.get("transfers") and not picks.get("transfer"):
        todo.append("transfer")
    return todo


def _next_prompt(options: dict) -> str:
    todo = outstanding(options)
    if not todo:
        return "That's everything selected."
    word = {
        "transport": "flight" if options.get("transport_kind") == "flight" else "train",
        "hotel": "hotel",
        "transfer": "transfer",
    }
    named = [word[t] for t in todo]
    if len(named) == 1:
        return f"Which {named[0]} would you like? Reply with its number."
    example = ", ".join(f"{n.capitalize()} 1" for n in named)
    return (
        f"Tell me your {', '.join(named[:-1])} and {named[-1]} — all at once "
        f"(\"{example}\") or one at a time."
    )


def complete(options: dict, picks: dict | None = None) -> bool:
    return bool(options) and not outstanding(options, picks)


# ── Reading a rendered block back ────────────────────────────────────────────

# The opening line carries the destination and party size — the two facts the
# rows themselves don't, and both are needed to rebuild the plan a turn later.
_HEADER_RE = re.compile(r"available for your (.+?) trip — (\d{1,2}) traveller", re.I)
_ROW_RE = re.compile(r"^\s*(\d{1,2})\.\s+(.+?)\s+—\s+PKR\s+([\d,]+)", re.M)
_SELECTED_RE = re.compile(
    r"_Selected so far:\s*(.+?)_", re.I)
_SELECTED_ITEM_RE = re.compile(r"\b(transport|hotel|transfer)\s+(\d{1,2})\b", re.I)
_FLIGHT_CODE_RE = re.compile(r"\b([A-Z]{2}\s?-?\d{2,4})\b")
_STARS_RE = re.compile(r"·\s*([\d.]+)★")
_NIGHTS_RE = re.compile(r"·\s*(\d+)\s+nights?")
_TRANSFER_RE = re.compile(r"^(\w+)\s+·\s+(.+?)\s+→\s+(.+)$")
_ROUTE_RE = re.compile(r"·\s*([A-Za-z .'-]+?)\s+→\s+([A-Za-z .'-]+?)\s*(?:·|$)")
# Departure/arrival must survive the round trip too, or the list silently loses
# its times the moment it's re-rendered with a selection marked on it.
_TIME_RE = re.compile(r"\b(\d{1,2}:\d{2})\s*→\s*(\d{1,2}:\d{2})\b")


def _int(text) -> int:
    try:
        return int(str(text).replace(",", "").strip())
    except (TypeError, ValueError):
        return 0


def _section(text: str, head: str, *others: str) -> str:
    """The block of text under `head`, up to whichever other head comes next."""
    start = text.find(head)
    if start < 0:
        return ""
    start += len(head)
    ends = [text.find(o, start) for o in others]
    ends = [e for e in ends if e >= 0]
    return text[start:min(ends)] if ends else text[start:]


def parse_options(text: str) -> dict:
    """Recover the full option set (and the picks so far) from a rendered block."""
    text = text or ""
    heads = (_FLIGHTS_HEAD, _TRAINS_HEAD, _HOTELS_HEAD, _TRANSFERS_HEAD)
    if not any(h in text for h in heads):
        return {}

    is_flight = _FLIGHTS_HEAD in text
    transport_head = _FLIGHTS_HEAD if is_flight else _TRAINS_HEAD
    transport_block = _section(text, transport_head, *[h for h in heads if h != transport_head])
    hotel_block = _section(text, _HOTELS_HEAD, _TRANSFERS_HEAD)
    transfer_block = _section(text, _TRANSFERS_HEAD)

    transport: list[dict] = []
    for _num_, body, price in _ROW_RE.findall(transport_block):
        label = body.split(" · ")[0].strip()
        row: dict = {
            "kind": "flight" if is_flight else "train",
            "label": label,
            "price_pkr": _int(price),
        }
        route = _ROUTE_RE.search(body)
        if route:
            row["origin"] = route.group(1).strip()
            row["destination"] = route.group(2).strip()
        times = _TIME_RE.search(body)
        if times:
            row["depart"] = times.group(1)
            row["arrive"] = times.group(2)
        tail = [p.strip() for p in body.split(" · ") if p.strip()][1:]
        tail = [p for p in tail if not _TIME_RE.search(p) and "→" not in p]
        if is_flight:
            code = _FLIGHT_CODE_RE.search(label)
            if code:
                row["flight_number"] = code.group(1).replace(" ", "").replace("-", "")
            row["cabin"] = tail[-1] if tail else ""
        else:
            row["train_name"] = label.split(" (")[0].strip()
            row["travel_class"] = tail[-1] if tail else ""
        transport.append(row)

    hotels: list[dict] = []
    for _num_, body, price in _ROW_RE.findall(hotel_block):
        stars = _STARS_RE.search(body)
        nights = _NIGHTS_RE.search(body)
        hotels.append({
            "kind": "hotel",
            "name": body.split(" · ")[0].strip(),
            "stars": float(stars.group(1)) if stars else 0.0,
            "nights": _int(nights.group(1)) if nights else 0,
            "price_pkr": _int(price),
        })

    transfers: list[dict] = []
    for _num_, body, price in _ROW_RE.findall(transfer_block):
        m = _TRANSFER_RE.match(body.strip())
        if not m:
            continue
        vehicle, hub, destination = (g.strip() for g in m.groups())
        transfers.append({
            "vehicle": vehicle,
            "hub": hub,
            "destination": destination,
            "fare_pkr": _int(price),
            # Re-derived from the fare table rather than read back out of the
            # text, so the label can never drift from the price it describes.
            "estimated": fare_is_estimated(hub, destination, vehicle),
        })

    picks: dict = {}
    selected = _SELECTED_RE.search(text)
    if selected:
        for category, index in _SELECTED_ITEM_RE.findall(selected.group(1)):
            picks[category.lower()] = _int(index)

    header = _HEADER_RE.search(text)
    destination = header.group(1).strip() if header else (
        transfers[0]["destination"] if transfers else ""
    )
    return {
        "destination": destination,
        "passengers": _int(header.group(2)) if header else 0,
        "nights": hotels[0]["nights"] if hotels else 0,
        "transport_kind": "flight" if is_flight else "train",
        "transport": transport,
        "hotels": hotels,
        "transfers": transfers,
        "picks": picks,
    }


def named_a_different_destination(text: str, own_destination: str) -> bool:
    """True if `text` names one of the four northern destinations OTHER than
    `own_destination` — the traveller has moved on to a different trip.

    Public (no leading underscore) so master_agent.py can reuse this exact
    check when validating structured planner state against the conversation,
    rather than re-implementing the same staleness rule a second time."""
    own = canonical_destination(own_destination)
    return any(
        dest != own and names_destination(text, dest)
        for dest in NORTHERN_DESTINATIONS
    )


def is_valid_planner_state(state) -> bool:
    """
    Structural check that `state` has the exact shape build_options() always
    produces, before master_agent.py trusts it as _planner_options.

    The normal write path can never create anything else — build_options()
    either returns this exact shape or {} (never saved) — so a failure here
    means the underlying DB row was corrupted or hand-edited, not a bug in
    ordinary operation. Guards outstanding()/complete()/build_plan(), which
    assume this shape and otherwise index straight into it (a missing or
    empty "transport"/"hotels" list, for instance, makes complete() think
    nothing is outstanding, and build_plan() then raises).

    Public (no leading underscore) so master_agent.py can reuse this exact
    check rather than re-deriving the schema a second time.
    """
    if not isinstance(state, dict):
        return False
    if not isinstance(state.get("destination"), str) or not state["destination"]:
        return False
    if not isinstance(state.get("transport_kind"), str) or not state["transport_kind"]:
        return False
    transport = state.get("transport")
    hotels = state.get("hotels")
    transfers = state.get("transfers")
    # transport/hotels are never empty on a genuine write (build_options()
    # returns {} rather than a row with either empty) — transfers legitimately
    # can be (a destination reached by its own airport has no hub transfer).
    if not isinstance(transport, list) or not transport or not all(isinstance(r, dict) for r in transport):
        return False
    if not isinstance(hotels, list) or not hotels or not all(isinstance(r, dict) for r in hotels):
        return False
    if not isinstance(transfers, list) or not all(isinstance(r, dict) for r in transfers):
        return False
    picks = state.get("picks")
    if not isinstance(picks, dict):
        return False
    lengths = {"transport": len(transport), "hotel": len(hotels), "transfer": len(transfers)}
    for key, value in picks.items():
        if key not in lengths:
            return False
        if not isinstance(value, int) or isinstance(value, bool):
            return False
        if not (1 <= value <= lengths[key]):
            return False
    return True


def find_options(history: list[dict] | None) -> dict:
    """
    The most recent option block this conversation rendered, parsed — or {}
    if it no longer belongs to the current trip.

    find_options has no notion of a "current trip" of its own — a completed
    Swat booking followed by "plan a trip to Hunza" leaves nothing in this
    conversation contradicting a stale Swat option block on its own terms, so
    a later "Flight 1, Hotel 1, Transfer 1" would otherwise resolve against
    someone else's already-paid-for trip. The check is deliberately NOT
    TripState.destination: that field is sticky by design (derive_state only
    sets it once, elsewhere in this codebase, and a later single-city mention
    doesn't overwrite it) — using it here would silently miss exactly this
    case. Instead this reads the conversation directly: if any USER message
    AFTER the candidate block names a different one of the four known
    northern destinations, the block is stale and {} is returned — the same
    "nothing to resolve" outcome as no options ever having been shown, which
    the caller already falls back on safely. Deliberately not "pick whichever
    block is newest" either — an empty result is always safer than a guess.
    """
    items = list(history or [])
    for i in range(len(items) - 1, -1, -1):
        m = items[i]
        if (m.get("role") or "").lower() != "assistant":
            continue
        content = m.get("content")
        if not isinstance(content, str):
            continue
        options = parse_options(content)
        if not options:
            continue
        destination = options.get("destination") or ""
        if destination:
            later_user_texts = (
                mm.get("content") for mm in items[i + 1:]
                if (mm.get("role") or "").lower() == "user"
            )
            if any(
                isinstance(t, str) and named_a_different_destination(t, destination)
                for t in later_user_texts
            ):
                return {}
        return options
    return {}


def find_picks(history: list[dict] | None) -> dict:
    """
    The newest recorded selection state — which may sit on the Trip Plan rather
    than on the option block, since the plan is what the last turn rendered.
    """
    for m in reversed(list(history or [])):
        if (m.get("role") or "").lower() != "assistant":
            continue
        content = m.get("content")
        if not isinstance(content, str):
            continue
        selected = _SELECTED_RE.search(content)
        if selected:
            return {
                category.lower(): _int(index)
                for category, index in _SELECTED_ITEM_RE.findall(selected.group(1))
            }
        if any(h in content for h in (_FLIGHTS_HEAD, _TRAINS_HEAD)):
            return {}      # options were shown with nothing picked yet
    return {}


# ── Reading the traveller's choices ──────────────────────────────────────────

_CATEGORY_WORDS = {
    "transport": r"flight|train|transport",
    "hotel": r"hotel|stay|accommodation",
    "transfer": r"transfer|car|vehicle|cab|taxi|ride",
}
_VEHICLE_WORDS = {"sedan": "Sedan", "suv": "SUV", "van": "Van"}
_BARE_NUMBER_RE = re.compile(r"^\s*(?:option|number|no\.?|#)?\s*(\d{1,2})\s*[.!)]?\s*$", re.I)


@dataclass
class PickResult:
    picks: dict = field(default_factory=dict)
    problems: list[str] = field(default_factory=list)
    # Whether THIS message changed anything. A confirmation must not be read as
    # a re-selection, and a re-selection must not be read as a confirmation.
    picks_changed: bool = False


def parse_picks(message: str, options: dict, prior: dict | None = None) -> PickResult:
    """
    Resolve "Flight 2, Hotel 1, SUV" into exact option indices.

    Every category is read independently, so the first number in the message can
    never be mistaken for a whole-package choice — the failure this replaces,
    where "Flight 2, Hotel 1, SUV" silently booked package 2.

    A number that names no option, or a bare number when more than one category
    is still open, comes back as a PROBLEM rather than a guess.
    """
    text = (message or "").strip()
    result = PickResult()
    if not text or not options:
        return result
    prior = dict(prior or {})
    low = text.lower()

    sizes = {
        "transport": len(options.get("transport") or []),
        "hotel": len(options.get("hotels") or []),
        "transfer": len(options.get("transfers") or []),
    }

    def _record(category: str, index: int, label: str) -> None:
        limit = sizes.get(category, 0)
        if limit and 1 <= index <= limit:
            result.picks[category] = index
        else:
            result.problems.append(
                f"{label} {index} isn't on the list — there "
                f"{'is only 1 option' if limit == 1 else f'are {limit} options'}."
                if limit else f"There are no {label.lower()} options to choose from."
            )

    matched_any = False
    for category, words in _CATEGORY_WORDS.items():
        # "flight 2" / "flight #2" / "2 for the flight" / "option 2 for the hotel"
        for pattern in (
            rf"\b(?:{words})\s*(?:option|number|no\.?|#)?\s*[:#-]?\s*(\d{{1,2}})\b",
            rf"\b(?:option|number|no\.?|#)?\s*(\d{{1,2}})\s+for\s+(?:the\s+)?(?:{words})\b",
        ):
            m = re.search(pattern, low, re.I)
            if m:
                matched_any = True
                _record(category, int(m.group(1)), category.capitalize())
                break

    # A vehicle named outright ("SUV") is a transfer pick — resolve it against
    # the transfers actually offered rather than assuming the usual ordering.
    if "transfer" not in result.picks:
        for word, vehicle in _VEHICLE_WORDS.items():
            if re.search(rf"\b{word}\b", low):
                matched_any = True
                index = next(
                    (i for i, t in enumerate(options.get("transfers") or [], start=1)
                     if t.get("vehicle", "").lower() == vehicle.lower()),
                    None,
                )
                if index:
                    result.picks["transfer"] = index
                else:
                    offered = ", ".join(
                        t["vehicle"] for t in (options.get("transfers") or [])
                    ) or "none"
                    result.problems.append(
                        f"A {vehicle} isn't available for {options.get('passengers') or 'your'} "
                        f"travellers — offered: {offered}."
                    )
                break

    if matched_any:
        return result

    # A bare number is only unambiguous when exactly one category is still open.
    bare = _BARE_NUMBER_RE.match(text)
    if bare:
        open_now = outstanding(options, {**prior})
        if len(open_now) == 1:
            category = open_now[0]
            _record(category, int(bare.group(1)), category.capitalize())
        elif len(open_now) > 1:
            result.problems.append(
                "I'm not sure which that number is for — say which, "
                "like \"Flight 2\" or \"Hotel 2\"."
            )
    return result


def merge_picks(options: dict, message: str, prior: dict) -> PickResult:
    """Prior selections updated with whatever this message changes."""
    fresh = parse_picks(message, options, prior)
    merged = dict(prior)
    merged.update(fresh.picks)
    changed = any(prior.get(k) != v for k, v in fresh.picks.items())
    return PickResult(picks=merged, problems=fresh.problems, picks_changed=changed)


def clarification(problems: list[str], options: dict, picks: dict) -> str:
    """Ask, rather than silently choosing something the user didn't say."""
    lines = list(problems)
    todo = outstanding(options, picks)
    if todo:
        lines.append(_next_prompt({**options, "picks": picks}))
    return "\n\n".join(lines)


# ── The final trip plan ──────────────────────────────────────────────────────

def build_plan(options: dict, picks: dict) -> TripPackage | None:
    """
    The traveller's OWN selections composed into one priced trip.

    Reuses TripPackage so the total, and everything downstream of it, is the
    same deterministic code path the package flow already uses.
    """
    if not complete(options, picks):
        return None
    transport = (options.get("transport") or [])[picks["transport"] - 1]
    hotel = (options.get("hotels") or [])[picks["hotel"] - 1]
    transfers = options.get("transfers") or []
    transfer = transfers[picks["transfer"] - 1] if transfers and picks.get("transfer") else None

    hotel_row = dict(hotel.get("row") or {})
    hotel_row.setdefault("name", hotel.get("name"))
    hotel_row.setdefault("stars", hotel.get("stars"))
    return TripPackage(
        tier="",
        transport=dict(transport.get("row") or transport),
        transport_kind=options.get("transport_kind") or "flight",
        transport_pkr=int(transport.get("price_pkr") or 0),
        hotel=hotel_row,
        hotel_pkr=int(hotel.get("price_pkr") or 0),
        nights=int(hotel.get("nights") or options.get("nights") or 0),
        transfer=(
            {
                "vehicle": transfer["vehicle"],
                "hub": transfer["hub"],
                "destination": transfer["destination"],
                "fare_pkr": int(transfer["fare_pkr"]),
            } if transfer else None
        ),
    )


def _budget_block(total: int, budget_pkr) -> list[str]:
    budget = _num(budget_pkr)
    if budget <= 0:
        return [f"**TOTAL: {_money(total)}**"]
    if total <= budget:
        return [
            f"**TOTAL: {_money(total)}**",
            f"Budget: {_money(budget)}",
            f"Remaining: {_money(budget - total)}",
        ]
    return [
        f"**TOTAL: {_money(total)}**",
        f"Budget: {_money(budget)}",
        f"**Over budget by {_money(total - budget)}.** Nothing has been changed for you — "
        f"tell me which part to swap (e.g. \"Hotel 2\") and I'll re-price it.",
    ]


def render_plan(
    plan: TripPackage, options: dict, picks: dict, destination: str, budget_pkr=None,
    travel_date: str = "", return_date: str = "",
) -> str:
    """The final Trip Plan — the traveller's exact selections, priced and totalled."""
    if not plan:
        return ""
    dest = canonical_destination(destination) or destination
    pax = options.get("passengers") or 0
    transport_row = (options.get("transport") or [])[picks["transport"] - 1]
    hotel_row = (options.get("hotels") or [])[picks["hotel"] - 1]

    lines = [f"{_PLAN_HEAD} — {dest.upper()}**", ""]

    icon = "✈️" if plan.transport_kind == "flight" else "🚆"
    kind_word = "Flight" if plan.transport_kind == "flight" else "Train"
    lines.append(f"**Transport**")
    lines.append(f"{icon} {kind_word} #{picks['transport']} — {transport_row.get('label', '')}")
    if transport_row.get("origin"):
        lines.append(f"{transport_row['origin']} → {transport_row['destination']}")
    seat = transport_row.get("cabin") or transport_row.get("travel_class")
    if seat:
        lines.append(seat)
    if transport_row.get("depart"):
        lines.append(str(transport_row["depart"]))
    lines.append(_money(plan.transport_pkr))

    lines += ["", "**Hotel**"]
    stars = hotel_row.get("stars") or 0
    lines.append(f"🏨 Hotel #{picks['hotel']} — {hotel_row.get('name', '')}")
    lines.append(f"{dest}" + (f" · {stars:g}★" if stars else ""))
    nights = plan.nights or hotel_row.get("nights") or 0
    if nights:
        lines.append(f"{nights} night{'s' if nights != 1 else ''}")
    lines.append(_money(plan.hotel_pkr))

    if plan.transfer:
        t = plan.transfer
        lines += ["", "**Transfer**"]
        lines.append(f"🚗 Transfer #{picks.get('transfer')} — {t['vehicle']}")
        lines.append(f"{t['hub']} → {t['destination']}")
        estimated = fare_is_estimated(t["hub"], t["destination"], t["vehicle"])
        lines.append(_money(t["fare_pkr"]) + (_ESTIMATED_TAG if estimated else ""))

    if plan.return_transport:
        icon = "✈️" if plan.return_transport_kind == "flight" else "🚆"
        lines += ["", "**Return**"]
        lines.append(f"{icon} {plan.return_transport_label}")
        if plan.return_transport.get("origin"):
            lines.append(f"{plan.return_transport['origin']} → {plan.return_transport['destination']}")
        lines.append(_money(plan.return_transport_pkr))

    trip_dates = " → ".join(d for d in (travel_date, return_date) if d)
    if trip_dates:
        lines += ["", f"Dates: {trip_dates}"]
    if pax:
        lines += ["", f"Travellers: {pax}"] if not trip_dates else [f"Travellers: {pax}"]
    lines += ["", "---"]
    lines += _budget_block(plan.total_pkr, budget_pkr)
    lines.append("---")
    # Carried so the next turn can recover the exact selection without asking.
    lines += ["", _selected_line(picks)]
    lines += ["", "Would you like to proceed with this complete trip package?"]
    return "\n".join(lines)


def plan_was_shown(history: list[dict] | None) -> bool:
    for m in reversed(list(history or [])):
        if (m.get("role") or "").lower() != "assistant":
            continue
        content = m.get("content")
        if isinstance(content, str) and content.strip():
            return _PLAN_HEAD in content
    return False


_CONFIRM_RE = re.compile(
    r"^\s*(?:yes|yep|yeah|yup|ok(?:ay)?|sure|proceed|confirm(?:ed)?|go ahead|"
    r"book it|book now|let'?s go|do it|sounds good|perfect|that works)\b",
    re.I,
)


def is_confirmation(message: str) -> bool:
    return bool(_CONFIRM_RE.match((message or "").strip()))


# A reply to the assistant's OWN follow-up question ("what's the pickup
# address?") reads nothing like a question or a change of mind. Deliberately
# narrow and conservative: this only screens OUT the shapes a question or an
# edit request takes (a trailing "?", an interrogative opener, an explicit
# change/swap word) — it never tries to positively recognise an address, a
# hotel name or anything else, so it can't be fooled by not knowing what an
# address "looks like". Anything not screened out is treated as an answer.
_FOLLOWUP_QUESTION_RE = re.compile(
    r"\?\s*$"
    r"|^\s*(?:can|could|why|what|should|is|are|do|does|will|would|may)\b"
    r"|\b(?:change|switch|swap|instead|different|actually|cancel)\b",
    re.I,
)


def looks_like_a_followup_answer(message: str) -> bool:
    """
    True when `message` reads as a plain answer rather than a question or a
    change-of-mind — e.g. "Islamabad Airport" or "Hotel is Hotel Pameer /
    pickup address is Islamabad Airport", but not "Can I change the hotel?"
    or "Hotel 2 instead".

    Used ONLY to decide whether a post-confirmation reply should reach the
    booking pipeline instead of being silently re-answered with the same
    Trip Plan — see the caller in master_agent.py. It never fills in a
    field itself and never bypasses a booking gate; it only decides whether
    the message is handed to the model at all.
    """
    text = (message or "").strip()
    return bool(text) and not _FOLLOWUP_QUESTION_RE.search(text)


def looks_like_a_bare_number(message: str) -> bool:
    """
    True for a lone digit reply ("2", "Option 2", "#2") -- never a real
    pickup address, hotel name, or anything else with actual content.

    A bare number answering some OTHER question (the model free-lancing an
    ad-hoc "1. cheaper / 2. raise the budget / 3. suggest an alternative"
    after an over-budget plan, for instance -- see master_agent.py) still
    passes looks_like_a_followup_answer() above, since it isn't a question
    or a change-of-mind either. This is the extra check that stops such a
    number from being taken AS the pickup address once a plan is confirmed
    and a transfer is the only thing still missing -- "2" would otherwise
    pass every existing transfer gate (it's not a known placeholder phrase
    and not a bare city name) and get dispatched to a real driver.
    """
    return bool(_BARE_NUMBER_RE.match((message or "").strip()))


# A real answer to "what's the pickup address?" very often echoes the
# question back naturally ("Pickup address is 123 Main Street", "the address
# is..."), which is indistinguishable, as raw text, from
# agent_tools._TRANSFER_PLACEHOLDER_RE's actual target: a MODEL parroting the
# field name back with nothing filled in ("Your pickup address in
# Islamabad"). Stripping just this leading frame — never the whole message,
# never anything after it — lets a genuine answer through that gate without
# weakening what the gate actually guards against downstream.
_PICKUP_ANSWER_PREFIX_RE = re.compile(
    r"^\s*(?:the\s+|my\s+)?pick[\s-]?up\s+(?:address|location|point)\s*(?:is|:|-)?\s*",
    re.I,
)


def clean_pickup_reply(message: str) -> str:
    """Strip a leading "pickup address is" / "the pickup address:" frame
    from a traveller's reply, so a plainly-phrased real answer isn't
    mistaken for the placeholder text this exact wording usually signals
    when a MODEL produces it instead — see _PICKUP_ANSWER_PREFIX_RE."""
    text = (message or "").strip()
    return _PICKUP_ANSWER_PREFIX_RE.sub("", text, count=1).strip()


def booking_instruction(plan: TripPackage, options: dict, picks: dict) -> str:
    """
    The flat brief for booking the traveller's OWN selection as one checkout.

    Same contract as trip_package.selection_instruction — it hands the model
    exact component identities and forbids re-pricing — so everything
    downstream (the atomic package gate, reprice_booking, package_id, the one
    payment, the one email) behaves identically to the package flow.
    """
    transport_row = (options.get("transport") or [])[picks["transport"] - 1]
    hotel_row = (options.get("hotels") or [])[picks["hotel"] - 1]
    parts: list[str] = []
    if plan.transport_kind == "flight" and transport_row.get("flight_number"):
        cabin = transport_row.get("cabin") or ""
        parts.append(
            f"the FLIGHT {transport_row['flight_number']}"
            + (f" in {cabin}" if cabin else "")
            + f" (shown at PKR {plan.transport_pkr:,})"
        )
    else:
        seat = transport_row.get("travel_class") or ""
        parts.append(
            f"the TRAIN {transport_row.get('train_name') or transport_row.get('label', '')}"
            + (f" in {seat}" if seat else "")
        )
    nights = plan.nights
    parts.append(
        f"the HOTEL \"{hotel_row.get('name', '')}\""
        + (f" for {nights} nights" if nights else "")
    )

    lines = [
        f"TRIP PLAN CONFIRMED by the traveller — total PKR {plan.total_pkr:,}. "
        "These are THEIR chosen components. This is ONE trip, not separate bookings.",
        "Call prepare_booking for " + " AND ".join(parts) + " in this SAME reply — "
        "one call each, together, so they become a single checkout with one "
        "passenger form and one payment.",
    ]
    if plan.transfer:
        t = plan.transfer
        lines.append(
            f"On the {'flight' if plan.transport_kind == 'flight' else 'train'} call ALSO set "
            f"transfer_vehicle_type=\"{t['vehicle']}\" and "
            f"transfer_dropoff_location=\"{t['destination']}\", and ask the traveller only "
            f"for the pickup address at {t['hub']} if you don't already have it. "
            "Do NOT use book_car — the car is part of this package."
        )
    lines.append(
        "Do not re-list options, do not re-price anything, do not substitute a "
        "different flight, hotel or vehicle, and do not prepare only part of it."
    )
    return " ".join(lines)


_ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}")


def confirmation_booking_payloads(
    plan: TripPackage, options: dict, picks: dict, *,
    pickup_location: str = "", fallback_date: str = "",
) -> list[dict]:
    """
    The traveller's OWN selection as ready-to-verify prepare_booking payloads
    -- the deterministic counterpart to booking_instruction()'s prose brief.

    Built from the exact same rows that brief already reads, so completing a
    confirmed plan never depends on a model correctly re-typing what this
    app already knows server-side. Exists because the ATOMIC PACKAGE GATE
    (master_agent.py) requires transport AND hotel to land in prepare_booking
    calls within the SAME model turn, and a free-tier model was not reliably
    managing that -- see master_agent.py's _complete_trip_planner_confirmation.

    `fallback_date` covers the ONE case the rendered options block itself
    can't answer: when `options` was recovered by parsing rendered text back
    (find_options' fallback path, not fresh from build_options()/structured
    state), row["depart"] only ever carries a bare time ("07:00") -- the
    rendered line never showed a date to parse back (see render_options'
    `when` line and parse_options' _TIME_RE). Using it here is still safe:
    a wrong date can't mint a wrong price or the wrong component, because
    reprice_booking still has to re-match the SAME flight_number/hotel_name
    against a fresh search on that date -- if the date is wrong, that match
    simply fails and the caller falls back to the existing model-driven path,
    exactly as if this function had never run.

    Returns [transport_payload, hotel_payload]. The transport payload only
    carries the transfer fields when `plan.transfer` is set AND
    `pickup_location` is non-empty -- when a transfer is needed but no
    pickup address is known yet, the caller must ask for one rather than
    have this function guess.
    """
    transport_row = (options.get("transport") or [])[picks["transport"] - 1]
    hotel_row = (options.get("hotels") or [])[picks["hotel"] - 1]
    destination = options.get("destination") or ""
    passengers = int(options.get("passengers") or 1)
    depart_date = (transport_row.get("depart") or "").split(" ", 1)[0]
    if not _ISO_DATE_RE.match(depart_date):
        depart_date = fallback_date

    if plan.transport_kind == "train":
        transport: dict = {
            "booking_type": "train",
            "origin": transport_row.get("origin", ""),
            "destination": transport_row.get("destination", ""),
            "travel_date": depart_date,
            "train_name": transport_row.get("train_name", ""),
            "train_class": transport_row.get("travel_class", ""),
            "adults": passengers,
            "total_price_pkr": plan.transport_pkr,
        }
    else:
        transport = {
            "booking_type": "flight",
            "origin": transport_row.get("origin", ""),
            "destination": transport_row.get("destination", ""),
            "travel_date": depart_date,
            "flight_number": transport_row.get("flight_number", ""),
            "cabin_class": transport_row.get("cabin", ""),
            "adults": passengers,
            "total_price_pkr": plan.transport_pkr,
        }
    if plan.transfer and pickup_location:
        transport["transfer_vehicle_type"] = plan.transfer["vehicle"]
        # get_transfer_error already grounds this exact string against the
        # traveller's own words — real risk here isn't fabrication, it's that
        # this app's own downstream fare lookup (agent_tools._add_transfer_fare
        # -> car_service.estimate_fare -> northern_routes.price_for_route)
        # matches routes by scanning for known city NAMES anywhere in this
        # text, and re-derives the fare from it rather than trusting the
        # ALREADY server-computed plan.transfer['fare_pkr']. A traveller who
        # answers "what's the pickup address?" with a real landmark instead
        # of literally typing the hub city name (e.g. "near point to hunza"
        # for a Gilgit hub) silently fell through to the flat in-city rate —
        # observed live: PKR 18,000 (Gilgit->Hunza, sourced) became PKR 6,000.
        # Appending the known hub name (only when genuinely absent) keeps the
        # traveller's own words as the primary pickup text a driver reads,
        # while guaranteeing the fare lookup can still find the real route.
        hub = str(plan.transfer.get("hub") or "").strip()
        pickup_text = pickup_location
        if hub and hub.lower() not in pickup_location.lower():
            pickup_text = f"{pickup_location} ({hub})"
        transport["transfer_pickup_location"] = pickup_text
        transport["transfer_dropoff_location"] = plan.transfer["destination"]

    hotel: dict = {
        "booking_type": "hotel",
        "destination": destination,
        "check_in": depart_date,
        "check_out": _add_days(depart_date, plan.nights),
        "hotel_name": hotel_row.get("name", ""),
        "guests": passengers,
        "rooms": 1,
        "total_price_pkr": plan.hotel_pkr,
    }
    payloads = [transport, hotel]
    if plan.return_transport:
        r = plan.return_transport
        r_date = (r.get("depart") or "").split(" ", 1)[0]
        if not _ISO_DATE_RE.match(r_date):
            r_date = options.get("_return_date") or fallback_date
        if plan.return_transport_kind == "train":
            payloads.append({
                "booking_type": "train",
                "origin": r.get("origin", ""),
                "destination": r.get("destination", ""),
                "travel_date": r_date,
                "train_name": r.get("train_name", ""),
                "train_class": r.get("travel_class", ""),
                "adults": passengers,
                "total_price_pkr": plan.return_transport_pkr,
            })
        else:
            payloads.append({
                "booking_type": "flight",
                "origin": r.get("origin", ""),
                "destination": r.get("destination", ""),
                "travel_date": r_date,
                "flight_number": r.get("flight_number", ""),
                "cabin_class": r.get("cabin", ""),
                "adults": passengers,
                "total_price_pkr": plan.return_transport_pkr,
            })
    return payloads


def _add_days(date_str: str, days: int) -> str:
    try:
        y, m, d = (int(p) for p in date_str.split("-"))
        return (date(y, m, d) + timedelta(days=max(days, 1))).isoformat()
    except (TypeError, ValueError):
        return date_str


# ── Optional return leg ──────────────────────────────────────────────────────
#
# A SEPARATE, later step from the outbound options/picks above, deliberately
# not woven into build_options/render_options/parse_picks/outstanding — those
# already carry a render-your-own-output-then-reparse-it contract the rest of
# the app depends on, and a traveller's answer here ("2", "no thanks") has a
# completely different shape than an outbound pick. Only offered once the
# outbound plan is already confirmed, and only when the traveller gave a real
# second date (see master_agent's use of conversation_state.TripState.
# return_date) — the return-leg SEARCH itself is run deterministically
# server-side (never left to the model), the same reasoning as every other
# search this file drives.

_RETURN_HEAD = "**RETURN TRIP OPTIONS**"


def build_return_options(gathered: list[tuple[str, str]]) -> tuple[list[dict], str]:
    """The return-leg transport rows from a single deterministic hub->origin
    search result, plus its kind ("flight"/"train") — or ([], "") when
    nothing came back. `gathered` holds exactly one (tool_name, raw_json)
    entry, the same shape build_options() itself consumes."""
    transport, kind, _, _, _ = _collect(gathered)
    if not transport:
        return [], ""
    rows = _flight_rows(transport) if kind == "flight" else _train_rows(transport)
    return rows, kind


def render_return_options(rows: list[dict], origin: str, return_date: str) -> str:
    """The traveller-facing return-leg list — same row shape/format as the
    outbound AVAILABLE FLIGHTS/TRAINS block, under its own distinct header
    (_RETURN_HEAD) so return_was_offered() can recognise this exact turn."""
    lines = [
        f"Your outbound trip is set. Would you like a return trip back to "
        f"{origin} on {return_date}?",
        "",
        _RETURN_HEAD,
    ]
    for i, row in enumerate(rows, start=1):
        route = f"{row['origin']} → {row['destination']}" if row.get("origin") else ""
        when = f"{row.get('depart', '')[-5:]} → {row.get('arrive', '')[-5:]}".strip(" →")
        extra = row.get("cabin") or row.get("travel_class") or ""
        parts = [p for p in (route, when, extra) if p]
        lines.append(
            f"{i}. {row['label']}"
            + (" · " + " · ".join(parts) if parts else "")
            + f" — {_money(row['price_pkr'])}"
        )
    lines += [
        "",
        "Reply with a number to add it to your booking, or say \"no thanks\" "
        "to keep this trip one-way.",
    ]
    return "\n".join(lines)


def return_was_offered(history: list[dict] | None) -> bool:
    """True when the LAST assistant message was render_return_options' own
    output — mirrors plan_was_shown()'s exact pattern for the plan card."""
    for m in reversed(list(history or [])):
        if (m.get("role") or "").lower() != "assistant":
            continue
        content = m.get("content")
        if isinstance(content, str) and content.strip():
            return _RETURN_HEAD in content
    return False


_RETURN_DECLINE_RE = re.compile(
    r"\b(?:no|nah|nope|skip|one[\s-]?way|not\s+needed|don'?t\s+need|no\s+thanks?)\b",
    re.I,
)
_RETURN_PICK_RE = re.compile(r"\b(\d{1,2})\b")


def parse_return_pick(message: str, rows: list[dict]) -> int | None:
    """1-based index into `rows`, 0 for an explicit decline, or None when the
    reply is neither — the caller should ask again rather than guess."""
    text = (message or "").strip()
    if not text:
        return None
    if _RETURN_DECLINE_RE.search(text):
        return 0
    m = _RETURN_PICK_RE.search(text)
    if m:
        idx = int(m.group(1))
        if 1 <= idx <= len(rows):
            return idx
    return None


def apply_return_pick(plan: TripPackage, rows: list[dict], kind: str, pick_index: int) -> None:
    """Attach the traveller's chosen return-leg row onto an already-built
    plan (TripPackage is a plain, mutable dataclass). A decline (0) or an
    out-of-range index leaves the plan exactly as build_plan() made it — a
    one-way trip, unchanged."""
    if not rows or not (1 <= pick_index <= len(rows)):
        return
    plan.return_transport = rows[pick_index - 1]
    plan.return_transport_kind = kind
    plan.return_transport_pkr = int(plan.return_transport.get("price_pkr") or 0)
