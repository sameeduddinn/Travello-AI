# =============================================================================
# PURPOSE: Pakistan Railways mock service.
#          Uses real train names, station codes, and realistic schedules.
#          Pakistan Railways has no public API — this is standard FYP practice.
#

# =============================================================================

from __future__ import annotations

import hashlib
import random
from datetime import date, datetime, timedelta

from core.pk_time import pk_now, pk_today
from typing import Any

from models.train import SeatClass, TrainOffer, TrainSearchResponse

# Station data - IATA-style codes used internally

STATIONS: dict[str, dict[str, Any]] = {
    "KHI": {"name": "Karachi Cantonment", "city": "Karachi",   "aliases": ["karachi", "khi"]},
    "KCT": {"name": "Karachi City",        "city": "Karachi",   "aliases": ["karachi city"]},
    "HYD": {"name": "Hyderabad Junction",  "city": "Hyderabad", "aliases": ["hyderabad", "hyd"]},
    "SKZ": {"name": "Sukkur",              "city": "Sukkur",    "aliases": ["sukkur", "skz"]},
    "MUL": {"name": "Multan Cantonment",   "city": "Multan",    "aliases": ["multan", "mul"]},
    "LHE": {"name": "Lahore Junction",     "city": "Lahore",    "aliases": ["lahore", "lhe"]},
    "GUJ": {"name": "Gujranwala",          "city": "Gujranwala","aliases": ["gujranwala", "guj"]},
    "SKT": {"name": "Sialkot",             "city": "Sialkot",   "aliases": ["sialkot", "skt"]},
    "RWP": {"name": "Rawalpindi",          "city": "Rawalpindi","aliases": ["rawalpindi", "rwp"]},
    "ISB": {"name": "Islamabad",           "city": "Islamabad", "aliases": ["islamabad", "isb"]},
    "ATK": {"name": "Attock Khurd",        "city": "Attock",    "aliases": ["attock"]},
    "PEW": {"name": "Peshawar Cantonment", "city": "Peshawar",  "aliases": ["peshawar", "pew"]},
    "LYP": {"name": "Faisalabad",          "city": "Faisalabad","aliases": ["faisalabad", "lyp"]},
    "QTA": {"name": "Quetta",              "city": "Quetta",    "aliases": ["quetta", "qta"]},
    "ZHB": {"name": "Zhob",               "city": "Zhob",      "aliases": ["zhob"]},
    "SUK": {"name": "Jacobabad",           "city": "Jacobabad", "aliases": ["jacobabad"]},
    "KOT": {"name": "Kot Adu",            "city": "Kot Adu",   "aliases": ["kot adu"]},
    "SHD": {"name": "Sahiwal",            "city": "Sahiwal",   "aliases": ["sahiwal"]},
    # New railway stations
    "BWP": {"name": "Bahawalpur",         "city": "Bahawalpur",      "aliases": ["bahawalpur", "bwp"]},
    "DGK": {"name": "Dera Ghazi Khan",    "city": "Dera Ghazi Khan", "aliases": ["dera ghazi khan", "dg khan", "dgk"]},
    "LKN": {"name": "Larkana",            "city": "Larkana",         "aliases": ["larkana", "lkn"]},
    "HTR": {"name": "Haripur",            "city": "Haripur",         "aliases": ["haripur", "htr"]},
    # Northern areas — bus service only, Pakistan Railways has no tracks here
    "SKD": {"name": "Skardu",             "city": "Skardu",          "aliases": ["skardu", "skd"],          "bus_only": True},
    "GIL": {"name": "Gilgit",             "city": "Gilgit",          "aliases": ["gilgit", "gil"],          "bus_only": True},
    "ABT": {"name": "Abbottabad",         "city": "Abbottabad",      "aliases": ["abbottabad", "abt"],      "bus_only": True},
    "SWT": {"name": "Swat/Mingora",       "city": "Swat",            "aliases": ["swat", "mingora", "swt"], "bus_only": True},
    "MZD": {"name": "Muzaffarabad",       "city": "Muzaffarabad",    "aliases": ["muzaffarabad", "mzd"],    "bus_only": True},
    "KAL": {"name": "Kalam",              "city": "Kalam",           "aliases": ["kalam", "kal"],           "bus_only": True},
    "NRN": {"name": "Naran",              "city": "Naran",           "aliases": ["naran", "kaghan", "naran kaghan"], "bus_only": True},
    "HNZ": {"name": "Hunza",              "city": "Hunza",           "aliases": ["hunza", "karimabad", "aliabad"],   "bus_only": True},
}


