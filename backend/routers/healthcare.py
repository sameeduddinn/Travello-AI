# =============================================================================
# FILE: routers/healthcare.py
# PREFIX: /healthcare
# PURPOSE: Healthcare guidance — nearby hospitals, pharmacies, emergency numbers.
#          Uses OpenStreetMap Overpass live lookup first, then curated mock fallback.
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
from fastapi import APIRouter, HTTPException, Query, status

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/healthcare", tags=["Healthcare"])

_OVERPASS_URL = "https://overpass-api.de/api/interpreter"


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
    return f"https://www.openstreetmap.org/?mlat={lat}&mlon={lng}#map=15/{lat}/{lng}"


# ---------------------------------------------------------------------------
# City coordinates (for city-based lookup support)
# ---------------------------------------------------------------------------

_CITY_COORDS: dict[str, tuple[float, float]] = {
    # Major cities
    "karachi":          (24.8607, 67.0011),
    "lahore":           (31.5204, 74.3587),
    "islamabad":        (33.6844, 73.0479),
    "rawalpindi":       (33.5651, 73.0169),
    "multan":           (30.1575, 71.5249),
    "faisalabad":       (31.4504, 73.1350),
    "peshawar":         (34.0151, 71.5249),
    "quetta":           (30.1798, 66.9750),
    "sialkot":          (32.4945, 74.5229),
    "gujranwala":       (32.1877, 74.1945),
    "bahawalpur":       (29.3956, 71.6836),
    "hyderabad":        (25.3960, 68.3578),
    "sukkur":           (27.7052, 68.8574),
    "larkana":          (27.5580, 68.2150),
    "dera ghazi khan":  (30.0571, 70.6350),
    "dg khan":          (30.0571, 70.6350),
    "gwadar":           (25.1264, 62.3225),
    "mirpur":           (33.1475, 73.7511),
    # Northern Pakistan & tourism
    "skardu":           (35.2971, 75.6338),
    "gilgit":           (35.9208, 74.3149),
    "hunza":            (36.3167, 74.6500),
    "karimabad":        (36.3167, 74.6500),
    "aliabad":          (36.2185, 74.6513),
    "naran":            (34.9030, 73.6540),
    "kaghan":           (34.7733, 73.5419),
    "chitral":          (35.8518, 71.7864),
    "swat":             (34.7462, 72.3578),
    "mingora":          (34.7726, 72.3600),
    "abbottabad":       (34.1463, 73.2117),
    "mansehra":         (34.3300, 73.2000),
    "nathiagali":       (34.0741, 73.3778),
    "murree":           (33.9072, 73.3943),
    "muzaffarabad":     (34.3700, 73.4711),
    "rawalakot":        (33.8575, 73.7614),
    "ziarat":           (30.3810, 67.7285),
    "fairy meadows":    (35.3753, 74.5958),
    "kalash valley":    (35.7000, 71.6000),
    "bumburet":         (35.7200, 71.6500),
}


