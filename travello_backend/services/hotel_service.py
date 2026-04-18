# =============================================================================
# FILE: services/hotel_service.py
# PURPOSE: Hotel search via RapidAPI Hotels4 endpoint.
#          Falls back to rich mock data when RAPIDAPI_KEY is not set.
#          All prices are in PKR.
#
# RapidAPI Hotels4 free tier: https://rapidapi.com/apidojo/api/hotels4
#   - 500 requests/month free
#   - No credit card required for free tier
# =============================================================================

from __future__ import annotations

import logging
import random
from datetime import date
from typing import Any

import httpx

from core.config import settings
from models.hotel import HotelOffer, HotelSearchResponse, RoomOffer

logger = logging.getLogger(__name__)

RAPIDAPI_BASE = "https://tripadvisor-com1.p.rapidapi.com"

# ---------------------------------------------------------------------------
# City name normalisation — handles typos, aliases, IATA codes
# ---------------------------------------------------------------------------

CITY_ALIASES: dict[str, str] = {
    "hunza": "Hunza", "karimabad": "Hunza", "aliabad": "Hunza",
    "skardu": "Skardu", "skardo": "Skardu",
    "gilgit": "Gilgit", "gilgit baltistan": "Gilgit",
    "swat": "Swat", "mingora": "Swat",
    "abbottabad": "Abbottabad", "abbotabad": "Abbottabad",
    "murree": "Murree",
    "nathiagali": "Nathiagali", "nathia gali": "Nathiagali",
    "naran": "Naran", "kaghan": "Naran", "naran kaghan": "Naran",
    "muzaffarabad": "Muzaffarabad", "mzd": "Muzaffarabad",
    "bahawalpur": "Bahawalpur", "bwp": "Bahawalpur",
    "larkana": "Larkana",
    "sukkur": "Sukkur", "skz": "Sukkur",
    "hyderabad": "Hyderabad", "hyd": "Hyderabad",
    "sialkot": "Sialkot", "skt": "Sialkot",
    "karachi": "Karachi", "khi": "Karachi",
    "lahore": "Lahore", "lhe": "Lahore",
    "islamabad": "Islamabad", "isb": "Islamabad",
    "rawalpindi": "Rawalpindi", "rwp": "Rawalpindi", "pindi": "Rawalpindi",
    "multan": "Multan", "mul": "Multan",
    "peshawar": "Peshawar", "pew": "Peshawar",
    "quetta": "Quetta", "qta": "Quetta",
    "faisalabad": "Faisalabad", "lyp": "Faisalabad",
}

def _get_headers() -> dict:
    return {
        "X-RapidAPI-Key": settings.RAPIDAPI_KEY,
        "X-RapidAPI-Host": settings.RAPIDAPI_HOST,
    }


# ---------------------------------------------------------------------------
# Step 1: resolve city → TripAdvisor geoId
# ---------------------------------------------------------------------------

