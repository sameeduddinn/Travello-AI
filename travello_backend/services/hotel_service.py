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
    Uses rich Pakistani hotel mock catalogue — TripAdvisor API has no Pakistan
    coverage so we serve curated mock data directly (faster, no API quota used).
    """
    nights = max((check_out - check_in).days, 1)
    hotels = _mock_hotels(city, check_in, check_out, guests, rooms)
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
]


def _mock_hotel_catalogue(city: str) -> list[HotelOffer]:
    """Build HotelOffer objects from static catalogue, filtered by city."""
    city_lower = city.lower()
    matches = [h for h in _HOTEL_DATA if h["city"].lower() == city_lower]
    if not matches:
        # Return all if city not found — demo-safe
        matches = _HOTEL_DATA[:6]

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
