# =============================================================================
# PURPOSE: Hub facts and route fares for northern Pakistan destinations that
#          have no airport or railway station of their own (Naran, Hunza,
#          Swat) plus Skardu, which already has its own airport and needs no
#          hub substitution. Single source of truth reused by car pricing,
#          tool-error messages, and tool-selection signals.
# =============================================================================

from __future__ import annotations

import re
from typing import NamedTuple

from services.hotel_service import CITY_ALIASES


class HubOption(NamedTuple):
    hub_city: str
    mode: str  # "flight" | "train"
    distance_km: int
    duration_hint: str


# None (missing key) = not one of these four. [] = already has its own
# airport (Skardu) — no hub substitution, ordinary transfer only.
NORTHERN_DESTINATIONS: dict[str, list[HubOption]] = {
    "Naran": [
        HubOption("Islamabad", "flight", 190, "6-7 hours by road"),
        HubOption("Rawalpindi", "train", 190, "6-7 hours by road"),
    ],
    "Hunza": [
        HubOption("Gilgit", "flight", 100, "2.5-3 hours by road"),
        # Gilgit has an airport but NO railway station, so a train traveller
        # cannot be collected there. Pakistan Railways' nearest railhead to
        # Hunza is Rawalpindi, and the road leg from there runs the full
        # Karakoram Highway — a different journey entirely from the 100km
        # Gilgit hop, which is why it carries its own fare below.
        HubOption("Rawalpindi", "train", 600, "14-16 hours by road"),
    ],
    "Swat": [
        HubOption("Islamabad", "flight", 160, "4-5 hours by road"),
        HubOption("Rawalpindi", "train", 160, "4-5 hours by road"),
    ],
    "Skardu": [],
}

# One-way hub<->destination car fares, PKR. PROVENANCE IS MIXED — some of these
# are sourced from real operator quotes and some are estimates, so nothing here
# may be described as researched as a whole. _ESTIMATED_FARES below records
# exactly which are which, and the traveller is shown "(Estimated)" beside any
# price we cannot attribute to a source.
#
# SOURCED
#   Gilgit-Hunza Sedan  PKR 10,000  — Wonderland Treks & Tours, one-way,
#   Gilgit-Hunza SUV    PKR 18,000    Gilgit Airport -> Aliabad/Karimabad:
#                                     "10k" normal car, "18k to 20k" Prado
#                                     TX/TZ. Lower bound taken for the SUV.
#                                     Corroborated by a 2026 fare calculator
#                                     quoting ~PKR 12,720 for the 106km leg.
#
# ESTIMATED (no source found — see _ESTIMATED_FARES)
#   Gilgit-Hunza Van        PKR 30,000 is OWNER-DEFINED. No van quote exists
#                           for this leg, and this figure is not derived,
#                           scaled or interpolated from the sedan/SUV quotes
#                           above or from any other source. It is a price the
#                           operator sets, and it is shown to the traveller as
#                           "(Estimated)" for exactly that reason.
#   Rawalpindi-Hunza        the RAIL traveller's road leg, ~620km of Karakoram
#                           Highway. Real operator pricing for this corridor is
#                           published PER DAY to Gilgit (Corolla 24,000-50,000,
#                           Prado 45,000-85,000, Hiace 45,000-90,000), never as
#                           a one-way drop, so these sit inside real ranges but
#                           are not a quoted one-way fare.
#   Islamabad/Rawalpindi-Swat   derived from the Naran figure on the reasoning
#                           that the motorway route is easier; never quoted.
#
# Islamabad/Rawalpindi-Naran carries a claimed ~PKR 18,000 private-transfer
# anchor from the original research. It is treated as sourced here, but that
# anchor has NOT been independently re-verified — see the FYP report.
#
# Ordering kept consistent with the app's existing flat in-city rates, distinct
# from car_service's flat rate which stays the fallback for everything not
# listed here (in-city rides, ordinary airport transfers).
_ROUTE_FARES: dict[frozenset[str], dict[str, int]] = {
    frozenset({"islamabad", "naran"}):  {"Sedan": 18000, "SUV": 24000, "Van": 28000},
    frozenset({"rawalpindi", "naran"}): {"Sedan": 18000, "SUV": 24000, "Van": 28000},
    frozenset({"gilgit", "hunza"}):     {"Sedan": 10000, "SUV": 18000, "Van": 30000},
    frozenset({"rawalpindi", "hunza"}): {"Sedan": 38000, "SUV": 48000, "Van": 55000},
    frozenset({"islamabad", "swat"}):   {"Sedan": 15000, "SUV": 20000, "Van": 23000},
    frozenset({"rawalpindi", "swat"}):  {"Sedan": 15000, "SUV": 20000, "Van": 23000},
}

