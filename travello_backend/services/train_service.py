# =============================================================================
# FILE: services/train_service.py
# PURPOSE: Pakistan Railways mock service.
#          Uses real train names, station codes, and realistic schedules.
#          Pakistan Railways has no public API — this is standard FYP practice.
#
# Trains included (real Pakistan Railways trains):
#   Tezgam Express, Karakoram Express, Green Line, Khyber Mail,
#   Awam Express, Business Express, Islamabad Express, Shalimar Express,
#   Shah Hussein Express, Sukkur Express, Jaffar Express, Bolan Mail
# =============================================================================

from __future__ import annotations

import hashlib
import random
from datetime import date, datetime, timedelta
from typing import Any

from models.train import SeatClass, TrainOffer, TrainSearchResponse

# ---------------------------------------------------------------------------
# Station data — IATA-style codes used internally
# ---------------------------------------------------------------------------

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
}


def _resolve_station(city: str) -> str | None:
    """Map a free-text city name to an internal station code."""
    city_lower = city.strip().lower()
    for code, info in STATIONS.items():
        if city_lower in info["aliases"] or city_lower == info["city"].lower():
            return code
    return None


# ---------------------------------------------------------------------------
# Train schedule definitions
# Each train has fixed origin/destination and class pricing
# ---------------------------------------------------------------------------