def _resolve_coordinates(
    lat: float | None,
    lng: float | None,
    lon: float | None,
    city: str | None,
) -> tuple[float, float]:
    final_lng = lng if lng is not None else lon
    if lat is not None and final_lng is not None:
        return lat, final_lng

    if city:
        coords = _CITY_COORDS.get(city.strip().lower())
        if coords:
            return coords

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Provide either lat/lng coordinates or a supported city name.",
    )


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
    {"name": "CMH Abbottabad", "city": "Abbottabad",
     "address": "Cantt, Abbottabad", "phone": "0992-9310401",
     "lat": 34.1490, "lng": 73.2135, "is_open": True},
    # Hunza
    {"name": "Aga Khan Health Service Aliabad", "city": "Hunza",
     "address": "Aliabad, Hunza", "phone": "05813-440077",
     "lat": 36.2185, "lng": 74.6513, "is_open": True},
    {"name": "DHQ Hospital Hunza (Karimabad)", "city": "Hunza",
     "address": "Karimabad, Hunza-Nagar", "phone": "05813-457001",
     "lat": 36.3168, "lng": 74.6541, "is_open": True},
    # Naran
    {"name": "Naran Emergency Health Centre", "city": "Naran",
     "address": "Main Bazaar, Naran", "phone": "0997-415001",
     "lat": 34.9065, "lng": 73.6511, "is_open": True},
    # Chitral
    {"name": "DHQ Hospital Chitral", "city": "Chitral",
     "address": "Ataliq Bazaar, Chitral", "phone": "0943-412026",
     "lat": 35.8508, "lng": 71.7882, "is_open": True},
    {"name": "Aga Khan Health Service Chitral", "city": "Chitral",
     "address": "Mastuj Road, Chitral", "phone": "0943-412200",
     "lat": 35.8530, "lng": 71.7910, "is_open": False},
    # Mansehra
    {"name": "DHQ Hospital Mansehra", "city": "Mansehra",
     "address": "Shinkiari Road, Mansehra", "phone": "0997-302401",
     "lat": 34.3298, "lng": 73.1974, "is_open": True},
    # Murree
    {"name": "DHQ Hospital Murree", "city": "Murree",
     "address": "The Mall, Murree", "phone": "051-3410501",
     "lat": 33.9072, "lng": 73.3903, "is_open": True},
    {"name": "CMH Murree", "city": "Murree",
     "address": "GPO Road, Murree", "phone": "051-3410601",
     "lat": 33.9090, "lng": 73.3940, "is_open": True},
    # Nathiagali
    {"name": "Nathiagali Health Centre", "city": "Nathiagali",
     "address": "Nathiagali Bazaar, KPK", "phone": "0992-380050",
     "lat": 34.0741, "lng": 73.3778, "is_open": True},
    # Rawalakot
    {"name": "DHQ Hospital Rawalakot", "city": "Rawalakot",
     "address": "Bazar Road, Rawalakot, AJK", "phone": "05824-440200",
     "lat": 33.8575, "lng": 73.7614, "is_open": True},
    # Mirpur
    {"name": "DHQ Hospital Mirpur", "city": "Mirpur",
     "address": "New Mirpur City, AJK", "phone": "05827-920001",
     "lat": 33.1475, "lng": 73.7511, "is_open": True},
    # Gujranwala
    {"name": "DHQ Hospital Gujranwala", "city": "Gujranwala",
     "address": "Peoples Colony, Gujranwala", "phone": "055-9200421",
     "lat": 32.1601, "lng": 74.1967, "is_open": True},
    {"name": "Govt. Victoria Hospital Gujranwala", "city": "Gujranwala",
     "address": "GT Road, Gujranwala", "phone": "055-9200401",
     "lat": 32.1877, "lng": 74.1945, "is_open": True},
    # Sialkot
    {"name": "Allama Iqbal Memorial Hospital", "city": "Sialkot",
     "address": "Paris Road, Sialkot", "phone": "052-9250101",
     "lat": 32.4921, "lng": 74.5400, "is_open": True},
    # Bahawalpur
    {"name": "Bahawal Victoria Hospital", "city": "Bahawalpur",
     "address": "Circular Road, Bahawalpur", "phone": "062-9250201",
     "lat": 29.3956, "lng": 71.6836, "is_open": True},
    # Hyderabad
    {"name": "Liaquat University Hospital", "city": "Hyderabad",
     "address": "Jamshoro Road, Hyderabad", "phone": "022-9200401",
     "lat": 25.3813, "lng": 68.3400, "is_open": True},
    {"name": "Civil Hospital Hyderabad", "city": "Hyderabad",
     "address": "Tilak Incline, Hyderabad", "phone": "022-9200301",
     "lat": 25.3960, "lng": 68.3578, "is_open": True},
    # Sukkur
    {"name": "DHQ Hospital Sukkur", "city": "Sukkur",
     "address": "Military Road, Sukkur", "phone": "071-9310101",
     "lat": 27.7052, "lng": 68.8574, "is_open": True},
    # Larkana
    {"name": "Chandka Medical College Hospital", "city": "Larkana",
     "address": "Dokri Road, Larkana", "phone": "074-9310201",
     "lat": 27.5580, "lng": 68.2150, "is_open": True},
    # Dera Ghazi Khan
    {"name": "DHQ Hospital Dera Ghazi Khan", "city": "Dera Ghazi Khan",
     "address": "Hospital Road, DG Khan", "phone": "064-9260101",
     "lat": 30.0571, "lng": 70.6350, "is_open": True},
    # Gwadar
    {"name": "DHQ Hospital Gwadar", "city": "Gwadar",
     "address": "Shaheed Square, Gwadar", "phone": "0864-210101",
     "lat": 25.1264, "lng": 62.3225, "is_open": True},
    # Ziarat
    {"name": "DHQ Hospital Ziarat", "city": "Ziarat",
     "address": "Main Bazaar, Ziarat", "phone": "081-9201801",
     "lat": 30.3810, "lng": 67.7285, "is_open": True},
    # Fairy Meadows
    {"name": "Tato Basic Health Unit", "city": "Fairy Meadows",
     "address": "Tato Village, Near Fairy Meadows", "phone": "0346-5510001",
     "lat": 35.3520, "lng": 74.5800, "is_open": True},
    # Kalash Valley
    {"name": "Aga Khan Health Post Bumburet", "city": "Kalash Valley",
     "address": "Bumburet Valley, Chitral", "phone": "0943-416100",
     "lat": 35.7200, "lng": 71.6500, "is_open": False},
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
    {"name": "Hunza Pharmacy Aliabad", "city": "Hunza",
     "address": "Main Bazar, Aliabad, Hunza", "phone": "05813-440050",
     "lat": 36.2189, "lng": 74.6507, "is_open": True},
    {"name": "Skardu Medicos", "city": "Skardu",
     "address": "Yadgar Chowk, Skardu", "phone": "058-9270060",
     "lat": 35.2945, "lng": 75.6310, "is_open": True},
    {"name": "Chitral Medical Store", "city": "Chitral",
     "address": "Ataliq Bazaar, Chitral", "phone": "0943-412050",
     "lat": 35.8512, "lng": 71.7875, "is_open": True},
    {"name": "Naran Medical Store", "city": "Naran",
     "address": "Main Bazaar, Naran", "phone": "0997-415010",
     "lat": 34.9068, "lng": 73.6514, "is_open": True},
    {"name": "Swat Valley Pharmacy", "city": "Swat",
     "address": "Mingora Bazaar, Swat", "phone": "0946-9230060",
     "lat": 34.7730, "lng": 72.3605, "is_open": True},
    {"name": "Murree Medical Centre", "city": "Murree",
     "address": "The Mall, Murree", "phone": "051-3410510",
     "lat": 33.9074, "lng": 73.3907, "is_open": True},
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


