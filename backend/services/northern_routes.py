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
    ],
    "Swat": [
        HubOption("Islamabad", "flight", 160, "4-5 hours by road"),
        HubOption("Rawalpindi", "train", 160, "4-5 hours by road"),
    ],
    "Skardu": [],
}

# Real-researched one-way hub<->destination car fares, PKR. Anchors: private
# car transfer Islamabad-Naran ~PKR 18,000; Gilgit-Hunza taxi/car ~PKR
# 7,000-18,000 depending on vehicle (mid estimate used); Islamabad-Swat
# estimated slightly below Naran given the easier motorway route. Ordering
# kept consistent with the app's existing flat in-city rates (Sedan < SUV <
# Van), distinct from car_service's flat rate which stays the fallback for
# everything not listed here (in-city rides, ordinary airport transfers).
_ROUTE_FARES: dict[frozenset[str], dict[str, int]] = {
    frozenset({"islamabad", "naran"}):  {"Sedan": 18000, "SUV": 24000, "Van": 28000},
    frozenset({"rawalpindi", "naran"}): {"Sedan": 18000, "SUV": 24000, "Van": 28000},
    frozenset({"gilgit", "hunza"}):     {"Sedan": 7000,  "SUV": 9500,  "Van": 12000},
    frozenset({"islamabad", "swat"}):   {"Sedan": 15000, "SUV": 20000, "Van": 23000},
    frozenset({"rawalpindi", "swat"}):  {"Sedan": 15000, "SUV": 20000, "Van": 23000},
}
_ROUTE_CITY_TOKENS = sorted({c for pair in _ROUTE_FARES for c in pair}, key=len, reverse=True)


def hub_options_for(destination_city: str) -> list[HubOption] | None:
    """The real hub(s) for a destination with no airport/station of its own,
    [] if it already has one (Skardu), or None if it's not one of these four."""
    return NORTHERN_DESTINATIONS.get((destination_city or "").strip().title())


def _cities_in(text: str) -> set[str]:
    low = (text or "").lower()
    return {c for c in _ROUTE_CITY_TOKENS if re.search(rf"\b{re.escape(c)}\b", low)}


def price_for_route(pickup_location: str, dropoff_location: str, vehicle_type: str) -> int | None:
    """PKR fare for a KNOWN long hub<->destination route, matched fuzzily
    against free-text addresses — or None, so the caller falls back to the
    flat in-city rate."""
    cities = _cities_in(pickup_location) | _cities_in(dropoff_location)
    for pair, fares in _ROUTE_FARES.items():
        if pair <= cities:
            return fares.get(vehicle_type)
    return None


def estimate_hub_car_fare(destination_city: str) -> tuple[int, str] | None:
    """Cheapest (Sedan) hub->destination estimate + a short label, for the
    deterministic whole-trip budget verdict — or None if no route matches."""
    hubs = hub_options_for(destination_city)
    if not hubs:
        return None
    dest_key = destination_city.strip().lower()
    best: tuple[int, str] | None = None
    for h in hubs:
        fares = _ROUTE_FARES.get(frozenset({h.hub_city.lower(), dest_key}))
        if fares and (best is None or fares["Sedan"] < best[0]):
            best = (fares["Sedan"], f"{h.hub_city} -> {destination_city}")
    return best
