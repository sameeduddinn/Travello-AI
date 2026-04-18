# =============================================================================
# FILE: routers/healthcare.py
# PREFIX: /healthcare
# PURPOSE: Healthcare guidance — nearby hospitals, pharmacies, emergency numbers.
#          Uses Google Places API if configured; falls back to curated mock data.
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // GET /healthcare/nearby
# Future<List<dynamic>> getNearbyHospitals({
#   required double lat,
#   required double lng,
#   double radiusKm = 5.0,
# }) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/healthcare/nearby?lat=$lat&lng=$lng&radius=$radiusKm'),
#   );
#   final data = jsonDecode(res.body) as List<dynamic>;
#   // Each item: {name, address, distance_km, phone, is_open, lat, lng, maps_url}
#   // Open with: launchUrl(Uri.parse(item['maps_url']))
#   return data;
# }
#
# // GET /healthcare/emergency-numbers
# Future<Map<String, dynamic>> getEmergencyNumbers() async {
#   final res = await http.get(Uri.parse('$baseUrl/healthcare/emergency-numbers'));
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // GET /healthcare/pharmacies
# Future<List<dynamic>> getNearbyPharmacies({
#   required double lat,
#   required double lng,
# }) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/healthcare/pharmacies?lat=$lat&lng=$lng'),
#   );
#   return jsonDecode(res.body) as List<dynamic>;
# }
# =============================================================================

from __future__ import annotations

import logging
import math
from typing import Any

import httpx
from fastapi import APIRouter, Query

from core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/healthcare", tags=["Healthcare"])

GOOGLE_PLACES_BASE = "https://maps.googleapis.com/maps/api/place"


# ---------------------------------------------------------------------------
# Haversine distance helper
# ---------------------------------------------------------------------------

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _maps_url(lat: float, lng: float) -> str:
    return f"https://www.google.com/maps/dir/?api=1&destination={lat},{lng}"


# ---------------------------------------------------------------------------
# Google Places nearby search
# ---------------------------------------------------------------------------