def _resolve_station(city: str) -> str | None:
    """Map a free-text city name to an internal station code."""
    city_lower = city.strip().lower()
    for code, info in STATIONS.items():
        if city_lower in info["aliases"] or city_lower == info["city"].lower():
            return code
    return None


# Train schedule definitions
# Each train has fixed origin/destination and class pricing

# Buses (NATCO/KKH) aren't in Pakistan Railways' fare table at all — no official
# anchor exists, so these stay a plain min/max band scaled by distance.
_BUS_BASE_PRICES: dict[str, dict[str, float]] = {
    "BUS-STD": {"min": 2500,  "max": 7500},   # Standard Bus (KKH/NATCO)
    "BUS-AC":  {"min": 4000,  "max": 11000},  # AC Bus (KKH/NATCO)
}

# Rail fare curves, sourced from Pakistan Railways' official "Passenger Fare
# Table at a Glance" (effective 20 Apr 2025, pakrail.gov.pk). Each tuple is
# (fraction_of_KHI_PEW_distance, Economy, AC Standard, AC Business, AC Sleeper,
# AC Parlour) PKR. `fraction` is journey distance ÷ 1680km (the Karachi-Peshawar
# main line, the longest route in this dataset) — real fares are per-km, not
# per-stop, so pricing is keyed on distance rather than the number of stations
# a train happens to call at.
#
# Four tiers exist in the official table, and every named train in this
# dataset falls into exactly one of them:
#   "premium" — Karachi, Business, Karakoram, Jaffar, Tezgam & All Special Trains
#   "legacy"  — Khyber Mail, Millat, Bahauddin Zakria, Sukkur, Shalimar, Awam,
#               Bolan & other plain mail/express trains
#   "green_line" / "shah_husain" — priced independently, not a multiple of
#               either tier above (confirmed against the official table)
_KM_REF = 1680.0  # Karachi-Peshawar, the longest route this dataset prices

_RAIL_FARE_CLASSES = ["EC", "AC", "ACB", "SL", "PAR"]

_RAIL_FARE_CURVES: dict[str, list[tuple[float, ...]]] = {
    "premium": [
        (0.0000,  150,  450,  850,   950,  650),
        (0.0970,  700,  1100, 1800,  2500, 1650),
        (0.2833,  1950, 3050, 3750,  5900, 3350),
        (0.4720,  3050, 4750, 6300,  9050, 5650),
        (0.7226,  4300, 7050, 9800,  12500, 8850),
        (1.0000,  5250, 9800, 11850, 16050, 11600),
    ],
    "legacy": [
        (0.0000,  100,  350,  700,   800,   550),
        (0.0970,  650,  1000, 1400,  1600,  1200),
        (0.2833,  1400, 2700, 3550,  5550,  3200),
        (0.4720,  2350, 4400, 5850,  8600,  5600),
        (0.7226,  3150, 6300, 9050,  11700, 8300),
        (1.0000,  4200, 9700, 11150, 15050, 10700),
    ],
    # No AC Sleeper on Green Line — the SL column is never read for this train
    # (its "classes" list excludes SL) so the placeholder value is inert.
    "green_line": [
        (0.0000,  600,  1100, 1400,  1400,  1250),
        (0.0970,  600,  1100, 1400,  1400,  1250),
        (0.2833,  2450, 4050, 5100,  5100,  4550),
        (0.4720,  3600, 6200, 7750,  7750,  7000),
        (0.7226,  4800, 9100, 11400, 11400, 10300),
    ],
    # No AC Sleeper or Parlour on Shah Hussein — same inert-placeholder note.
    "shah_husain": [
        (0.0000,  300,  850,  1200, 1200, 1200),
        (0.0970,  1050, 1750, 2150, 2150, 2150),
        (0.1786,  1600, 3000, 3450, 3450, 3450),
        (0.2798,  1850, 3700, 4650, 4650, 4650),
    ],
}