def _parse_overpass_item(
    element: dict[str, Any],
    origin_lat: float,
    origin_lng: float,
    fallback_type: str,
) -> dict[str, Any] | None:
    tags = element.get("tags") or {}
    name = tags.get("name") or tags.get("name:en") or tags.get("brand")
    if not name:
        return None

    item_lat = element.get("lat") or (element.get("center") or {}).get("lat")
    item_lng = element.get("lon") or (element.get("center") or {}).get("lon")
    if item_lat is None or item_lng is None:
        return None

    addr_parts = [
        tags.get("addr:housenumber", ""),
        tags.get("addr:street", ""),
        tags.get("addr:suburb", ""),
        tags.get("addr:city", ""),
    ]
    address = ", ".join(part for part in addr_parts if part).strip() or "Address unavailable"

    phone = tags.get("phone") or tags.get("contact:phone")
    opening_hours = tags.get("opening_hours", "")
    is_open = True if "24/7" in opening_hours else None

    distance_km = round(_haversine_km(origin_lat, origin_lng, item_lat, item_lng), 2)

    poi_type = (
        tags.get("amenity")
        or tags.get("healthcare")
        or tags.get("tourism")
        or fallback_type
    )

    return {
        "place_id": f"osm-{element.get('type', 'node')}-{element.get('id', '0')}",
        "name": name,
        "address": address,
        "distance_km": distance_km,
        "phone": phone,
        "is_open": is_open,
        "lat": item_lat,
        "lng": item_lng,
        "maps_url": _maps_url(item_lat, item_lng),
        "rating": None,
        "type": str(poi_type).replace("_", " ").title(),
    }