async def _google_nearby(
    lat: float,
    lng: float,
    radius_m: int,
    place_type: str,
) -> list[dict[str, Any]]:
    if not settings.GOOGLE_PLACES_API_KEY:
        return []
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{GOOGLE_PLACES_BASE}/nearbysearch/json",
                params={
                    "location": f"{lat},{lng}",
                    "radius": radius_m,
                    "type": place_type,
                    "key": settings.GOOGLE_PLACES_API_KEY,
                },
            )
        if resp.status_code != 200:
            logger.warning("Google Places error %d", resp.status_code)
            return []
        data = resp.json()
        results = data.get("results", [])
        out = []
        for r in results[:10]:
            loc = r.get("geometry", {}).get("location", {})
            p_lat = loc.get("lat", lat)
            p_lng = loc.get("lng", lng)
            out.append({
                "place_id": r.get("place_id", ""),
                "name": r.get("name", ""),
                "address": r.get("vicinity", ""),
                "distance_km": round(_haversine_km(lat, lng, p_lat, p_lng), 2),
                "phone": None,
                "is_open": r.get("opening_hours", {}).get("open_now"),
                "lat": p_lat,
                "lng": p_lng,
                "maps_url": _maps_url(p_lat, p_lng),
                "rating": r.get("rating"),
            })
        return out
    except Exception as exc:
        logger.error("Google Places request failed: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Mock Pakistani hospital data (fallback when no API key)
# ---------------------------------------------------------------------------

_MOCK_HOSPITALS: list[dict[str, Any]] = [
    # Karachi
    {"name": "Aga Khan University Hospital", "city": "Karachi",
     "address": "Stadium Road, Karachi", "phone": "021-34930051",
     "lat": 24.8918, "lng": 67.0766, "is_open": True},
    {"name": "Liaquat National Hospital", "city": "Karachi",
     "address": "National Stadium Road, Karachi", "phone": "021-99201300",
     "lat": 24.8943, "lng": 67.0743, "is_open": True},
    {"name": "Ziauddin Hospital", "city": "Karachi",
     "address": "Clifton, Karachi", "phone": "021-35862937",
     "lat": 24.8217, "lng": 67.0310, "is_open": True},
    # Lahore
    {"name": "Services Hospital Lahore", "city": "Lahore",
     "address": "Jail Road, Lahore", "phone": "042-99203406",
     "lat": 31.5270, "lng": 74.3243, "is_open": True},
    {"name": "Shaukat Khanum Cancer Hospital", "city": "Lahore",
     "address": "Johar Town, Lahore", "phone": "042-35945100",
     "lat": 31.4669, "lng": 74.2647, "is_open": True},
    {"name": "Mayo Hospital Lahore", "city": "Lahore",
     "address": "The Mall, Lahore", "phone": "042-99203406",
     "lat": 31.5697, "lng": 74.3217, "is_open": True},
    # Islamabad
    {"name": "PIMS Hospital Islamabad", "city": "Islamabad",
     "address": "Shifa Road, Islamabad", "phone": "051-9261170",
     "lat": 33.7120, "lng": 73.0671, "is_open": True},
    {"name": "Shifa International Hospital", "city": "Islamabad",
     "address": "Pitras Bukhari Road, Islamabad", "phone": "051-8464646",
     "lat": 33.7128, "lng": 73.0591, "is_open": True},
    # Skardu
    {"name": "Combined Military Hospital (CMH) Skardu", "city": "Skardu",
     "address": "Airport Road, Skardu", "phone": "058-9270255",
     "lat": 35.2955, "lng": 75.6324, "is_open": True},
    {"name": "DHQ Hospital Skardu", "city": "Skardu",
     "address": "Yadgar Chowk, Skardu", "phone": "058-9270100",
     "lat": 35.2941, "lng": 75.6307, "is_open": True},
    # Gilgit
    {"name": "DHQ Hospital Gilgit", "city": "Gilgit",
     "address": "Hospital Road, Gilgit", "phone": "058-1920100",
     "lat": 35.9219, "lng": 74.3099, "is_open": True},
    {"name": "Aga Khan Health Service Gilgit", "city": "Gilgit",
     "address": "Jutial, Gilgit", "phone": "058-1920200",
     "lat": 35.9201, "lng": 74.3076, "is_open": True},
    # Peshawar
    {"name": "Lady Reading Hospital", "city": "Peshawar",
     "address": "Grand Trunk Road, Peshawar", "phone": "091-9211267",
     "lat": 34.0050, "lng": 71.5481, "is_open": True},
    # Quetta
    {"name": "Bolan Medical Complex Hospital", "city": "Quetta",
     "address": "Jail Road, Quetta", "phone": "081-9201070",
     "lat": 30.1968, "lng": 66.9895, "is_open": True},
    # Multan
    {"name": "Nishtar Hospital Multan", "city": "Multan",
     "address": "Nishtar Road, Multan", "phone": "061-9200160",
     "lat": 30.1832, "lng": 71.4768, "is_open": True},
    # Swat
    {"name": "Saidu Group of Teaching Hospitals", "city": "Swat",
     "address": "Saidu Sharif, Swat", "phone": "0946-9230007",
     "lat": 34.7449, "lng": 72.3560, "is_open": True},
    # Muzaffarabad
    {"name": "CMH Muzaffarabad", "city": "Muzaffarabad",
     "address": "AJK Road, Muzaffarabad", "phone": "05822-42614",
     "lat": 34.3596, "lng": 73.4714, "is_open": True},
    # Abbottabad
    {"name": "Ayub Teaching Hospital", "city": "Abbottabad",
     "address": "Mansehra Road, Abbottabad", "phone": "0992-381166",
     "lat": 34.1606, "lng": 73.2180, "is_open": True},
]

_MOCK_PHARMACIES: list[dict[str, Any]] = [
    {"name": "Fazal Din's Pharmacy", "city": "Karachi",
     "address": "M.A. Jinnah Road, Karachi", "phone": "021-32720271",
     "lat": 24.8700, "lng": 67.0100, "is_open": True},
    {"name": "Fazal Din's Pharmacy", "city": "Lahore",
     "address": "MM Alam Road, Gulberg, Lahore", "phone": "042-35752151",
     "lat": 31.5085, "lng": 74.3403, "is_open": True},
    {"name": "Medics Pharmacy", "city": "Islamabad",
     "address": "Blue Area, Islamabad", "phone": "051-2826061",
     "lat": 33.7248, "lng": 73.0953, "is_open": True},
    {"name": "Riaz Pharmacy", "city": "Peshawar",
     "address": "Saddar Road, Peshawar", "phone": "091-5275001",
     "lat": 34.0100, "lng": 71.5500, "is_open": True},
    {"name": "Shaheen Pharmacy", "city": "Skardu",
     "address": "Main Bazaar, Skardu", "phone": "058-9270050",
     "lat": 35.2960, "lng": 75.6320, "is_open": True},
    {"name": "Northern Pharmacy", "city": "Gilgit",
     "address": "KKH Road, Gilgit", "phone": "058-1920060",
     "lat": 35.9215, "lng": 74.3095, "is_open": True},
]


def _mock_nearby(
    lat: float,
    lng: float,
    radius_km: float,
    source: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    results = []
    for h in source:
        dist = _haversine_km(lat, lng, h["lat"], h["lng"])
        if dist <= radius_km:
            results.append({
                "place_id": f"mock-{h['name'].replace(' ', '-').lower()}",
                "name": h["name"],
                "address": h["address"],
                "distance_km": round(dist, 2),
                "phone": h.get("phone"),
                "is_open": h.get("is_open"),
                "lat": h["lat"],
                "lng": h["lng"],
                "maps_url": _maps_url(h["lat"], h["lng"]),
                "rating": None,
            })
    # If nothing within radius, return closest 3 from the full list
    if not results:
        all_sorted = sorted(
            source,
            key=lambda h: _haversine_km(lat, lng, h["lat"], h["lng"]),
        )
        for h in all_sorted[:3]:
            dist = _haversine_km(lat, lng, h["lat"], h["lng"])
            results.append({
                "place_id": f"mock-{h['name'].replace(' ', '-').lower()}",
                "name": h["name"],
                "address": h["address"],
                "distance_km": round(dist, 2),
                "phone": h.get("phone"),
                "is_open": h.get("is_open"),
                "lat": h["lat"],
                "lng": h["lng"],
                "maps_url": _maps_url(h["lat"], h["lng"]),
                "rating": None,
            })
    results.sort(key=lambda x: x["distance_km"])
    return results[:10]


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/nearby")
async def get_nearby_hospitals(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: float = Query(5.0, description="Search radius in km"),
) -> list[dict[str, Any]]:
    """
    Find hospitals near the given coordinates.
    Uses Google Places API if GOOGLE_PLACES_API_KEY is set, otherwise returns
    curated Pakistani hospital data (covers 11 major cities).
    """
    if settings.GOOGLE_PLACES_API_KEY:
        results = await _google_nearby(lat, lng, int(radius * 1000), "hospital")
        if results:
            return results

    return _mock_nearby(lat, lng, max(radius, 50.0), _MOCK_HOSPITALS)


@router.get("/pharmacies")
async def get_nearby_pharmacies(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: float = Query(5.0, description="Search radius in km"),
) -> list[dict[str, Any]]:
    """
    Find pharmacies near the given coordinates.
    Uses Google Places API if configured, otherwise returns mock data.
    """
    if settings.GOOGLE_PLACES_API_KEY:
        results = await _google_nearby(lat, lng, int(radius * 1000), "pharmacy")
        if results:
            return results

    return _mock_nearby(lat, lng, max(radius, 50.0), _MOCK_PHARMACIES)


@router.get("/emergency-numbers")
async def get_emergency_numbers() -> dict[str, Any]:
    """
    Pakistan emergency contacts and health tips for travellers.
    Includes altitude sickness guidance for northern areas (Skardu/Gilgit/Hunza).
    """
    return {
        "ambulance": [
            {"name": "Rescue Pakistan",    "number": "115",  "coverage": "Nationwide"},
            {"name": "Rescue Punjab",      "number": "1122", "coverage": "Punjab"},
            {"name": "Edhi Foundation",    "number": "115",  "coverage": "Nationwide"},
            {"name": "Aman Foundation",    "number": "1021", "coverage": "Karachi"},
            {"name": "Chhipa Welfare",     "number": "1020", "coverage": "Karachi/Sindh"},
        ],
        "police": "15",
        "fire": "16",
        "disaster_management": "1700",
        "tips": [
            "For altitude sickness in Skardu/Gilgit/Hunza: descend immediately and call 115.",
            "Nearest major hospital from Skardu: CMH Skardu (058-9270255).",
            "Nearest major hospital from Gilgit: DHQ Hospital Gilgit (058-1920100).",
            "Carry personal medication — pharmacies are scarce above 3000m.",
            "PIA medical emergency diversion is available on all northern-area flights.",
            "PEMRA mountain rescue team can be reached via local police (15) in GB.",
            "Drink bottled water in northern areas — tap water may cause GI issues.",
            "Travel insurance with evacuation cover is strongly recommended for trekking.",
        ],
    }