# Each train's own full-route distance (km) — real-world approximate, used to
# convert its schedule (hours from departure, already tracked for arrival-time
# math) into a real km position for every stop, proportionally. Two trains
# that reach the same city share that city's real distance; only each train's
# own endpoint needs a value here.
_TRAIN_TOTAL_KM: dict[str, float] = {
    "TR-001": 1680,  # Tezgam Express: Karachi-Peshawar
    "TR-002": 1490,  # Karakoram Express: Karachi-Rawalpindi
    "TR-003": 1214,  # Green Line Express: Karachi-Lahore
    "TR-004": 1680,  # Khyber Mail: Karachi-Peshawar
    "TR-005": 1214,  # Awam Express: Karachi-Lahore
    "TR-006": 1214,  # Business Express: Karachi-Lahore
    "TR-007": 1500,  # Islamabad Express: Karachi-Islamabad
    "TR-008": 1335,  # Shalimar Express: Karachi-Sialkot
    "TR-009": 470,   # Shah Hussein Express: Lahore-Peshawar
    "TR-010": 476,   # Sukkur Express: Karachi-Sukkur
    "TR-011": 1300,  # Jaffar Express: Rawalpindi-Quetta
    "TR-012": 1214,  # Bolan Mail: Karachi-Lahore
    "TR-013": 1214,  # Lahore Express: Karachi-Lahore
    "TR-014": 1030,  # Faisalabad Express: Karachi-Faisalabad
    "TR-015": 1214,  # Bahauddin Zakaria Express: Karachi-Lahore
    "TR-016": 500,   # NATCO KKH Bus: Islamabad-Gilgit (road distance)
}

# Which official fare tier each train belongs to — trains named explicitly in
# the official table are placed in their stated tier; the few not named
# (Islamabad/Lahore/Faisalabad Express) are placed by train character (special
# express -> premium; plain express -> legacy).
_TRAIN_TIER: dict[str, str] = {
    "TR-001": "premium",      # Tezgam Express (named)
    "TR-002": "premium",      # Karakoram Express (named)
    "TR-003": "green_line",   # Green Line Express (named)
    "TR-004": "legacy",       # Khyber Mail (named)
    "TR-005": "legacy",       # Awam Express (named)
    "TR-006": "premium",      # Business Express (named)
    "TR-007": "premium",      # Islamabad Express ("& All Special Trains")
    "TR-008": "legacy",       # Shalimar Express (named)
    "TR-009": "shah_husain",  # Shah Hussein Express (named)
    "TR-010": "legacy",       # Sukkur Express (named)
    "TR-011": "premium",      # Jaffar Express (named)
    "TR-012": "legacy",       # Bolan Mail (named)
    "TR-013": "legacy",       # Lahore Express (plain express, unnamed)
    "TR-014": "legacy",       # Faisalabad Express (plain express, unnamed)
    "TR-015": "legacy",       # Bahauddin Zakaria Express (named as "Bahauddin Zakria")
    "TR-016": "bus",          # NATCO KKH Bus — not a Pakistan Railways service
}

# Seat amenities per class
_CLASS_AMENITIES: dict[str, list[str]] = {
    "EC":      ["Fan", "Cushioned Seats"],
    "AC":      ["Air Conditioning", "Reclining Seats", "Power Outlet"],
    "ACB":     ["Air Conditioning", "Wide Reclining Seats", "Power Outlet", "Meal Included"],
    "SL":      ["Fan", "Berths", "Bedding Provided"],
    "PAR":     ["Air Conditioning", "Private Cabin", "Meal Included", "Dedicated Attendant"],
    "BUS-STD": ["Reclining Seats", "Storage Compartment", "KKH Scenic Route"],
    "BUS-AC":  ["Air Conditioning", "Reclining Seats", "WiFi", "Storage Compartment", "KKH Scenic Route"],
}