async def _get_geo_id(city: str) -> str | None:
    """Search TripAdvisor for a city and return its geoId."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{RAPIDAPI_BASE}/location/search",
                params={"searchQuery": city, "language": "en_US"},
                headers=_get_headers(),
            )
        if response.status_code != 200:
            logger.error("TripAdvisor location search failed: %s %s",
                         response.status_code, response.text[:200])
            return None

        data = response.json()
        results = data.get("data", [])
        for item in results:
            location_id = item.get("locationId") or item.get("location_id")
            if location_id:
                return str(location_id)
        return None
    except Exception as exc:
        logger.error("TripAdvisor location search error: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Step 2: search hotels by geoId
# ---------------------------------------------------------------------------

async def _search_hotels_tripadvisor(
    geo_id: str,
    check_in: date,
    check_out: date,
    guests: int,
    rooms: int,
) -> list[dict]:
    """Call TripAdvisor hotels/list endpoint."""
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                f"{RAPIDAPI_BASE}/hotels/list",
                params={
                    "geoId": geo_id,
                    "checkIn": check_in.strftime("%Y-%m-%d"),
                    "checkOut": check_out.strftime("%Y-%m-%d"),
                    "rooms": rooms,
                    "adults": guests,
                    "language": "en_US",
                    "currencyCode": "USD",
                },
                headers=_get_headers(),
            )
        if response.status_code != 200:
            logger.error("TripAdvisor hotel list failed: %s %s",
                         response.status_code, response.text[:200])
            return []

        data = response.json()
        # TripAdvisor API can return results in different structures
        hotels = (
            data.get("data", {}).get("data", []) or
            data.get("data", []) or
            []
        )
        return hotels if isinstance(hotels, list) else []
    except Exception as exc:
        logger.error("TripAdvisor hotel list error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Parse TripAdvisor property into HotelOffer
# ---------------------------------------------------------------------------

def _parse_hotel(prop: dict, check_in: date, check_out: date, city: str) -> HotelOffer:
    price_usd_per_night = 0.0
    try:
        # TripAdvisor price field paths vary — try multiple
        price_info = (
            prop.get("priceForDisplay") or
            prop.get("price") or
            prop.get("rawPrice") or
            {}
        )
        if isinstance(price_info, dict):
            raw = price_info.get("amount") or price_info.get("value") or 0
        elif isinstance(price_info, (int, float)):
            raw = price_info
        else:
            raw = 0
        price_usd_per_night = float(str(raw).replace("$", "").replace(",", "").strip() or 0)
    except (TypeError, ValueError):
        pass

    if price_usd_per_night <= 0:
        price_usd_per_night = random.uniform(40, 150)

    price_pkr_per_night = round(price_usd_per_night * settings.USD_TO_PKR_RATE, 2)

    # Images
    images: list[str] = []
    for img_field in ["photos", "images", "cardPhotos"]:
        raw_imgs = prop.get(img_field, [])
        if isinstance(raw_imgs, list):
            for img in raw_imgs[:4]:
                if isinstance(img, dict):
                    url = (
                        img.get("url") or
                        img.get("urlTemplate", "").replace("{width}", "800").replace("{height}", "600") or
                        img.get("src", "")
                    )
                    if url:
                        images.append(url)
            if images:
                break

    # Star rating
    star_rating = 3.0
    for sf in ["bubbleRating", "rating", "stars", "starRating", "categoryDescriptions"]:
        val = prop.get(sf)
        if isinstance(val, dict):
            val = val.get("ratingValue") or val.get("value") or val.get("overallRating")
        if val is not None:
            try:
                star_rating = min(5.0, float(val))
                break
            except (ValueError, TypeError):
                pass

    # Reviews
    review_score: float | None = None
    review_count: int | None = None
    for rf in ["bubbleRating", "reviews", "reviewSummary"]:
        rv = prop.get(rf)
        if isinstance(rv, dict):
            try:
                review_score = float(rv.get("ratingValue") or rv.get("rating") or rv.get("score") or 0) or None
                review_count = int(rv.get("count") or rv.get("total") or rv.get("reviewCount") or 0) or None
            except (ValueError, TypeError):
                pass
            if review_score:
                break

    hotel_id = str(prop.get("locationId") or prop.get("id") or random.randint(10000, 99999))
    name = prop.get("title") or prop.get("name") or "Hotel"

    rooms_list = [
        RoomOffer(
            room_id=f"{hotel_id}-STD",
            room_type="Standard Room",
            bed_type="King",
            price_per_night_pkr=price_pkr_per_night,
            max_guests=2,
            is_refundable=True,
            amenities=["WiFi", "AC", "TV", "Hot Water"],
        ),
        RoomOffer(
            room_id=f"{hotel_id}-DLX",
            room_type="Deluxe Room",
            bed_type="King",
            price_per_night_pkr=round(price_pkr_per_night * 1.35, 2),
            max_guests=2,
            is_refundable=True,
            amenities=["WiFi", "AC", "TV", "Mini Bar", "City View"],
        ),
    ]

    return HotelOffer(
        hotel_id=hotel_id,
        name=name,
        star_rating=star_rating,
        address=prop.get("secondaryInfo") or prop.get("address") or city,
        city=city,
        latitude=prop.get("latitude"),
        longitude=prop.get("longitude"),
        images=images,
        amenities=["WiFi", "Parking", "Restaurant", "24-Hour Reception"],
        rooms=rooms_list,
        review_score=review_score,
        review_count=review_count,
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def search_hotels(
    city: str,
    check_in: date,
    check_out: date,
    guests: int = 1,
    rooms: int = 1,
) -> HotelSearchResponse:
    """
    Search hotels for a given city and date range.

    Priority:
      1. Curated mock catalogue (instant, rich data — covers all major PK cities).
      2. OpenStreetMap Overpass API (free, real OSM data — supplements or replaces
         mock for cities not in the catalogue, including remote northern areas).
    """
    nights = max((check_out - check_in).days, 1)
    canonical = CITY_ALIASES.get(city.strip().lower(), city.strip())

    # Always start with curated mock data (fast, no quota)
    hotels = _mock_hotels(city, check_in, check_out, guests, rooms)

    # If mock has nothing, query Overpass for real OSM hotel data
    if not hotels:
        logger.info("No mock hotels for '%s' — querying Overpass OSM.", canonical)
        hotels = await _fetch_overpass_hotels(canonical)

    logger.info("Hotel search: %d hotels returned for %s", len(hotels), city)
    return HotelSearchResponse(
        city=city, check_in=check_in, check_out=check_out,
        nights=nights, count=len(hotels), hotels=hotels,
    )


async def get_hotel_detail(hotel_id: str, city: str = "") -> HotelOffer | None:
    """Return a single hotel by ID — pulled from mock catalogue for demo."""
    catalogue = _mock_hotel_catalogue(city or "Karachi")
    for h in catalogue:
        if h.hotel_id == hotel_id:
            return h
    return None


# ---------------------------------------------------------------------------
# Mock data — rich Pakistani hotel catalogue
# ---------------------------------------------------------------------------

_HOTEL_DATA: list[dict] = [
    # Karachi
    {"id": "KHI-001", "name": "Pearl Continental Karachi", "city": "Karachi",
     "stars": 5, "address": "Club Rd, Karachi", "price_usd": 120,
     "lat": 24.8607, "lon": 67.0011,
     "amenities": ["Pool", "Spa", "Gym", "Restaurant", "Business Center", "Valet Parking"],
     "images": ["https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"]},
    {"id": "KHI-002", "name": "Movenpick Hotel Karachi", "city": "Karachi",
     "stars": 5, "address": "Club Rd, Karachi", "price_usd": 110,
     "lat": 24.8550, "lon": 67.0052,
     "amenities": ["Pool", "Gym", "Restaurant", "Free WiFi", "Airport Shuttle"],
     "images": ["https://images.unsplash.com/photo-1455587734955-081b22074882?w=800"]},
    {"id": "KHI-003", "name": "Ramada by Wyndham Karachi", "city": "Karachi",
     "stars": 4, "address": "Shahrah-e-Faisal, Karachi", "price_usd": 65,
     "lat": 24.8900, "lon": 67.0601,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Room Service"],
     "images": ["https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800"]},
    {"id": "KHI-004", "name": "Avari Towers Karachi", "city": "Karachi",
     "stars": 5, "address": "Fatima Jinnah Rd, Karachi", "price_usd": 95,
     "lat": 24.8500, "lon": 67.0250,
     "amenities": ["Pool", "Spa", "Restaurant", "Bar", "Business Center"],
     "images": ["https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800"]},

    # Lahore
    {"id": "LHE-001", "name": "Pearl Continental Lahore", "city": "Lahore",
     "stars": 5, "address": "Shahrah-e-Quaid-e-Azam, Lahore", "price_usd": 100,
     "lat": 31.5204, "lon": 74.3587,
     "amenities": ["Pool", "Spa", "Gym", "Multiple Restaurants", "Business Center"],
     "images": ["https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800"]},
    {"id": "LHE-002", "name": "Avari Hotel Lahore", "city": "Lahore",
     "stars": 5, "address": "87 Shahrah-e-Quaid-e-Azam, Lahore", "price_usd": 85,
     "lat": 31.5497, "lon": 74.3436,
     "amenities": ["Pool", "Gym", "Restaurant", "Free WiFi", "Parking"],
     "images": ["https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800"]},
    {"id": "LHE-003", "name": "Nishat Hotel Lahore", "city": "Lahore",
     "stars": 5, "address": "Canal Bank Rd, Lahore", "price_usd": 90,
     "lat": 31.4687, "lon": 74.4020,
     "amenities": ["Pool", "Spa", "Multiple Restaurants", "Garden", "Business Center"],
     "images": ["https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800"]},
    {"id": "LHE-004", "name": "Faletti's Hotel Lahore", "city": "Lahore",
     "stars": 4, "address": "Egerton Rd, Lahore", "price_usd": 55,
     "lat": 31.5610, "lon": 74.3145,
     "amenities": ["Restaurant", "Garden", "Free WiFi", "Parking", "Laundry"],
     "images": ["https://images.unsplash.com/photo-1496417263034-38ec4f0b665a?w=800"]},

    # Islamabad
    {"id": "ISB-001", "name": "Serena Hotel Islamabad", "city": "Islamabad",
     "stars": 5, "address": "Khayaban-e-Suharwardy, Islamabad", "price_usd": 130,
     "lat": 33.7292, "lon": 73.0931,
     "amenities": ["Pool", "Spa", "Gym", "Multiple Restaurants", "Tennis Court"],
     "images": ["https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=800"]},
    {"id": "ISB-002", "name": "Marriott Hotel Islamabad", "city": "Islamabad",
     "stars": 5, "address": "Agha Khan Rd, Islamabad", "price_usd": 115,
     "lat": 33.7121, "lon": 73.0765,
     "amenities": ["Pool", "Spa", "Gym", "Restaurant", "Business Center", "Valet"],
     "images": ["https://images.unsplash.com/photo-1611892440504-42a792e24d32?w=800"]},
    {"id": "ISB-003", "name": "Best Western Plus Islamabad", "city": "Islamabad",
     "stars": 4, "address": "Blue Area, Islamabad", "price_usd": 60,
     "lat": 33.7244, "lon": 73.0931,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Room Service", "Gym"],
     "images": ["https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800"]},

    # Multan
    {"id": "MUL-001", "name": "Hotel One Multan", "city": "Multan",
     "stars": 4, "address": "Abdali Road, Multan", "price_usd": 45,
     "lat": 30.1575, "lon": 71.5249,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Room Service", "AC"],
     "images": ["https://images.unsplash.com/photo-1560347876-aeef00ee58a1?w=800"]},
    {"id": "MUL-002", "name": "Ramada Multan", "city": "Multan",
     "stars": 4, "address": "Nishtar Road, Multan", "price_usd": 50,
     "lat": 30.1852, "lon": 71.4813,
     "amenities": ["Pool", "Restaurant", "Free WiFi", "Parking", "Gym"],
     "images": ["https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=800"]},

    # Peshawar
    {"id": "PEW-001", "name": "Pearl Continental Peshawar", "city": "Peshawar",
     "stars": 5, "address": "Khyber Rd, Peshawar", "price_usd": 85,
     "lat": 34.0151, "lon": 71.5249,
     "amenities": ["Pool", "Restaurant", "Free WiFi", "Spa", "Business Center"],
     "images": ["https://images.unsplash.com/photo-1568084680786-a84f91d1153c?w=800"]},

    # Quetta
    {"id": "QTA-001", "name": "Serena Hotel Quetta", "city": "Quetta",
     "stars": 5, "address": "Shahrah-e-Zarghoon, Quetta", "price_usd": 75,
     "lat": 30.1798, "lon": 66.9750,
     "amenities": ["Restaurant", "Free WiFi", "Spa", "Garden", "Business Center"],
     "images": ["https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800"]},

    # Faisalabad
    {"id": "FSD-001", "name": "Hotel One Faisalabad", "city": "Faisalabad",
     "stars": 4, "address": "Susan Road, Faisalabad", "price_usd": 42,
     "lat": 31.4504, "lon": 73.1350,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Room Service"],
     "images": ["https://images.unsplash.com/photo-1587017539504-67cfbddac569?w=800"]},

    # Skardu (prices in PKR equivalent — USD 30-90/night)
    {"id": "SKD-001", "name": "Serena Hotel Skardu", "city": "Skardu",
     "stars": 5, "address": "Sadpara Road, Skardu", "price_usd": 85,
     "lat": 35.2971, "lon": 75.6338,
     "amenities": ["Mountain View", "Restaurant", "Jeep Rental", "Hiking Guide", "Free WiFi"],
     "images": ["https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"]},
    {"id": "SKD-002", "name": "Mashabrum Hotel Skardu", "city": "Skardu",
     "stars": 3, "address": "Airport Road, Skardu", "price_usd": 45,
     "lat": 35.2834, "lon": 75.6140,
     "amenities": ["Mountain View", "Restaurant", "Parking", "Free WiFi"],
     "images": ["https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800"]},
    {"id": "SKD-003", "name": "K2 Motel Skardu", "city": "Skardu",
     "stars": 2, "address": "Yadgar Chowk, Skardu", "price_usd": 30,
     "lat": 35.2942, "lon": 75.6257,
     "amenities": ["Restaurant", "Parking", "Free WiFi", "River View"],
     "images": ["https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800"]},

    # Gilgit
    {"id": "GIL-001", "name": "Serena Hotel Gilgit", "city": "Gilgit",
     "stars": 4, "address": "Jutial, Gilgit", "price_usd": 75,
     "lat": 35.9218, "lon": 74.3085,
     "amenities": ["Mountain View", "Restaurant", "Garden", "Free WiFi", "Jeep Rental"],
     "images": ["https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800"]},
    {"id": "GIL-002", "name": "PTDC Motel Gilgit", "city": "Gilgit",
     "stars": 3, "address": "KKH Road, Gilgit", "price_usd": 35,
     "lat": 35.9221, "lon": 74.3121,
     "amenities": ["Restaurant", "Parking", "Free WiFi", "Tourist Info"],
     "images": ["https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800"]},

    # Hunza
    {"id": "HNZ-001", "name": "Eagle's Nest Hotel Hunza", "city": "Hunza",
     "stars": 4, "address": "Duikar, Upper Hunza", "price_usd": 90,
     "lat": 36.3124, "lon": 74.6516,
     "amenities": ["Panoramic View", "Restaurant", "Terrace", "Free WiFi", "Nature Trails"],
     "images": ["https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"]},
    {"id": "HNZ-002", "name": "Serena Karimabad Hunza", "city": "Hunza",
     "stars": 4, "address": "Karimabad, Hunza", "price_usd": 80,
     "lat": 36.3162, "lon": 74.6484,
     "amenities": ["Mountain View", "Restaurant", "Spa", "Free WiFi", "Cultural Tours"],
     "images": ["https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800"]},

    # Swat
    {"id": "SWT-001", "name": "Serena Hotel Swat", "city": "Swat",
     "stars": 5, "address": "Saidu Sharif Road, Mingora", "price_usd": 70,
     "lat": 34.7748, "lon": 72.3601,
     "amenities": ["Pool", "Restaurant", "Spa", "Garden", "Free WiFi", "River View"],
     "images": ["https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?w=800"]},
    {"id": "SWT-002", "name": "PC Swat", "city": "Swat",
     "stars": 5, "address": "Malam Jabba, Swat", "price_usd": 65,
     "lat": 34.8104, "lon": 72.5608,
     "amenities": ["Ski Resort", "Restaurant", "Spa", "Free WiFi", "Snow Activities"],
     "images": ["https://images.unsplash.com/photo-1547981609-4b6bfe67ca0b?w=800"]},

    # Abbottabad
    {"id": "ABT-001", "name": "Pearl Continental Abbottabad", "city": "Abbottabad",
     "stars": 5, "address": "Shimla Hill, Abbottabad", "price_usd": 65,
     "lat": 34.1464, "lon": 73.2117,
     "amenities": ["Pool", "Restaurant", "Spa", "Gym", "Free WiFi", "Hill View"],
     "images": ["https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800"]},
    {"id": "ABT-002", "name": "Hotel One Abbottabad", "city": "Abbottabad",
     "stars": 3, "address": "Mansehra Road, Abbottabad", "price_usd": 38,
     "lat": 34.1558, "lon": 73.2194,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Room Service"],
     "images": ["https://images.unsplash.com/photo-1560347876-aeef00ee58a1?w=800"]},

    # Murree
    {"id": "MRE-001", "name": "PC Murree", "city": "Murree",
     "stars": 5, "address": "The Mall, Murree", "price_usd": 75,
     "lat": 33.9071, "lon": 73.3943,
     "amenities": ["Restaurant", "Spa", "Free WiFi", "Hill View", "Bonfire Area"],
     "images": ["https://images.unsplash.com/photo-1596436893853-b5b66de48c0b?w=800"]},
    {"id": "MRE-002", "name": "Hotel One Murree", "city": "Murree",
     "stars": 3, "address": "Kashmir Point Road, Murree", "price_usd": 40,
     "lat": 33.9054, "lon": 73.3937,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Valley View"],
     "images": ["https://images.unsplash.com/photo-1605346434674-a440ca4dc4c0?w=800"]},

    # Nathiagali
    {"id": "NTG-001", "name": "Greens Hotel Nathiagali", "city": "Nathiagali",
     "stars": 3, "address": "Main Road, Nathiagali", "price_usd": 35,
     "lat": 34.0687, "lon": 73.3719,
     "amenities": ["Restaurant", "Free WiFi", "Forest View", "Bonfire Area"],
     "images": ["https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800"]},
    {"id": "NTG-002", "name": "Pines Hotel Nathiagali", "city": "Nathiagali",
     "stars": 3, "address": "Governor's House Road, Nathiagali", "price_usd": 30,
     "lat": 34.0701, "lon": 73.3745,
     "amenities": ["Restaurant", "Garden", "Free WiFi", "Nature Walk"],
     "images": ["https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800"]},

    # Muzaffarabad
    {"id": "MZD-001", "name": "PC Muzaffarabad", "city": "Muzaffarabad",
     "stars": 5, "address": "AJK Road, Muzaffarabad", "price_usd": 60,
     "lat": 34.3596, "lon": 73.4714,
     "amenities": ["Pool", "Restaurant", "Spa", "Free WiFi", "River View"],
     "images": ["https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800"]},
    {"id": "MZD-002", "name": "Hilton Muzaffarabad", "city": "Muzaffarabad",
     "stars": 4, "address": "Neelum Road, Muzaffarabad", "price_usd": 50,
     "lat": 34.3648, "lon": 73.4776,
     "amenities": ["Restaurant", "Free WiFi", "Mountain View", "Conference Room"],
     "images": ["https://images.unsplash.com/photo-1611892440504-42a792e24d32?w=800"]},

    # Bahawalpur
    {"id": "BWP-001", "name": "Hotel One Bahawalpur", "city": "Bahawalpur",
     "stars": 3, "address": "Baghdad ul Jadeed, Bahawalpur", "price_usd": 35,
     "lat": 29.3956, "lon": 71.6836,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "Room Service"],
     "images": ["https://images.unsplash.com/photo-1568084680786-a84f91d1153c?w=800"]},
    {"id": "BWP-002", "name": "Cholistan Desert Resort", "city": "Bahawalpur",
     "stars": 3, "address": "Derawar Fort Road, Bahawalpur", "price_usd": 40,
     "lat": 29.1564, "lon": 71.3392,
     "amenities": ["Desert View", "Restaurant", "Camel Safari", "Free WiFi"],
     "images": ["https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=800"]},

    # Naran / Kaghan
    {"id": "NRN-001", "name": "PTDC Motel Naran", "city": "Naran",
     "stars": 3, "address": "Main Bazar, Naran", "price_usd": 40,
     "lat": 34.9022, "lon": 73.6528,
     "amenities": ["Restaurant", "Parking", "Free WiFi", "River View", "Hiking Info"],
     "images": ["https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800"]},
    {"id": "NRN-002", "name": "Al-Farooq Hotel Naran", "city": "Naran",
     "stars": 2, "address": "Lake Road, Naran", "price_usd": 25,
     "lat": 34.9034, "lon": 73.6540,
     "amenities": ["Restaurant", "Parking", "Mountain View"],
     "images": ["https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800"]},
    {"id": "NRN-003", "name": "Lalazar Hotel Naran", "city": "Naran",
     "stars": 3, "address": "Kaghan Road, Naran", "price_usd": 35,
     "lat": 34.9080, "lon": 73.6520,
     "amenities": ["Free WiFi", "Hot Water", "Restaurant", "Mountain View", "Bonfire Area"],
     "images": ["https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"]},

    # Hunza (expanded)
    {"id": "HNZ-003", "name": "Hunza Serena Inn", "city": "Hunza",
     "stars": 4, "address": "Aliabad, Hunza", "price_usd": 75,
     "lat": 36.3100, "lon": 74.6400,
     "amenities": ["Mountain View", "Free WiFi", "Restaurant", "Bonfire Area"],
     "images": ["https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800"]},
    {"id": "HNZ-004", "name": "Old Hunza Inn", "city": "Hunza",
     "stars": 3, "address": "Karimabad, Hunza", "price_usd": 35,
     "lat": 36.3150, "lon": 74.6550,
     "amenities": ["Free WiFi", "Hot Water", "Room Service", "Mountain View"],
     "images": ["https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800"]},
    {"id": "HNZ-005", "name": "Baltit Fort View Hotel", "city": "Hunza",
     "stars": 3, "address": "Near Baltit Fort, Karimabad", "price_usd": 40,
     "lat": 36.3220, "lon": 74.6620,
     "amenities": ["Fort View", "Free WiFi", "Hot Water", "Trekking Guide"],
     "images": ["https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"]},

    # Skardu (expanded)
    {"id": "SKD-004", "name": "Concordia Hotel Skardu", "city": "Skardu",
     "stars": 3, "address": "Skardu City", "price_usd": 35,
     "lat": 35.3080, "lon": 75.6280,
     "amenities": ["Free WiFi", "Hot Water", "Parking", "Mountain View"],
     "images": ["https://images.unsplash.com/photo-1496417263034-38ec4f0b665a?w=800"]},
    {"id": "SKD-005", "name": "PTDC Motel Skardu", "city": "Skardu",
     "stars": 2, "address": "PTDC Complex, Skardu", "price_usd": 25,
     "lat": 35.3050, "lon": 75.6400,
     "amenities": ["Hot Water", "Parking", "Basic Meals"],
     "images": ["https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800"]},

    # Gilgit (expanded)
    {"id": "GIL-003", "name": "Park Hotel Gilgit", "city": "Gilgit",
     "stars": 3, "address": "Bank Road, Gilgit", "price_usd": 30,
     "lat": 35.9200, "lon": 74.3050,
     "amenities": ["Free WiFi", "Hot Water", "Restaurant", "Parking"],
     "images": ["https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800"]},
    {"id": "GIL-004", "name": "Jasmine Guest House Gilgit", "city": "Gilgit",
     "stars": 3, "address": "Jutial, Gilgit", "price_usd": 28,
     "lat": 35.9250, "lon": 74.3120,
     "amenities": ["Free WiFi", "Hot Water", "Garden", "Mountain View"],
     "images": ["https://images.unsplash.com/photo-1496417263034-38ec4f0b665a?w=800"]},

    # Swat (expanded)
    {"id": "SWT-003", "name": "White Palace Hotel Swat", "city": "Swat",
     "stars": 4, "address": "Mingora, Swat", "price_usd": 60,
     "lat": 34.7700, "lon": 72.3580,
     "amenities": ["Restaurant", "Free WiFi", "Garden", "Mountain View"],
     "images": ["https://images.unsplash.com/photo-1455587734955-081b22074882?w=800"]},

    # Abbottabad (expanded)
    {"id": "ABT-003", "name": "Sarban Hotel Abbottabad", "city": "Abbottabad",
     "stars": 3, "address": "Mall Road, Abbottabad", "price_usd": 35,
     "lat": 34.1480, "lon": 73.2080,
     "amenities": ["Free WiFi", "Hot Water", "Restaurant", "Parking"],
     "images": ["https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800"]},

    # Murree (expanded — new IDs to avoid conflict with MRE-*)
    {"id": "MUR-003", "name": "Shangrila Resort Murree", "city": "Murree",
     "stars": 4, "address": "Bhurban Road, Murree", "price_usd": 60,
     "lat": 33.9100, "lon": 73.3960,
     "amenities": ["Pool", "Restaurant", "Free WiFi", "Valley View", "Bonfire Area"],
     "images": ["https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=800"]},
    {"id": "MUR-004", "name": "Cecil Hotel Murree", "city": "Murree",
     "stars": 3, "address": "The Mall, Murree", "price_usd": 40,
     "lat": 33.9055, "lon": 73.3920,
     "amenities": ["Free WiFi", "Hot Water", "Restaurant", "Valley View"],
     "images": ["https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800"]},

    # Nathiagali (expanded)
    {"id": "NTG-003", "name": "PTDC Motel Nathiagali", "city": "Nathiagali",
     "stars": 2, "address": "PTDC, Nathiagali", "price_usd": 20,
     "lat": 34.0680, "lon": 73.3730,
     "amenities": ["Hot Water", "Parking", "Basic Meals"],
     "images": ["https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800"]},

    # Muzaffarabad (expanded)
    {"id": "MZD-003", "name": "Neelum Valley Hotel", "city": "Muzaffarabad",
     "stars": 3, "address": "Neelum Chowk, Muzaffarabad", "price_usd": 35,
     "lat": 34.3680, "lon": 73.4700,
     "amenities": ["Free WiFi", "Hot Water", "Restaurant", "River View"],
     "images": ["https://images.unsplash.com/photo-1455587734955-081b22074882?w=800"]},

    # Larkana (new city)
    {"id": "LRK-001", "name": "Hotel Indus Larkana", "city": "Larkana",
     "stars": 3, "address": "Station Road, Larkana", "price_usd": 30,
     "lat": 27.5580, "lon": 68.2150,
     "amenities": ["Restaurant", "Free WiFi", "Parking", "AC"],
     "images": ["https://images.unsplash.com/photo-1496417263034-38ec4f0b665a?w=800"]},
    {"id": "LRK-002", "name": "Hotel Al-Meezan Larkana", "city": "Larkana",
     "stars": 2, "address": "Shaheed Chowk, Larkana", "price_usd": 20,
     "lat": 27.5560, "lon": 68.2130,
     "amenities": ["Hot Water", "Parking", "AC", "Room Service"],
     "images": ["https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800"]},

    # Sukkur (new city)
    {"id": "SUK-001", "name": "Hotel Mehran Sukkur", "city": "Sukkur",
     "stars": 3, "address": "Military Road, Sukkur", "price_usd": 28,
     "lat": 27.7052, "lon": 68.8574,
     "amenities": ["Restaurant", "Free WiFi", "AC", "Parking"],
     "images": ["https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800"]},
    {"id": "SUK-002", "name": "Hotel Al-Falah Sukkur", "city": "Sukkur",
     "stars": 2, "address": "Bunder Road, Sukkur", "price_usd": 18,
     "lat": 27.7040, "lon": 68.8560,
     "amenities": ["Hot Water", "AC", "Parking", "Room Service"],
     "images": ["https://images.unsplash.com/photo-1496417263034-38ec4f0b665a?w=800"]},

    # Hyderabad (new city)
    {"id": "HYD-001", "name": "Hotel Faran Hyderabad", "city": "Hyderabad",
     "stars": 3, "address": "Saddar, Hyderabad", "price_usd": 35,
     "lat": 25.3960, "lon": 68.3578,
     "amenities": ["Restaurant", "Free WiFi", "AC", "Parking"],
     "images": ["https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"]},
    {"id": "HYD-002", "name": "Hotel City Gate Hyderabad", "city": "Hyderabad",
     "stars": 3, "address": "Autobahn Road, Hyderabad", "price_usd": 30,
     "lat": 25.3940, "lon": 68.3560,
     "amenities": ["Restaurant", "Free WiFi", "AC", "Gym"],
     "images": ["https://images.unsplash.com/photo-1455587734955-081b22074882?w=800"]},

    # Sialkot (new city)
    {"id": "SKT-001", "name": "Hotel One Sialkot", "city": "Sialkot",
     "stars": 4, "address": "Cantt, Sialkot", "price_usd": 48,
     "lat": 32.4945, "lon": 74.5229,
     "amenities": ["Restaurant", "Free WiFi", "Pool", "Gym", "Parking"],
     "images": ["https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800"]},
    {"id": "SKT-002", "name": "Tariq Hotel Sialkot", "city": "Sialkot",
     "stars": 3, "address": "Shahabpura Road, Sialkot", "price_usd": 32,
     "lat": 32.4930, "lon": 74.5210,
     "amenities": ["Restaurant", "Free WiFi", "AC", "Parking"],
     "images": ["https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800"]},
]


def _mock_hotel_catalogue(city: str) -> list[HotelOffer]:
    """Build HotelOffer objects from static catalogue, filtered by city.
    Uses CITY_ALIASES to normalise aliases/typos → canonical city name.
    Returns [] for unknown cities (not a fallback dump of all hotels).
    """
    canonical = CITY_ALIASES.get(city.strip().lower(), city.strip())
    matches = [h for h in _HOTEL_DATA if h["city"] == canonical]
    if not matches:
        return []

    offers: list[HotelOffer] = []
    for h in matches:
        price_pkr = round(h["price_usd"] * settings.USD_TO_PKR_RATE, 2)
        rooms = [
            RoomOffer(
                room_id=f"{h['id']}-STD",
                room_type="Standard Room",
                bed_type="King",
                price_per_night_pkr=price_pkr,
                max_guests=2,
                is_refundable=True,
                amenities=["WiFi", "AC", "TV", "Hot Water"],
            ),
            RoomOffer(
                room_id=f"{h['id']}-DLX",
                room_type="Deluxe Room",
                bed_type="King",
                price_per_night_pkr=round(price_pkr * 1.4, 2),
                max_guests=3,
                is_refundable=True,
                amenities=["WiFi", "AC", "TV", "Mini Bar", "City View", "Bathtub"],
            ),
            RoomOffer(
                room_id=f"{h['id']}-SUT",
                room_type="Suite",
                bed_type="King",
                price_per_night_pkr=round(price_pkr * 2.2, 2),
                max_guests=4,
                is_refundable=False,
                amenities=["WiFi", "AC", "Smart TV", "Mini Bar", "Lounge", "Butler Service"],
            ),
        ]
        offers.append(
            HotelOffer(
                hotel_id=h["id"],
                name=h["name"],
                star_rating=float(h["stars"]),
                address=h["address"],
                city=h["city"],
                latitude=h.get("lat"),
                longitude=h.get("lon"),
                images=h.get("images", []),
                amenities=h.get("amenities", []),
                rooms=rooms,
                review_score=round(random.uniform(7.5, 9.5), 1),
                review_count=random.randint(120, 2500),
            )
        )
    return offers


def _mock_hotels(
    city: str,
    check_in: date,
    check_out: date,
    guests: int,
    rooms: int,
) -> list[HotelOffer]:
    return _mock_hotel_catalogue(city)


# ---------------------------------------------------------------------------
# OpenStreetMap / Overpass API — live hotel data for any Pakistan city
# ---------------------------------------------------------------------------

# City → (lat, lon) for Overpass radius queries
_OVERPASS_CITY_COORDS: dict[str, tuple[float, float]] = {
    "Karachi": (24.8607, 67.0011), "Lahore": (31.5204, 74.3587),
    "Islamabad": (33.7294, 73.0931), "Rawalpindi": (33.6007, 73.0679),
    "Faisalabad": (31.4504, 73.1350), "Multan": (30.1978, 71.4711),
    "Peshawar": (34.0151, 71.5249), "Quetta": (30.1798, 66.9750),
    "Sialkot": (32.4945, 74.5229), "Gujranwala": (32.1877, 74.1945),
    "Bahawalpur": (29.3956, 71.6836), "Hyderabad": (25.3960, 68.3578),
    "Sukkur": (27.7052, 68.8574), "Larkana": (27.5580, 68.2150),
    "Dera Ghazi Khan": (30.0571, 70.6350), "Gwadar": (25.1264, 62.3225),
    "Murree": (33.9072, 73.3943), "Nathiagali": (34.0741, 73.3778),
    "Abbottabad": (34.1463, 73.2117), "Mansehra": (34.3300, 73.2000),
    "Swat": (34.7462, 72.3578), "Chitral": (35.8518, 71.7864),
    "Gilgit": (35.9219, 74.3085), "Skardu": (35.2971, 75.6349),
    "Hunza": (36.3167, 74.6500), "Naran": (34.9030, 73.6540),
    "Muzaffarabad": (34.3700, 73.4711), "Rawalakot": (33.8575, 73.7614),
    "Ziarat": (30.3810, 67.7285), "Mirpur": (33.1475, 73.7511),
    "Fairy Meadows": (35.3753, 74.5958), "Kalash Valley": (35.7000, 71.6000),
}

_OVERPASS_URL = "https://overpass-api.de/api/interpreter"
_OVERPASS_RADIUS_M = 15_000   # 15 km radius around city centre


async def _fetch_overpass_hotels(canonical_city: str) -> list[HotelOffer]:
    """
    Query the Overpass API (free OSM data) for hotels/guest houses near a city.
    Returns an empty list on any error — caller falls back to mock data.
    """
    coords = _OVERPASS_CITY_COORDS.get(canonical_city)
    if coords is None:
        return []

    lat, lon = coords
    # Query nodes and ways tagged as hotel, hostel, or guest_house
    query = (
        f"[out:json][timeout:20];"
        f"("
        f'node["tourism"~"hotel|hostel|guest_house"](around:{_OVERPASS_RADIUS_M},{lat},{lon});'
        f'way["tourism"~"hotel|hostel|guest_house"](around:{_OVERPASS_RADIUS_M},{lat},{lon});'
        f");"
        f"out body;"
    )

    try:
        async with httpx.AsyncClient(timeout=22.0) as client:
            resp = await client.post(_OVERPASS_URL, data={"data": query})
        if resp.status_code != 200:
            logger.warning("Overpass API error %s for %s", resp.status_code, canonical_city)
            return []

        elements: list[dict] = resp.json().get("elements", [])
        offers: list[HotelOffer] = []

        for idx, el in enumerate(elements[:20]):   # cap at 20 OSM results
            tags: dict = el.get("tags", {})
            name = tags.get("name") or tags.get("name:en") or tags.get("brand")
            if not name:
                continue

            # Skip if no useful coordinates
            osm_lat = el.get("lat") or (el.get("center") or {}).get("lat")
            osm_lon = el.get("lon") or (el.get("center") or {}).get("lon")

            stars_raw = tags.get("stars") or tags.get("star_rating")
            try:
                stars = min(5.0, float(stars_raw or 3))
            except (ValueError, TypeError):
                stars = 3.0

            tourism_type = tags.get("tourism", "hotel")
            base_price_usd = {
                "hotel": random.uniform(35, 120),
                "hostel": random.uniform(8, 25),
                "guest_house": random.uniform(15, 45),
            }.get(tourism_type, 35.0)
            # Star-scale the price
            base_price_usd = round(base_price_usd * (0.6 + stars * 0.18), 2)
            price_pkr = round(base_price_usd * settings.USD_TO_PKR_RATE, 2)

            addr_parts = [
                tags.get("addr:housenumber", ""),
                tags.get("addr:street", ""),
                tags.get("addr:city", canonical_city),
            ]
            address = ", ".join(p for p in addr_parts if p) or canonical_city

            amenities: list[str] = []
            if tags.get("internet_access") in ("wlan", "wifi", "yes"):
                amenities.append("Free WiFi")
            if tags.get("parking") in ("yes", "private", "public"):
                amenities.append("Parking")
            if tags.get("restaurant") == "yes" or tags.get("amenity") == "restaurant":
                amenities.append("Restaurant")
            if tags.get("swimming_pool") == "yes":
                amenities.append("Pool")
            if not amenities:
                amenities = ["Hot Water", "Room Service"]

            hotel_id = f"OSM-{el['id']}"
            rooms_list = [
                RoomOffer(
                    room_id=f"{hotel_id}-STD",
                    room_type="Standard Room",
                    bed_type="Double",
                    price_per_night_pkr=price_pkr,
                    max_guests=2,
                    is_refundable=True,
                    amenities=amenities,
                ),
            ]

            offers.append(HotelOffer(
                hotel_id=hotel_id,
                name=name,
                star_rating=stars,
                address=address,
                city=canonical_city,
                latitude=osm_lat,
                longitude=osm_lon,
                images=[],
                amenities=amenities,
                rooms=rooms_list,
                review_score=round(random.uniform(6.5, 9.0), 1),
                review_count=random.randint(10, 400),
            ))

        logger.info("Overpass returned %d hotels for %s", len(offers), canonical_city)
        return offers

    except Exception as exc:
        logger.warning("Overpass fetch failed for %s: %s", canonical_city, exc)
        return []