async def _fetch_overpass_nearby(
    lat: float,
    lng: float,
    radius_km: float,
    place_type: str,
) -> list[dict[str, Any]]:
    """Fetch nearby healthcare places from OpenStreetMap Overpass."""
    radius_m = max(int(radius_km * 1000), 500)

    if place_type == "pharmacy":
        tag_patterns = [
            '"amenity"="pharmacy"',
            '"healthcare"="pharmacy"',
        ]
    else:
        tag_patterns = [
            '"amenity"~"hospital|clinic"',
            '"healthcare"~"hospital|clinic"',
        ]

    statements: list[str] = []
    for tag_pattern in tag_patterns:
        statements.extend(
            [
                f"node[{tag_pattern}](around:{radius_m},{lat},{lng});",
                f"way[{tag_pattern}](around:{radius_m},{lat},{lng});",
                f"relation[{tag_pattern}](around:{radius_m},{lat},{lng});",
            ]
        )

    query = "[out:json][timeout:20];(" + "".join(statements) + ");out center;"

    try:
        async with httpx.AsyncClient(timeout=22.0) as client:
            response = await client.post(_OVERPASS_URL, data={"data": query})

        if response.status_code != 200:
            logger.warning(
                "Overpass %s query failed with status %s",
                place_type,
                response.status_code,
            )
            return []

        elements = response.json().get("elements", [])
        parsed: list[dict[str, Any]] = []
        seen: set[tuple[str, float, float]] = set()

        for element in elements:
            item = _parse_overpass_item(element, lat, lng, place_type)
            if not item:
                continue

            dedupe_key = (
                item["name"].strip().lower(),
                round(float(item["lat"]), 4),
                round(float(item["lng"]), 4),
            )
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            parsed.append(item)

        parsed.sort(key=lambda x: x["distance_km"])
        return parsed[:10]
    except Exception as exc:
        logger.warning("Overpass %s lookup failed: %s", place_type, exc)
        return []


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/nearby")
async def get_nearby_hospitals(
    lat: float | None = Query(None, description="Latitude"),
    lng: float | None = Query(None, description="Longitude"),
    lon: float | None = Query(None, description="Longitude alias"),
    city: str | None = Query(None, description="City name fallback"),
    radius: float = Query(5.0, description="Search radius in km"),
) -> list[dict[str, Any]]:
    """
    Find hospitals near coordinates or by city name.
    Returns OpenStreetMap results first; falls back to curated Pakistani data.
    """
    resolved_lat, resolved_lng = _resolve_coordinates(lat, lng, lon, city)
    safe_radius = max(radius, 0.5)

    live_results = await _fetch_overpass_nearby(
        resolved_lat,
        resolved_lng,
        safe_radius,
        place_type="hospital",
    )
    if live_results:
        return live_results

    return _mock_nearby(resolved_lat, resolved_lng, safe_radius, _MOCK_HOSPITALS)


@router.get("/pharmacies")
async def get_nearby_pharmacies(
    lat: float | None = Query(None, description="Latitude"),
    lng: float | None = Query(None, description="Longitude"),
    lon: float | None = Query(None, description="Longitude alias"),
    city: str | None = Query(None, description="City name fallback"),
    radius: float = Query(5.0, description="Search radius in km"),
) -> list[dict[str, Any]]:
    """
    Find pharmacies near coordinates or by city name.
    Returns OpenStreetMap results first; falls back to curated Pakistani data.
    """
    resolved_lat, resolved_lng = _resolve_coordinates(lat, lng, lon, city)
    safe_radius = max(radius, 0.5)

    live_results = await _fetch_overpass_nearby(
        resolved_lat,
        resolved_lng,
        safe_radius,
        place_type="pharmacy",
    )
    if live_results:
        return live_results

    return _mock_nearby(resolved_lat, resolved_lng, safe_radius, _MOCK_PHARMACIES)


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