# Canonical train definitions
_TRAINS: list[dict[str, Any]] = [
    {
        "id": "TR-001", "name": "Tezgam Express", "number": "7-Up/8-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE", "GUJ", "RWP", "ISB", "ATK", "PEW"],
        "schedule": {  # departure from each station (hours from midnight KHI dep)
            "KHI": 0, "HYD": 2.5, "SKZ": 6, "MUL": 10, "LHE": 15,
            "GUJ": 16.5, "RWP": 18.5, "ISB": 19, "ATK": 20, "PEW": 22,
        },
        "classes": ["EC", "AC", "ACB", "PAR"],
    },
    {
        "id": "TR-002", "name": "Karakoram Express", "number": "1-Up/2-Dn",
        "route": ["KHI", "HYD", "MUL", "LHE", "RWP"],
        "schedule": {"KHI": 0, "HYD": 2.5, "MUL": 9, "LHE": 13.5, "RWP": 16},
        "classes": ["EC", "AC", "ACB"],
    },
    {
        "id": "TR-003", "name": "Green Line Express", "number": "23-Up/24-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7, "MUL": 11, "LHE": 16},
        "classes": ["AC", "ACB", "PAR"],
    },
    {
        "id": "TR-004", "name": "Khyber Mail", "number": "1-Dn/2-Up",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE", "RWP", "PEW"],
        "schedule": {"KHI": 0, "HYD": 2, "SKZ": 5.5, "MUL": 9.5, "LHE": 14.5,
                     "RWP": 17, "PEW": 20},
        "classes": ["EC", "AC", "SL"],
    },
    {
        "id": "TR-005", "name": "Awam Express", "number": "5-Up/6-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7.5, "MUL": 12, "LHE": 17},
        "classes": ["EC"],
    },
    {
        "id": "TR-006", "name": "Business Express", "number": "31-Up/32-Dn",
        "route": ["KHI", "MUL", "LHE"],
        "schedule": {"KHI": 0, "MUL": 9, "LHE": 14},
        "classes": ["AC", "ACB", "PAR"],
    },
    {
        "id": "TR-007", "name": "Islamabad Express", "number": "9-Up/10-Dn",
        "route": ["KHI", "HYD", "MUL", "LHE", "RWP", "ISB"],
        "schedule": {"KHI": 0, "HYD": 2.5, "MUL": 9, "LHE": 13.5, "RWP": 16.5, "ISB": 17},
        "classes": ["EC", "AC", "ACB"],
    },
    {
        "id": "TR-008", "name": "Shalimar Express", "number": "45-Up/46-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE", "GUJ", "SKT"],
        "schedule": {"KHI": 0, "HYD": 2.5, "SKZ": 6, "MUL": 10, "LHE": 15,
                     "GUJ": 16.5, "SKT": 18},
        "classes": ["EC", "AC"],
    },
    {
        "id": "TR-009", "name": "Shah Hussein Express", "number": "51-Up/52-Dn",
        "route": ["LHE", "GUJ", "RWP", "ISB", "PEW"],
        "schedule": {"LHE": 0, "GUJ": 1.5, "RWP": 4, "ISB": 4.5, "PEW": 7},
        "classes": ["EC", "AC", "ACB"],
    },
    {
        "id": "TR-010", "name": "Sukkur Express", "number": "41-Up/42-Dn",
        "route": ["KHI", "HYD", "SKZ"],
        "schedule": {"KHI": 0, "HYD": 2.5, "SKZ": 6},
        "classes": ["EC", "AC"],
    },
    {
        "id": "TR-011", "name": "Jaffar Express", "number": "53-Up/54-Dn",
        "route": ["RWP", "ATK", "QTA"],
        "schedule": {"RWP": 0, "ATK": 1.5, "QTA": 24},
        "classes": ["EC", "AC", "SL"],
    },
    {
        "id": "TR-012", "name": "Bolan Mail", "number": "58-Dn/57-Up",
        "route": ["KHI", "HYD", "SKZ", "SUK", "MUL", "KOT", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7, "SUK": 8.5,
                     "MUL": 12.5, "KOT": 14, "LHE": 19},
        "classes": ["EC", "SL"],
    },
    {
        "id": "TR-013", "name": "Lahore Express", "number": "21-Up/22-Dn",
        "route": ["KHI", "MUL", "SHD", "LHE"],
        "schedule": {"KHI": 0, "MUL": 9.5, "SHD": 12, "LHE": 14},
        "classes": ["EC", "AC"],
    },
    {
        "id": "TR-014", "name": "Faisalabad Express", "number": "11-Up/12-Dn",
        "route": ["KHI", "MUL", "LYP"],
        "schedule": {"KHI": 0, "MUL": 9, "LYP": 13.5},
        "classes": ["EC", "AC"],
    },
    {
        "id": "TR-015", "name": "Bahauddin Zakaria Express", "number": "33-Up/34-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "BWP", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7, "MUL": 11, "BWP": 13, "LHE": 17},
        "classes": ["EC", "AC", "ACB"],
    },
    {
        "id": "TR-016", "name": "NATCO Karakoram Highway Bus", "number": "KKH-1",
        "route": ["ISB", "ABT", "GIL"],
        "schedule": {"ISB": 0, "ABT": 2.5, "GIL": 13},
        "classes": ["BUS-STD", "BUS-AC"],
        "bus_only": True,
    },
]