# Which fares above are estimates rather than sourced quotes, per vehicle.
# Shown to the traveller as "(Estimated)" — a price we cannot attribute must
# never look like one we can.
_ALL_VEHICLES = frozenset({"Sedan", "SUV", "Van"})
_ESTIMATED_FARES: dict[frozenset[str], frozenset[str]] = {
    # Only the van: the sedan and SUV are quoted by a named operator.
    frozenset({"gilgit", "hunza"}):     frozenset({"Van"}),
    frozenset({"rawalpindi", "hunza"}): _ALL_VEHICLES,
    frozenset({"islamabad", "swat"}):   _ALL_VEHICLES,
    frozenset({"rawalpindi", "swat"}):  _ALL_VEHICLES,
}
# Every spelling that can name a route city, mapped to the canonical one the
# fare table is keyed by — so a pickup/dropoff written "Kaghan", "Karimabad"
# or "Mingora" prices at the real route fare instead of falling through to the
# flat in-city rate. Same reason as canonical_destination below.
_ROUTE_CITY_CANON: dict[str, str] = {c: c for pair in _ROUTE_FARES for c in pair}
_ROUTE_CITY_CANON.update({
    alias.lower(): canon.lower()
    for alias, canon in CITY_ALIASES.items()
    if canon.lower() in _ROUTE_CITY_CANON
})
_ROUTE_CITY_TOKENS = sorted(_ROUTE_CITY_CANON, key=len, reverse=True)


# A destination reaches this module in whatever words the traveller used —
# "Kaghan" and "naran kaghan" both mean Naran, "Karimabad" means Hunza. Those
# alias forms are already the app's own vocabulary (CITY_ALIASES drives hotel
# search), but NORTHERN_DESTINATIONS is keyed by canonical name only, so an
# alias used to miss every lookup here and read as "not a northern
# destination at all" — silently disabling the Trip Planner completeness gate
# and the transfer money-correctness gate, both of which key off
# hub_options_for returning None. Canonicalise once, here, so every caller
# sees the same answer whichever form the traveller typed.
def canonical_destination(destination_city: str) -> str:
    """The canonical city name for any alias the app recognises ('Kaghan' ->
    'Naran'), or the input title-cased when it isn't a known alias."""
    name = (destination_city or "").strip()
    return CITY_ALIASES.get(name.lower(), name.title()) if name else ""


def hub_options_for(destination_city: str) -> list[HubOption] | None:
    """The real hub(s) for a destination with no airport/station of its own,
    [] if it already has one (Skardu), or None if it's not one of these four.
    Accepts alias forms — see canonical_destination."""
    return NORTHERN_DESTINATIONS.get(canonical_destination(destination_city))


def names_destination(text: str, destination_city: str) -> bool:
    """True if `text` names `destination_city` in ANY form the app recognises
    — "Kaghan" names Naran, "Karimabad" names Hunza. The transfer gate needs
    this because the dropoff and the derived trip destination can legitimately
    be written in different forms of the same place."""
    canonical = canonical_destination(destination_city)
    if not canonical:
        return False
    low = (text or "").lower()
    forms = {canonical.lower()} | {
        alias.lower() for alias, canon in CITY_ALIASES.items() if canon == canonical
    }
    return any(re.search(rf"\b{re.escape(f)}\b", low) for f in forms)


def _cities_in(text: str) -> set[str]:
    """The canonical route cities named anywhere in free text, alias-aware."""
    low = (text or "").lower()
    return {
        _ROUTE_CITY_CANON[c] for c in _ROUTE_CITY_TOKENS
        if re.search(rf"\b{re.escape(c)}\b", low)
    }


def price_for_route(pickup_location: str, dropoff_location: str, vehicle_type: str) -> int | None:
    """PKR fare for a KNOWN long hub<->destination route, matched fuzzily
    against free-text addresses — or None, so the caller falls back to the
    flat in-city rate."""
    cities = _cities_in(pickup_location) | _cities_in(dropoff_location)
    for pair, fares in _ROUTE_FARES.items():
        if pair <= cities:
            return fares.get(vehicle_type)
    return None


def fare_is_estimated(pickup_location: str, dropoff_location: str, vehicle_type: str) -> bool:
    """
    True when the fare for this route+vehicle is an estimate, not a sourced
    quote — so the traveller can be told which they're looking at.

    Matched the same fuzzy way price_for_route matches, against the same table,
    so a fare and its provenance can never be resolved from different rows.
    Unknown routes fall back to car_service's flat in-city rate, which is a
    published app rate rather than an estimate, hence False.
    """
    cities = _cities_in(pickup_location) | _cities_in(dropoff_location)
    for pair in _ROUTE_FARES:
        if pair <= cities:
            return vehicle_type in _ESTIMATED_FARES.get(pair, frozenset())
    return False


def estimate_hub_car_fare(destination_city: str) -> tuple[int, str] | None:
    """Cheapest (Sedan) hub->destination estimate + a short label, for the
    deterministic whole-trip budget verdict — or None if no route matches."""
    hubs = hub_options_for(destination_city)
    if not hubs:
        return None
    canonical = canonical_destination(destination_city)
    dest_key = canonical.lower()
    best: tuple[int, str] | None = None
    for h in hubs:
        fares = _ROUTE_FARES.get(frozenset({h.hub_city.lower(), dest_key}))
        if fares and (best is None or fares["Sedan"] < best[0]):
            best = (fares["Sedan"], f"{h.hub_city} -> {canonical}")
    return best