# Price per passenger per seat class for the most common routes (in PKR)
# Intermediate routes are interpolated
_BASE_PRICES: dict[str, dict[str, float]] = {
    "EC":      {"min": 350,   "max": 1200},   # Economy
    "AC":      {"min": 1200,  "max": 4500},   # AC Standard
    "ACB":     {"min": 2200,  "max": 8500},   # AC Business
    "SL":      {"min": 800,   "max": 2800},   # Sleeper
    "PAR":     {"min": 3500,  "max": 12000},  # Parlour Car
    "BUS-STD": {"min": 500,   "max": 2000},   # Standard Bus (KKH/NATCO)
    "BUS-AC":  {"min": 1000,  "max": 4000},   # AC Bus (KKH/NATCO)
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
        "price_factor": 1.0,
    },
    {
        "id": "TR-002", "name": "Karakoram Express", "number": "1-Up/2-Dn",
        "route": ["KHI", "HYD", "MUL", "LHE", "RWP"],
        "schedule": {"KHI": 0, "HYD": 2.5, "MUL": 9, "LHE": 13.5, "RWP": 16},
        "classes": ["EC", "AC", "ACB"],
        "price_factor": 0.9,
    },
    {
        "id": "TR-003", "name": "Green Line Express", "number": "23-Up/24-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7, "MUL": 11, "LHE": 16},
        "classes": ["AC", "ACB", "PAR"],
        "price_factor": 1.3,
    },
    {
        "id": "TR-004", "name": "Khyber Mail", "number": "1-Dn/2-Up",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE", "RWP", "PEW"],
        "schedule": {"KHI": 0, "HYD": 2, "SKZ": 5.5, "MUL": 9.5, "LHE": 14.5,
                     "RWP": 17, "PEW": 20},
        "classes": ["EC", "AC", "SL"],
        "price_factor": 0.85,
    },
    {
        "id": "TR-005", "name": "Awam Express", "number": "5-Up/6-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7.5, "MUL": 12, "LHE": 17},
        "classes": ["EC"],
        "price_factor": 0.55,
    },
    {
        "id": "TR-006", "name": "Business Express", "number": "31-Up/32-Dn",
        "route": ["KHI", "MUL", "LHE"],
        "schedule": {"KHI": 0, "MUL": 9, "LHE": 14},
        "classes": ["AC", "ACB", "PAR"],
        "price_factor": 1.5,
    },
    {
        "id": "TR-007", "name": "Islamabad Express", "number": "9-Up/10-Dn",
        "route": ["KHI", "HYD", "MUL", "LHE", "RWP", "ISB"],
        "schedule": {"KHI": 0, "HYD": 2.5, "MUL": 9, "LHE": 13.5, "RWP": 16.5, "ISB": 17},
        "classes": ["EC", "AC", "ACB"],
        "price_factor": 1.1,
    },
    {
        "id": "TR-008", "name": "Shalimar Express", "number": "45-Up/46-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "LHE", "GUJ", "SKT"],
        "schedule": {"KHI": 0, "HYD": 2.5, "SKZ": 6, "MUL": 10, "LHE": 15,
                     "GUJ": 16.5, "SKT": 18},
        "classes": ["EC", "AC"],
        "price_factor": 0.95,
    },
    {
        "id": "TR-009", "name": "Shah Hussein Express", "number": "51-Up/52-Dn",
        "route": ["LHE", "GUJ", "RWP", "ISB", "PEW"],
        "schedule": {"LHE": 0, "GUJ": 1.5, "RWP": 4, "ISB": 4.5, "PEW": 7},
        "classes": ["EC", "AC", "ACB"],
        "price_factor": 1.0,
    },
    {
        "id": "TR-010", "name": "Sukkur Express", "number": "41-Up/42-Dn",
        "route": ["KHI", "HYD", "SKZ"],
        "schedule": {"KHI": 0, "HYD": 2.5, "SKZ": 6},
        "classes": ["EC", "AC"],
        "price_factor": 0.7,
    },
    {
        "id": "TR-011", "name": "Jaffar Express", "number": "53-Up/54-Dn",
        "route": ["RWP", "ATK", "QTA"],
        "schedule": {"RWP": 0, "ATK": 1.5, "QTA": 24},
        "classes": ["EC", "AC", "SL"],
        "price_factor": 1.2,
    },
    {
        "id": "TR-012", "name": "Bolan Mail", "number": "58-Dn/57-Up",
        "route": ["KHI", "HYD", "SKZ", "SUK", "MUL", "KOT", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7, "SUK": 8.5,
                     "MUL": 12.5, "KOT": 14, "LHE": 19},
        "classes": ["EC", "SL"],
        "price_factor": 0.75,
    },
    {
        "id": "TR-013", "name": "Lahore Express", "number": "21-Up/22-Dn",
        "route": ["KHI", "MUL", "SHD", "LHE"],
        "schedule": {"KHI": 0, "MUL": 9.5, "SHD": 12, "LHE": 14},
        "classes": ["EC", "AC"],
        "price_factor": 0.9,
    },
    {
        "id": "TR-014", "name": "Faisalabad Express", "number": "11-Up/12-Dn",
        "route": ["KHI", "MUL", "LYP"],
        "schedule": {"KHI": 0, "MUL": 9, "LYP": 13.5},
        "classes": ["EC", "AC"],
        "price_factor": 0.88,
    },
    {
        "id": "TR-015", "name": "Bahauddin Zakaria Express", "number": "33-Up/34-Dn",
        "route": ["KHI", "HYD", "SKZ", "MUL", "BWP", "LHE"],
        "schedule": {"KHI": 0, "HYD": 3, "SKZ": 7, "MUL": 11, "BWP": 13, "LHE": 17},
        "classes": ["EC", "AC", "ACB"],
        "price_factor": 0.95,
    },
    {
        "id": "TR-016", "name": "NATCO Karakoram Highway Bus", "number": "KKH-1",
        "route": ["ISB", "ABT", "GIL"],
        "schedule": {"ISB": 0, "ABT": 2.5, "GIL": 13},
        "classes": ["BUS-STD", "BUS-AC"],
        "price_factor": 0.6,
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


# ---------------------------------------------------------------------------
# Core search logic
# ---------------------------------------------------------------------------

def _trains_for_route(origin_code: str, dest_code: str) -> list[dict]:
    """Return trains that serve both origin and destination in the correct order."""
    results = []
    for train in _TRAINS:
        route = train["route"]
        if origin_code in route and dest_code in route:
            if route.index(origin_code) < route.index(dest_code):
                results.append(train)
    return results


def _calculate_price(
    train: dict,
    origin_code: str,
    dest_code: str,
    class_code: str,
    passengers: int,
) -> float:
    """
    Calculate ticket price based on route distance (number of stops) and class.
    Uses a band from _BASE_PRICES scaled by number of route segments.
    """
    route = train["route"]
    o_idx = route.index(origin_code)
    d_idx = route.index(dest_code)
    total_stops = len(route) - 1
    journey_stops = d_idx - o_idx
    fraction = journey_stops / max(total_stops, 1)

    band = _BASE_PRICES.get(class_code, _BASE_PRICES["EC"])
    price_range = band["max"] - band["min"]
    base_price = band["min"] + price_range * fraction
    final_price = base_price * train.get("price_factor", 1.0) * passengers
    # Add small randomness for realism (±5%)
    jitter = random.uniform(0.95, 1.05)
    return round(final_price * jitter, 2)


def _build_offer(
    train: dict,
    origin_code: str,
    dest_code: str,
    travel_date: datetime,
    passengers: int,
) -> TrainOffer:
    schedule = train["schedule"]
    dep_hours = schedule[origin_code]
    arr_hours = schedule[dest_code]

    departure_at = travel_date + timedelta(hours=dep_hours)
    arrival_at = travel_date + timedelta(hours=arr_hours)

    total_minutes = int((arr_hours - dep_hours) * 60)
    h, m = divmod(total_minutes, 60)
    duration = f"{h}h {m}m" if m else f"{h}h"

    seat_classes: list[SeatClass] = []
    for code in train["classes"]:
        price = _calculate_price(train, origin_code, dest_code, code, passengers)
        _seed = hash(f"{train['id']}-{origin_code}-{dest_code}-{travel_date.strftime('%Y%m%d')}") % (2**32)
        seats_available = random.Random(_seed).randint(0, 80)
        seat_classes.append(
            SeatClass(
                class_name=_CLASS_NAMES.get(code, code),
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


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

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
        origin=origin,
        destination=destination,
        date=travel_date,
        count=len(offers),
        trains=offers,
    )


def get_train_offer(train_offer_id: str, passengers: int = 1) -> TrainOffer | None:
    """
    Reconstruct a train offer from its ID (format: TR-XXX-ORI-DST).
    Used when the Flutter app needs to re-fetch a single offer detail.
    """
    # train_offer_id format: "TR-001-KHI-LHE"
    parts = train_offer_id.split("-")
    if len(parts) < 5:
        return None

    train_id = f"{parts[0]}-{parts[1]}-{parts[2]}"  # e.g. TR-001
    origin_code = parts[3]
    dest_code = parts[4]

    train = next((t for t in _TRAINS if t["id"] == train_id), None)
    if not train:
        return None

    today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    return _build_offer(train, origin_code, dest_code, today, passengers)


def generate_pnr(booking_id: str, train_name: str) -> str:
    """
    Generate a realistic Pakistan Railways PNR (8 alphanumeric characters).
    Deterministic from booking_id so the same booking always gets the same PNR.
    """
    raw = f"PR-{booking_id}-{train_name}"
    digest = hashlib.md5(raw.encode()).hexdigest().upper()
    return f"PR{digest[:6]}"