_CLASS_NAMES: dict[str, str] = {
    "EC":      "Economy",
    "AC":      "AC Standard",
    "ACB":     "AC Business",
    "SL":      "Sleeper",
    "PAR":     "Parlour Car",
    "BUS-STD": "Standard Bus",
    "BUS-AC":  "AC Bus",
}


# Core search logic

def _is_reverse(train: dict, origin_code: str, dest_code: str) -> bool:
    """
    Is this journey running against the stored stop order?

    Every route in _TRAINS is written once, south-to-north (Karachi first), but
    the trains themselves run both ways — the numbers say so: "7-Up/8-Dn" is
    Pakistan Railways' notation for the two directions of one service.
    """
    route = train["route"]
    return route.index(origin_code) > route.index(dest_code)


def _hours_from_departure(train: dict, station_code: str, reverse: bool) -> float:
    """
    When this train calls at `station_code`, in hours from ITS OWN departure.

    The stored schedule is the Dn direction only. Running Up, the timetable is
    mirrored end to end: the last stop becomes hour 0 and the first becomes the
    arrival. `first + last - hours` does exactly that, which keeps every leg's
    duration identical in both directions — Lahore→Islamabad and
    Islamabad→Lahore are both 4h on the Tezgam, as they should be.

    It does NOT claim the Up service departs at the same clock time as the Dn
    one; real Up/Dn timings differ, and we have no data for that. Mirroring
    invents nothing beyond what the Dn timetable already states.
    """
    schedule = train["schedule"]
    if not reverse:
        return schedule[station_code]
    route = train["route"]
    return schedule[route[0]] + schedule[route[-1]] - schedule[station_code]


def _trains_for_route(origin_code: str, dest_code: str) -> list[dict]:
    """
    Return trains serving both stations, in EITHER direction.

    This used to require route.index(origin) < route.index(dest), which meant
    only the Dn direction ever matched. Since every route is stored
    Karachi-first, that made the entire southbound network invisible: Karachi →
    Lahore returned 11 trains and Lahore → Karachi returned none, and no return
    journey was bookable anywhere on the network.
    """
    return [
        train for train in _TRAINS
        if origin_code in train["route"] and dest_code in train["route"]
        and origin_code != dest_code
    ]


def _interpolate_rail_fare(tier: str, fraction: float, class_code: str) -> float:
    """Linear interpolation over the official fare-table anchors for one tier."""
    curve = _RAIL_FARE_CURVES.get(tier, _RAIL_FARE_CURVES["legacy"])
    fraction = max(0.0, min(1.0, fraction))
    try:
        col = _RAIL_FARE_CLASSES.index(class_code)
    except ValueError:
        col = 0

    if fraction <= curve[0][0]:
        return curve[0][col + 1]
    for (f0, *v0), (f1, *v1) in zip(curve, curve[1:]):
        if f0 <= fraction <= f1:
            t = (fraction - f0) / (f1 - f0) if f1 > f0 else 0.0
            return v0[col] + t * (v1[col] - v0[col])
    return curve[-1][col + 1]


def _calculate_price(
    train: dict,
    origin_code: str,
    dest_code: str,
    class_code: str,
    passengers: int,
) -> float:
    """
    Calculate ticket price from real journey distance and class, using the
    official Pakistan Railways fare-table tier this train belongs to.

    Distance is derived from the train's own schedule (hours from departure,
    already tracked for arrival-time math) scaled to its real total route
    length — hours-into-the-journey correlates with real distance far better
    than stop count does (Karachi-Lahore is 4 of Tezgam's 9 stops, 44%, but
    73% of its real Karachi-Peshawar distance).
    """
    reverse = _is_reverse(train, origin_code, dest_code)
    dep_hours = _hours_from_departure(train, origin_code, reverse)
    arr_hours = _hours_from_departure(train, dest_code, reverse)
    route = train["route"]
    total_hours = train["schedule"][route[-1]] - train["schedule"][route[0]]
    total_km = _TRAIN_TOTAL_KM.get(train["id"], 1214.0)
    journey_km = abs(arr_hours - dep_hours) / total_hours * total_km if total_hours else 0.0

    tier = _TRAIN_TIER.get(train["id"], "legacy")
    if tier == "bus":
        band = _BUS_BASE_PRICES.get(class_code, _BUS_BASE_PRICES["BUS-STD"])
        fraction = journey_km / total_km if total_km else 0.0
        fraction = max(0.0, min(1.0, fraction))
        base_price = band["min"] + (band["max"] - band["min"]) * fraction
    else:
        base_price = _interpolate_rail_fare(tier, journey_km / _KM_REF, class_code)

    final_price = base_price * passengers
    # ±5% realism jitter, but DETERMINISTIC — seeded on the fare's identity
    # (train / route / class), never on the call or passenger count. An unseeded
    # random.uniform() re-rolled on every search, so reprice_booking re-confirmed a
    # different number than the one quoted and the user was charged up to ±5% off.
    # Passengers are deliberately excluded from the seed so the per-seat fare is
    # stable and the party total stays an exact multiple of it.
    _jseed = int(hashlib.md5(
        f"jitter-{train['id']}-{origin_code}-{dest_code}-{class_code}".encode()
    ).hexdigest(), 16) % (2**32)
    jitter = random.Random(_jseed).uniform(0.95, 1.05)
    return round(final_price * jitter, 2)


def _build_offer(
    train: dict,
    origin_code: str,
    dest_code: str,
    travel_date: datetime,
    passengers: int,
) -> TrainOffer:
    reverse = _is_reverse(train, origin_code, dest_code)
    dep_hours = _hours_from_departure(train, origin_code, reverse)
    arr_hours = _hours_from_departure(train, dest_code, reverse)

    departure_at = travel_date + timedelta(hours=dep_hours)
    arrival_at = travel_date + timedelta(hours=arr_hours)

    total_minutes = int((arr_hours - dep_hours) * 60)
    h, m = divmod(total_minutes, 60)
    duration = f"{h}h {m}m" if m else f"{h}h"

    seat_classes: list[SeatClass] = []
    for code in train["classes"]:
        price = _calculate_price(train, origin_code, dest_code, code, passengers)
        _seed = int(hashlib.md5(
            f"{train['id']}-{origin_code}-{dest_code}-{code}-{travel_date.strftime('%Y%m%d')}".encode()
        ).hexdigest(), 16) % (2**32)
        seats_available = random.Random(_seed).randint(0, 80)
        seat_classes.append(
            SeatClass(
                class_name=_CLASS_NAMES.get(code) or code,
                class_code=code,
                price_pkr=price,
                seats_available=seats_available,
                amenities=_CLASS_AMENITIES.get(code, []),
            )
        )

    origin_info = STATIONS[origin_code]
    dest_info = STATIONS[dest_code]

    return TrainOffer(
        train_id=f"{train['id']}-{origin_code}-{dest_code}",
        train_name=train["name"],
        train_number=train["number"],
        origin=origin_info["city"],
        destination=dest_info["city"],
        departure_at=departure_at,
        arrival_at=arrival_at,
        duration=duration,
        classes=seat_classes,
    )


# Public API

def search_trains(
    origin: str,
    destination: str,
    travel_date: date,
    passengers: int = 1,
) -> TrainSearchResponse:
    """
    Search Pakistan Railways trains for the given route and date.
    Returns real train names and schedules with randomised seat availability.
    """
    origin_code = _resolve_station(origin)
    dest_code = _resolve_station(destination)

    # If we can't resolve station, return helpful empty response
    if not origin_code or not dest_code:
        return TrainSearchResponse(
            origin=origin, destination=destination,
            date=travel_date, count=0, trains=[],
        )

    # Check if either endpoint is bus-only (no Pakistan Railways coverage)
    origin_info = STATIONS.get(origin_code, {})
    dest_info = STATIONS.get(dest_code, {})
    if origin_info.get("bus_only") or dest_info.get("bus_only"):
        _BUS_OPERATORS: dict[str, str] = {
            "GIL": "NATCO (115-Shaheen) & Faisal Movers — depart from Rawalpindi/Islamabad",
            "SKD": "NATCO Skardu Service — depart from Islamabad (Pir Wadhai Terminal)",
            "ABT": "Daewoo Express & Faisal Movers — from Islamabad or Lahore",
            "SWT": "Daewoo Express — from Islamabad (approx 4 h)",
            "MZD": "NATCO & Kashmir Movers — from Rawalpindi",
            "KAL": "PTDC coach or private transport via Swat Valley",
            "NRN": "NATCO & Faisal Movers — from Islamabad (Pir Wadhai Terminal), approx 6-7h to Naran/Kaghan valley",
            "HNZ": "NATCO (115-Shaheen) & Faisal Movers — from Islamabad/Rawalpindi to Gilgit, then local transport onward to Hunza (~2.5h)",
        }
        bus_key = origin_code if origin_info.get("bus_only") else dest_code
        bus_info = _BUS_OPERATORS.get(bus_key, "NATCO or Daewoo Express from major cities")
        return TrainSearchResponse(
            origin=origin_info.get("city", origin),
            destination=dest_info.get("city", destination),
            date=travel_date, count=0, trains=[],
            notes=(
                "Pakistan Railways does not serve this route. "
                f"Road travel options: {bus_info}. "
                "Book at NATCO terminal or via Daewoo/Faisal Movers counters."
            ),
        )

    matching_trains = _trains_for_route(origin_code, dest_code)

    # Base datetime for the travel date (midnight)
    base_dt = datetime(travel_date.year, travel_date.month, travel_date.day, 0, 0, 0)

    offers: list[TrainOffer] = []
    for train in matching_trains:
        try:
            offer = _build_offer(train, origin_code, dest_code, base_dt, passengers)
            offers.append(offer)
        except Exception:
            continue

    # Sort by departure time
    offers.sort(key=lambda o: o.departure_at)

    return TrainSearchResponse(
        origin=origin_info["city"],
        destination=dest_info["city"],
        date=travel_date,
        count=len(offers),
        trains=offers,
    )


def get_train_offer(train_offer_id: str, passengers: int = 1) -> TrainOffer | None:
    """
    Reconstruct a train offer from its ID (format: TR-001-KHI-LHE).
    Used when the Flutter app needs to re-fetch a single offer detail.
    """
    # train_offer_id format: "TR-001-KHI-LHE" → ["TR", "001", "KHI", "LHE"]
    parts = train_offer_id.split("-")
    if len(parts) < 4:
        return None

    train_id = f"{parts[0]}-{parts[1]}"  # "TR-001"
    origin_code = parts[2]               # "KHI"
    dest_code = parts[3]                 # "LHE"

    train = next((t for t in _TRAINS if t["id"] == train_id), None)
    if not train:
        return None

    # PK wall-clock, not UTC: utcnow() rebuilt this offer against YESTERDAY
    # for every request between midnight and 5am Pakistan time.
    today = pk_now().replace(hour=0, minute=0, second=0, microsecond=0)
    return _build_offer(train, origin_code, dest_code, today, passengers)


def generate_pnr(booking_id: str, train_name: str) -> str:
    """
    Generate a realistic Pakistan Railways PNR (8 alphanumeric characters).
    Deterministic from booking_id so the same booking always gets the same PNR.
    """
    raw = f"PR-{booking_id}-{train_name}"
    digest = hashlib.md5(raw.encode()).hexdigest().upper()
    return f"PR{digest[:6]}"
