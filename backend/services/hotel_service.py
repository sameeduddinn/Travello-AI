# =============================================================================
# PURPOSE: Hotel search via RapidAPI Hotels4 endpoint.
#          Falls back to rich mock data when RAPIDAPI_KEY is not set.
#          All prices are in PKR.

# RapidAPI Hotels4 free tier: https://rapidapi.com/apidojo/api/hotels4
#   - 500 requests/month free
#   - No credit card required for free tier
# =============================================================================

from __future__ import annotations

import logging
import random
import urllib.parse
from datetime import date
from typing import Any

import httpx

from core.config import settings
from models.hotel import HotelOffer, HotelSearchResponse, RoomOffer

logger = logging.getLogger(__name__)

RAPIDAPI_BASE = (
    settings.RAPIDAPI_HOST.strip().rstrip("/")
    if settings.RAPIDAPI_HOST.startswith("http")
    else f"https://{settings.RAPIDAPI_HOST.strip()}"
)
NOMINATIM_BASE = "https://nominatim.openstreetmap.org"
_MIN_FALLBACK_COUNT = 5  # only call next source if current total is below this

# City name normalisation - handles typos, aliases, IATA codes

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


def _rapidapi_is_configured() -> bool:
    """Return True when RapidAPI credentials look usable (not placeholders)."""
    key = (settings.RAPIDAPI_KEY or "").strip()
    if not key:
        return False
    lowered = key.lower()
    return "your-rapidapi-key" not in lowered and not key.startswith("REPLACE_WITH")


def _normalise_hotel_text(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def _hotel_merge_key(hotel: HotelOffer) -> tuple[str, str, float | None, float | None]:
    name_key = _normalise_hotel_text(hotel.name)
    city_key = _normalise_hotel_text(hotel.city)
    lat = round(float(hotel.latitude), 3) if hotel.latitude is not None else None
    lon = round(float(hotel.longitude), 3) if hotel.longitude is not None else None
    return (name_key, city_key, lat, lon)


def _enrich_hotel(primary: HotelOffer, fallback: HotelOffer) -> None:
    """Fill missing fields in primary from fallback without replacing core identity."""
    if not primary.address and fallback.address:
        primary.address = fallback.address
    if primary.latitude is None and fallback.latitude is not None:
        primary.latitude = fallback.latitude
    if primary.longitude is None and fallback.longitude is not None:
        primary.longitude = fallback.longitude
    if not primary.images and fallback.images:
        primary.images = fallback.images
    if (not primary.amenities) and fallback.amenities:
        primary.amenities = fallback.amenities
    if (not primary.review_score) and fallback.review_score:
        primary.review_score = fallback.review_score
    if (not primary.review_count) and fallback.review_count:
        primary.review_count = fallback.review_count


def _merge_hotel_lists(
    base: list[HotelOffer],
    incoming: list[HotelOffer],
    *,
    limit: int | None = None,
) -> list[HotelOffer]:
    """Merge hotels by source priority order with de-duplication and enrichment.
    If limit is None, all incoming hotels are merged without a cap.
    """
    merged = list(base)
    key_to_index: dict[tuple[str, str, float | None, float | None], int] = {
        _hotel_merge_key(h): idx for idx, h in enumerate(merged)
    }

    for hotel in incoming:
        key = _hotel_merge_key(hotel)
        existing_idx = key_to_index.get(key)
        if existing_idx is not None:
            _enrich_hotel(merged[existing_idx], hotel)
            continue

        merged.append(hotel)
        key_to_index[key] = len(merged) - 1
        if limit is not None and len(merged) >= limit:
            break

    return merged


async def _rapidapi_get_json(
    endpoint_candidates: list[str],
    params: dict[str, Any],
    *,
    timeout: float,
) -> dict[str, Any] | None:
    """Try multiple endpoint paths and return the first successful JSON payload."""
    async with httpx.AsyncClient(timeout=timeout) as client:
        for endpoint in endpoint_candidates:
            url = f"{RAPIDAPI_BASE}{endpoint}"
            try:
                response = await client.get(url, params=params, headers=_get_headers())
                if response.status_code == 200:
                    return response.json()
                logger.warning(
                    "RapidAPI request failed for %s: %s %s",
                    endpoint,
                    response.status_code,
                    response.text[:140],
                )
            except Exception as exc:
                logger.warning("RapidAPI request error for %s: %s", endpoint, exc)

    return None


# Step 1: resolve city - TripAdvisor geoId

async def _get_geo_id(city: str) -> str | None:
    """Search TripAdvisor for a city and return its geoId."""
    try:
        data = await _rapidapi_get_json(
            ["/api/v1/hotels/searchLocation"],
            {"query": city},
            timeout=15.0,
        )
        if not data:
            return None

        results = data.get("data", [])
        if not isinstance(results, list):
            results = []

        for item in results:
            location_id = item.get("geoId") or item.get("locationId") or item.get("location_id")
            if location_id:
                return str(location_id)
        return None
    except Exception as exc:
        logger.error("TripAdvisor location search error: %s", exc)
        return None


# Step 2: search hotels by geoId

async def _search_hotels_tripadvisor(
    geo_id: str,
    check_in: date,
    check_out: date,
    guests: int,
    rooms: int,
) -> list[dict]:
    """Call TripAdvisor hotels/list endpoint."""
    try:
        data = await _rapidapi_get_json(
            ["/api/v1/hotels/searchHotels"],
            {
                "geoId": geo_id,
                "checkIn": check_in.strftime("%Y-%m-%d"),
                "checkOut": check_out.strftime("%Y-%m-%d"),
                "rooms": rooms,
                "adults": guests,
                "currencyCode": "USD",
            },
            timeout=20.0,
        )
        if not data:
            return []

        # TripAdvisor API can return results in different structures
        hotels = (
            data.get("data", {}).get("data", []) or
            data.get("data", []) or
            data.get("results", []) or
            []
        )
        return hotels if isinstance(hotels, list) else []
    except Exception as exc:
        logger.error("TripAdvisor hotel list error: %s", exc)
        return []


async def _fetch_nominatim_hotels(canonical_city: str, *, limit: int = 20) -> list[HotelOffer]:
    """Search hotels/guest houses via Nominatim as a secondary live data source."""
    queries = [
        f"hotel in {canonical_city}, Pakistan",
        f"guest house in {canonical_city}, Pakistan",
    ]

    headers = {
        "User-Agent": "travello-ai-backend/1.0 (hotel-search)",
        "Accept-Language": "en",
    }

    raw_items: list[dict[str, Any]] = []
    try:
        async with httpx.AsyncClient(timeout=20.0, headers=headers) as client:
            for query in queries:
                response = await client.get(
                    f"{NOMINATIM_BASE}/search",
                    params={
                        "q": query,
                        "format": "jsonv2",
                        "addressdetails": 1,
                        "countrycodes": "pk",
                        "dedupe": 1,
                        "limit": limit,
                    },
                )
                if response.status_code != 200:
                    logger.warning(
                        "Nominatim query failed for '%s': %s %s",
                        query,
                        response.status_code,
                        response.text[:140],
                    )
                    continue

                data = response.json()
                if isinstance(data, list):
                    raw_items.extend(data)
    except Exception as exc:
        logger.warning("Nominatim fetch failed for %s: %s", canonical_city, exc)
        return []

    allowed_types = {
        "hotel", "guest_house", "hostel", "motel", "resort", "apartment", "chalet",
    }
    hotel_keywords = (
        "hotel", "guest house", "guesthouse", "hostel", "motel", "resort", "inn", "lodge",
    )

    seen: set[tuple[str, float | None, float | None]] = set()
    seen_ids: set[str] = set()
    offers: list[HotelOffer] = []

    for item in raw_items:
        osm_id = str(item.get("osm_id") or item.get("place_id") or "").strip()
        if not osm_id or osm_id in seen_ids:
            continue

        type_value = _normalise_hotel_text(str(item.get("type") or "")).replace(" ", "_")
        class_value = _normalise_hotel_text(str(item.get("class") or ""))
        searchable_text = _normalise_hotel_text(
            f"{item.get('name', '')} {item.get('display_name', '')}"
        )
        has_hotel_keyword = any(keyword in searchable_text for keyword in hotel_keywords)

        if type_value not in allowed_types and not has_hotel_keyword:
            continue
        if class_value not in {"tourism", "amenity", "building", "place", ""}:
            continue

        raw_name = (item.get("name") or "").strip()
        display_title = (item.get("display_name") or "").split(",")[0].strip()

        # If OSM has no explicit name, only accept display titles that clearly
        # look like accommodations (prevents paths/roads from slipping in).
        if not raw_name:
            normalised_title = _normalise_hotel_text(display_title)
            if not any(keyword in normalised_title for keyword in hotel_keywords):
                continue

        name = raw_name or display_title or None
        if not name:
            continue

        lat_raw = item.get("lat")
        lon_raw = item.get("lon")
        try:
            lat = float(lat_raw) if lat_raw is not None else None
            lon = float(lon_raw) if lon_raw is not None else None
        except (TypeError, ValueError):
            lat, lon = None, None

        dedupe_key = (
            _normalise_hotel_text(name),
            round(lat, 3) if lat is not None else None,
            round(lon, 3) if lon is not None else None,
        )
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        seen_ids.add(osm_id)

        star_rating = random.choice([2.0, 2.5, 3.0, 3.5, 4.0])
        base_price_usd = random.uniform(18, 90)
        price_pkr = round(base_price_usd * settings.USD_TO_PKR_RATE, 2)

        address = item.get("display_name") or canonical_city
        amenities = ["WiFi", "Hot Water", "Room Service"]
        rooms_list = [
            RoomOffer(
                room_id=f"NOM-{osm_id}-STD",
                room_type="Standard Room",
                bed_type="Double",
                price_per_night_pkr=price_pkr,
                max_guests=2,
                is_refundable=True,
                amenities=amenities,
            )
        ]

        # Generic hotel images so these results survive the image filter
        _HOTEL_PLACEHOLDER_IMAGES = [
            "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80",
            "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&q=80",
            "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80",
            "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800&q=80",
            "https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800&q=80",
        ]
        placeholder_image = _HOTEL_PLACEHOLDER_IMAGES[len(offers) % len(_HOTEL_PLACEHOLDER_IMAGES)]

        offers.append(
            HotelOffer(
                hotel_id=f"NOM-{osm_id}",
                name=name,
                star_rating=star_rating,
                address=address,
                city=canonical_city,
                latitude=lat,
                longitude=lon,
                images=[placeholder_image],
                amenities=amenities,
                rooms=rooms_list,
                review_score=round(random.uniform(6.0, 8.8), 1),
                review_count=random.randint(5, 200),
            )
        )

        if len(offers) >= limit:
            break

    logger.info("Nominatim returned %d hotels for %s", len(offers), canonical_city)
    return offers


# Google Places API - hotel search

_GOOGLE_PLACES_NEARBY_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
_GOOGLE_PLACES_PHOTO_URL  = "https://maps.googleapis.com/maps/api/place/photo"

_GOOGLE_PRICE_LEVEL_TO_USD: dict[int, tuple[float, float]] = {
    0: (15.0,  30.0),   # free / budget
    1: (20.0,  50.0),   # inexpensive
    2: (50.0,  100.0),  # moderate
    3: (100.0, 200.0),  # expensive
    4: (200.0, 400.0),  # very expensive
}


def _google_places_is_configured() -> bool:
    key = (settings.GOOGLE_PLACES_API_KEY or "").strip()
    return bool(key) and "your-google" not in key.lower() and not key.startswith("REPLACE")


def _google_photo_url(photo_reference: str) -> str:
    return (
        f"{_GOOGLE_PLACES_PHOTO_URL}"
        f"?maxwidth=800&photo_reference={photo_reference}"
        f"&key={settings.GOOGLE_PLACES_API_KEY}"
    )


async def _fetch_google_places_hotels(canonical_city: str, *, limit: int = 20) -> list[HotelOffer]:
    """
    Query Google Places Nearby Search for lodging near a city centre.
    Returns an empty list on any error — caller falls back to next source.
    """
    coords = _OVERPASS_CITY_COORDS.get(canonical_city)
    if coords is None:
        return []

    lat, lon = coords
    params = {
        "location": f"{lat},{lon}",
        "radius": 15000,          # 15 km radius
        "type": "lodging",
        "key": settings.GOOGLE_PLACES_API_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.get(_GOOGLE_PLACES_NEARBY_URL, params=params)

        if resp.status_code != 200:
            logger.warning(
                "Google Places error %s for %s: %s",
                resp.status_code, canonical_city, resp.text[:200],
            )
            return []

        data = resp.json()
        status = data.get("status", "")
        if status not in ("OK", "ZERO_RESULTS"):
            logger.warning("Google Places status '%s' for %s", status, canonical_city)
            return []

        results: list[dict] = data.get("results", [])
        offers: list[HotelOffer] = []

        for place in results[:limit]:
            name = (place.get("name") or "").strip()
            if not name:
                continue

            place_id  = place.get("place_id", f"GP-{random.randint(10000,99999)}")
            vicinity  = place.get("vicinity") or canonical_city
            geometry  = place.get("geometry", {}).get("location", {})
            g_lat     = geometry.get("lat")
            g_lon     = geometry.get("lng")

            # Rating: Google uses 1.0–5.0 → treat as star rating directly
            g_rating      = place.get("rating")
            review_count  = place.get("user_ratings_total")
            try:
                star_rating  = float(g_rating) if g_rating is not None else 3.0
                review_score = float(g_rating) if g_rating is not None else None
            except (TypeError, ValueError):
                star_rating, review_score = 3.0, None

            # Price level → PKR estimate
            price_level = place.get("price_level")
            lo, hi = _GOOGLE_PRICE_LEVEL_TO_USD.get(price_level or 2, (40.0, 100.0))
            price_usd = random.uniform(lo, hi)
            price_pkr = round(price_usd * settings.USD_TO_PKR_RATE, 2)

            # Photos — build signed URL for first photo
            photos_raw = place.get("photos") or []
            images: list[str] = []
            for ph in photos_raw[:3]:
                ref = ph.get("photo_reference")
                if ref:
                    images.append(_google_photo_url(ref))

            amenities = ["Free WiFi", "AC", "Room Service"]
            if star_rating >= 4.0:
                amenities += ["Pool", "Gym", "Restaurant"]

            rooms_list = [
                RoomOffer(
                    room_id=f"GP-{place_id}-STD",
                    room_type="Standard Room",
                    bed_type="Double",
                    price_per_night_pkr=price_pkr,
                    max_guests=2,
                    is_refundable=True,
                    amenities=amenities,
                ),
                RoomOffer(
                    room_id=f"GP-{place_id}-DLX",
                    room_type="Deluxe Room",
                    bed_type="King",
                    price_per_night_pkr=round(price_pkr * 1.35, 2),
                    max_guests=3,
                    is_refundable=True,
                    amenities=amenities + ["City View"],
                ),
            ]

            offers.append(HotelOffer(
                hotel_id=f"GP-{place_id}",
                name=name,
                star_rating=min(star_rating, 5.0),
                address=vicinity,
                city=canonical_city,
                latitude=g_lat,
                longitude=g_lon,
                images=images,
                amenities=amenities,
                rooms=rooms_list,
                review_score=review_score,
                review_count=review_count,
            ))

        logger.info("Google Places returned %d hotels for %s", len(offers), canonical_city)
        return offers

    except Exception as exc:
        logger.warning("Google Places fetch failed for %s: %s", canonical_city, exc)
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
        elif isinstance(price_info, str):
            raw = price_info  # e.g. "$35" — stripped below
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
                    # tripadvisor16: nested under img.sizes.urlTemplate
                    sizes = img.get("sizes") or {}
                    nested_template = sizes.get("urlTemplate", "") if isinstance(sizes, dict) else ""
                    url = (
                        img.get("url") or
                        img.get("urlTemplate", "").replace("{width}", "800").replace("{height}", "600") or
                        nested_template.replace("{width}", "800").replace("{height}", "600") or
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
            val = (val.get("rating") or val.get("ratingValue") or
                   val.get("value") or val.get("overallRating"))
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
                review_score = float(rv.get("rating") or rv.get("ratingValue") or rv.get("score") or 0) or None
                # count may come as "(45)" string — strip parens before int()
                raw_count = rv.get("count") or rv.get("total") or rv.get("reviewCount") or 0
                clean_count = str(raw_count).replace("(", "").replace(")", "").strip()
                review_count = int(clean_count) if clean_count.isdigit() else None
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
# Hotels.com Provider (RapidAPI) — hotel search + room availability
# ---------------------------------------------------------------------------

def _hotels_com_headers() -> dict:
    return {
        "X-RapidAPI-Key": settings.RAPIDAPI_KEY,
        "X-RapidAPI-Host": settings.HOTELS_COM_HOST,
    }


def _hotels_com_is_configured() -> bool:
    key = (settings.RAPIDAPI_KEY or "").strip()
    host = (settings.HOTELS_COM_HOST or "").strip()
    if not key or not host:
        return False
    return "your-rapidapi-key" not in key.lower() and not key.startswith("REPLACE_WITH")


async def _hotels_com_get_json(endpoint: str, params: dict) -> dict | None:
    """GET request against Hotels.com Provider host."""
    url = f"https://{settings.HOTELS_COM_HOST.strip()}{endpoint}"
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.get(url, params=params, headers=_hotels_com_headers())
        if resp.status_code == 200:
            return resp.json()
        logger.warning("Hotels.com %s %s: %s", resp.status_code, endpoint, resp.text[:200])
        return None
    except Exception as exc:
        logger.warning("Hotels.com request error %s: %s", endpoint, exc)
        return None


async def _hotels_com_get_region_id(city: str) -> str | None:
    """Resolve a city name to a Hotels.com gaiaId (region ID)."""
    data = await _hotels_com_get_json(
        "/v2/regions",
        {"query": city, "locale": "en_US", "domain": "US"},
    )
    if not data:
        logger.warning("Hotels.com: no response from /v2/regions for '%s'", city)
        return None
    results = data.get("data", [])
    if not isinstance(results, list) or not results:
        logger.warning("Hotels.com: empty region results for '%s'. Response keys: %s", city, list(data.keys()))
        return None
    logger.info("Hotels.com: found %d region results for '%s'", len(results), city)
    for item in results:
        gaia_id = item.get("gaiaId") or item.get("id")
        region_type = (item.get("type") or "").upper()
        country = (item.get("hierarchyInfo") or {}).get("country", {}).get("isoCode2", "")
        logger.debug("Hotels.com region candidate: gaiaId=%s type=%s country=%s", gaia_id, region_type, country)
        # Prefer Pakistan results (isoCode2 = PK)
        if gaia_id and country == "PK":
            logger.info("Hotels.com: selected region %s (%s) for '%s'", gaia_id, region_type, city)
            return str(gaia_id)
    # Fallback: first CITY result regardless of country
    for item in results:
        gaia_id = item.get("gaiaId") or item.get("id")
        region_type = (item.get("type") or "").upper()
        if gaia_id and region_type == "CITY":
            logger.info("Hotels.com: fallback region %s (CITY) for '%s'", gaia_id, city)
            return str(gaia_id)
    # Last resort: first result
    gaia_id = results[0].get("gaiaId") or results[0].get("id")
    if gaia_id:
        logger.info("Hotels.com: last-resort region %s for '%s'", gaia_id, city)
        return str(gaia_id)
    logger.warning("Hotels.com: could not extract gaiaId for '%s'", city)
    return None


async def fetch_hotels_com_hotels(
    city: str,
    check_in: date,
    check_out: date,
    guests: int,
    rooms: int,
) -> list[HotelOffer]:
    """Search Hotels.com for hotels in a city — returns parsed HotelOffer list."""
    if not _hotels_com_is_configured():
        return []

    region_id = await _hotels_com_get_region_id(city)
    if not region_id:
        logger.info("Hotels.com: no region ID found for %s", city)
        return []

    data = await _hotels_com_get_json(
        "/v2/hotels/search",
        {
            "region_id": region_id,
            "checkin_date": check_in.strftime("%Y-%m-%d"),
            "checkout_date": check_out.strftime("%Y-%m-%d"),
            "adults_number": guests,
            "rooms_number": rooms,
            "locale": "en_US",
            "domain": "US",
            "sort_order": "RECOMMENDED",
            "currency": "USD",
        },
    )
    if not data:
        logger.warning("Hotels.com: no response from /v2/hotels/search for region %s", region_id)
        return []

    # propertySearchListings has full hotel objects; 'properties' only has skeleton placeholders
    raw_results = (
        data.get("propertySearchListings") or
        (data.get("data") or {}).get("propertySearchListings") or
        []
    )
    if not isinstance(raw_results, list) or not raw_results:
        logger.warning("Hotels.com: could not find results in response. Keys: %s", list(data.keys()))
        return []

    logger.info("Hotels.com: found %d raw results for %s (all skeleton — API broken)", len(raw_results), city)
    return []


def _parse_hotels_com_hotel(prop: dict, city: str) -> HotelOffer | None:
    """Parse a single Hotels.com search result into a HotelOffer."""
    hotel_id = prop.get("id") or prop.get("hotelId")
    if not hotel_id:
        logger.debug("Hotels.com: skipping prop with no id, keys=%s", list(prop.keys()))
        return None
    hotel_id = f"HC-{hotel_id}"

    # Name — nested under 'name' or 'headingSection'
    name = (
        prop.get("name") or
        (prop.get("headingSection") or {}).get("title") or
        (prop.get("heading") or {}).get("text") or
        "Hotel"
    )

    # Star rating — nested under 'star', 'starRating', or 'star-rating'
    star_raw = (
        (prop.get("star") or {}).get("value") or
        (prop.get("star-rating") or {}).get("ratingValue") or
        prop.get("starRating") or
        prop.get("stars") or
        3
    )
    try:
        star_rating = min(5.0, float(star_raw))
    except (ValueError, TypeError):
        star_rating = 3.0

    # Price — 'price.lead.amount' or 'price.options[0].pricePerNightIncludingTaxesAndFees'
    price_usd = 0.0
    try:
        price_block = prop.get("price") or {}
        lead = price_block.get("lead") or {}
        options = price_block.get("options") or []
        price_usd = float(
            lead.get("amount") or
            lead.get("formatted", "0").replace("$", "").replace(",", "").strip() or
            (options[0].get("pricePerNightIncludingTaxesAndFees", {}).get("amount") if options else 0) or
            price_block.get("value") or
            0
        )
    except (ValueError, TypeError):
        price_usd = 0.0
    if price_usd <= 0:
        price_usd = random.uniform(40, 150)
    price_pkr = round(price_usd * settings.USD_TO_PKR_RATE, 2)

    # Location
    coord = prop.get("mapMarker") or prop.get("coordinate") or prop.get("location") or {}
    lat = coord.get("latLong", {}).get("latitude") or coord.get("lat") or coord.get("latitude")
    lon = coord.get("latLong", {}).get("longitude") or coord.get("lon") or coord.get("longitude")
    address = (
        (prop.get("address") or {}).get("addressLine") or
        (prop.get("address") or {}).get("streetAddress") or
        (prop.get("address") or {}).get("cityName") or
        city
    )

    # Images — nested under 'propertyImage', 'images', or 'image'
    images: list[str] = []
    prop_img = prop.get("propertyImage") or {}
    if prop_img:
        img_url = (prop_img.get("image") or {}).get("url") or prop_img.get("url") or ""
        if img_url:
            images.append(img_url if img_url.startswith("http") else f"https:{img_url}")
    if not images:
        for img_field in ["images", "thumbnailImageUrl", "image"]:
            raw_imgs = prop.get(img_field)
            if isinstance(raw_imgs, list):
                for img in raw_imgs[:4]:
                    url = (img.get("url") or img.get("baseUri") or img.get("src") or "") if isinstance(img, dict) else str(img)
                    if url:
                        images.append(url if url.startswith("http") else f"https:{url}")
            elif isinstance(raw_imgs, str) and raw_imgs.startswith("http"):
                images.append(raw_imgs)
            if images:
                break

    # Review — 'reviews.score' and 'reviews.total'
    review_raw = prop.get("reviews") or prop.get("guestReviews") or {}
    try:
        review_score = float(review_raw.get("score") or review_raw.get("rating") or (review_raw.get("brands") or {}).get("rating") or 0) or None
        review_count = int(str(review_raw.get("total") or review_raw.get("count") or 0).replace(",", "").replace("+", "") or 0) or None
    except (ValueError, TypeError):
        review_score, review_count = None, None

    amenities = ["Free WiFi", "AC", "Room Service"]
    if star_rating >= 4:
        amenities += ["Pool", "Gym", "Restaurant"]

    rooms_list = [
        RoomOffer(
            room_id=f"{hotel_id}-STD",
            room_type="Standard Room",
            bed_type="Double",
            price_per_night_pkr=price_pkr,
            max_guests=2,
            is_refundable=True,
            amenities=amenities,
            rooms_available=10,
            cancellation_policy="Free cancellation up to 24 hours before check-in",
        ),
        RoomOffer(
            room_id=f"{hotel_id}-DLX",
            room_type="Deluxe Room",
            bed_type="King",
            price_per_night_pkr=round(price_pkr * 1.35, 2),
            max_guests=3,
            is_refundable=True,
            amenities=amenities + ["City View"],
            rooms_available=6,
            has_city_view=True,
            cancellation_policy="Free cancellation up to 24 hours before check-in",
        ),
    ]

    return HotelOffer(
        hotel_id=hotel_id,
        name=name,
        star_rating=star_rating,
        address=address,
        city=city,
        latitude=lat,
        longitude=lon,
        images=images,
        amenities=amenities,
        rooms=rooms_list,
        review_score=review_score,
        review_count=review_count,
    )


async def _fetch_hotels_com_rooms(
    hotel_id: str,
    check_in: date,
    check_out: date,
    guests: int,
) -> list[RoomOffer]:
    """
    Call Hotels.com detail endpoint to get live room availability for specific dates.
    hotel_id should be the raw Hotels.com ID (without 'HC-' prefix).
    """
    data = await _hotels_com_get_json(
        "/v2/hotels/detail",
        {
            "hotel_id": hotel_id,
            "checkin_date": check_in.strftime("%Y-%m-%d"),
            "checkout_date": check_out.strftime("%Y-%m-%d"),
            "adults_number": guests,
            "locale": "en_US",
            "domain": "US",
            "currency": "USD",
        },
    )
    if not data:
        return []

    # Rooms nested under multiple possible paths
    body = (data.get("data") or {}).get("body") or data.get("data") or data
    rooms_raw = (
        body.get("roomsAndRates", {}).get("rooms") or
        body.get("rooms") or
        body.get("roomTypes") or
        []
    )
    if not isinstance(rooms_raw, list) or not rooms_raw:
        logger.info("Hotels.com detail: no rooms in response for %s", hotel_id)
        return []

    offers: list[RoomOffer] = []
    for room in rooms_raw[:8]:
        # Name
        name = room.get("name") or room.get("roomName") or room.get("header", {}).get("text") or "Standard Room"

        # Bed type
        beds = room.get("beds") or room.get("bedTypes") or []
        if isinstance(beds, list) and beds:
            first_bed = beds[0]
            bed = first_bed.get("description") or first_bed.get("type") or "Double" if isinstance(first_bed, dict) else str(first_bed)
        else:
            bed = "Double"

        # Price from first rate plan
        rate_plans = room.get("ratePlans") or room.get("rates") or [{}]
        first_rate = rate_plans[0] if rate_plans else {}
        price_info = (
            (first_rate.get("price") or {}).get("lead") or
            (first_rate.get("price") or {}).get("current") or
            first_rate.get("price") or
            {}
        )
        try:
            price_usd = float(
                price_info.get("amount") or price_info.get("value") or 0
            )
        except (ValueError, TypeError):
            price_usd = 0.0
        if price_usd <= 0:
            price_usd = random.uniform(40, 150)
        price_pkr = round(price_usd * settings.USD_TO_PKR_RATE, 2)

        # Availability
        avail_raw = room.get("availableRoomsCount") or room.get("availability") or room.get("remainingCount")
        try:
            avail = int(avail_raw) if avail_raw is not None else None
        except (ValueError, TypeError):
            avail = None
        if avail is None:
            seed = hash(f"HC-{hotel_id}-{name}-{check_in}") % (2 ** 31)
            avail = random.Random(seed).randint(2, 12)

        # Cancellation
        cancel_info = first_rate.get("cancellationPolicy") or {}
        is_refundable = cancel_info.get("type") != "NON_REFUNDABLE" if cancel_info else True
        cancel_policy = (
            "Free cancellation up to 24 hours before check-in"
            if is_refundable else "Non-refundable"
        )

        # Max occupancy
        try:
            max_guests = int(
                (room.get("maxOccupancy") or {}).get("total") or
                room.get("maxOccupancy") or 2
            )
        except (ValueError, TypeError):
            max_guests = 2

        # Amenities
        raw_amenities = room.get("amenities") or []
        if isinstance(raw_amenities, list):
            amenities = [a.get("description", a) if isinstance(a, dict) else str(a) for a in raw_amenities[:8]]
        else:
            amenities = []
        if not amenities:
            amenities = ["WiFi", "AC", "TV"]

        room_id = f"HC-{hotel_id}-{room.get('roomTypeId', room.get('id', len(offers)))}"
        offers.append(RoomOffer(
            room_id=room_id,
            room_type=name,
            bed_type=bed,
            price_per_night_pkr=price_pkr,
            max_guests=max_guests,
            is_refundable=is_refundable,
            amenities=amenities,
            rooms_available=avail,
            cancellation_policy=cancel_policy,
            has_city_view="city view" in name.lower(),
            has_balcony="balcony" in name.lower(),
            breakfast_included="breakfast" in name.lower(),
        ))

    logger.info("Hotels.com rooms for hotel %s: %d rooms", hotel_id, len(offers))
    return offers


# Real-time room availability

async def _fetch_tripadvisor_rooms(
    hotel_id: str,
    check_in: date,
    check_out: date,
    guests: int,
) -> list[RoomOffer]:
    """
    Call TripAdvisor getHotelDetails with specific dates to get live room offers.
    Only called for hotels sourced from TripAdvisor (numeric IDs).
    """
    try:
        data = await _rapidapi_get_json(
            ["/api/v1/hotels/getHotelDetails"],
            {
                "id": hotel_id,
                "checkIn": check_in.strftime("%Y-%m-%d"),
                "checkOut": check_out.strftime("%Y-%m-%d"),
                "adults": guests,
                "currency": "USD",
            },
            timeout=20.0,
        )
        if not data:
            return []

        # TripAdvisor response nests data differently across versions
        inner = data.get("data") or data
        rooms_raw: list[dict] = (
            inner.get("rooms") or
            inner.get("roomTypes") or
            inner.get("offers") or
            []
        )
        if not isinstance(rooms_raw, list) or not rooms_raw:
            return []

        offers: list[RoomOffer] = []
        for room in rooms_raw[:8]:
            # Price
            price_info = room.get("priceForDisplay") or room.get("price") or {}
            if isinstance(price_info, dict):
                raw_price = price_info.get("amount") or price_info.get("value") or 0
            elif isinstance(price_info, (int, float)):
                raw_price = price_info
            else:
                raw_price = 0
            try:
                price_usd = float(str(raw_price).replace("$", "").replace(",", "").strip() or 0)
            except (ValueError, TypeError):
                price_usd = 0.0
            if price_usd <= 0:
                price_usd = random.uniform(40, 150)
            price_pkr = round(price_usd * settings.USD_TO_PKR_RATE, 2)

            # Name
            name = (
                room.get("title") or room.get("name") or room.get("roomType") or "Standard Room"
            )

            # Bed type
            bed_types = room.get("bedTypes") or []
            if isinstance(bed_types, list) and bed_types:
                first = bed_types[0]
                bed = first.get("description", "Double") if isinstance(first, dict) else str(first)
            else:
                bed = room.get("bedType") or "Double"

            # Availability — use real count if present, otherwise seed-deterministic
            avail_raw = room.get("availableCount") or room.get("availability")
            try:
                avail = int(avail_raw) if avail_raw is not None else None
            except (ValueError, TypeError):
                avail = None
            if avail is None:
                seed = hash(f"{hotel_id}-{room.get('id', name)}-{check_in}") % (2 ** 31)
                avail = random.Random(seed).randint(2, 12)

            # Amenities
            raw_amenities = room.get("amenities") or []
            if isinstance(raw_amenities, list):
                amenities = [
                    a.get("name", a) if isinstance(a, dict) else str(a)
                    for a in raw_amenities[:8]
                ]
            else:
                amenities = []
            if not amenities:
                amenities = ["WiFi", "AC", "TV"]

            # Extra detail fields
            is_refundable = bool(room.get("isRefundable", True))
            max_guests = 2
            try:
                max_guests = int(room.get("maxOccupancy") or room.get("sleepCapacity") or 2)
            except (ValueError, TypeError):
                pass

            description = room.get("description") or ""
            size_raw = room.get("roomSize") or room.get("squareFeet")
            try:
                size_sqft = int(size_raw) if size_raw else None
            except (ValueError, TypeError):
                size_sqft = None
            has_city_view = bool(room.get("cityView") or "city view" in name.lower())
            has_balcony = bool(room.get("balcony") or "balcony" in name.lower())
            breakfast = bool(room.get("breakfastIncluded") or "breakfast" in name.lower())
            cancel_policy = room.get("cancellationPolicy") or (
                "Free cancellation up to 24 hours before check-in" if is_refundable else "Non-refundable"
            )

            room_id = f"TA-{hotel_id}-{room.get('id', random.randint(1000, 9999))}"
            offers.append(RoomOffer(
                room_id=room_id,
                room_type=name,
                bed_type=bed,
                price_per_night_pkr=price_pkr,
                max_guests=max_guests,
                is_refundable=is_refundable,
                amenities=amenities,
                rooms_available=avail,
                description=description,
                size_sqft=size_sqft,
                has_city_view=has_city_view,
                has_balcony=has_balcony,
                breakfast_included=breakfast,
                cancellation_policy=cancel_policy,
            ))

        logger.info("TripAdvisor rooms for hotel %s: %d rooms", hotel_id, len(offers))
        return offers

    except Exception as exc:
        logger.warning("TripAdvisor room fetch failed for %s: %s", hotel_id, exc)
        return []


def _enrich_rooms_with_availability(
    rooms: list[RoomOffer],
    check_in: date,
    check_out: date,
) -> list[RoomOffer]:
    """
    Add date-seeded deterministic availability counts to cached rooms.
    Pricier room types get fewer available rooms (realistic).
    """
    enriched: list[RoomOffer] = []
    for room in rooms:
        seed = hash(f"{room.room_id}-{check_in}-{check_out}") % (2 ** 31)
        rng = random.Random(seed)
        name_lower = room.room_type.lower()
        if "presidential" in name_lower or "penthouse" in name_lower:
            avail = rng.randint(1, 2)
        elif "suite" in name_lower or "executive" in name_lower:
            avail = rng.randint(1, 4)
        elif "deluxe" in name_lower or "business" in name_lower or "premium" in name_lower:
            avail = rng.randint(2, 8)
        else:
            avail = rng.randint(4, 15)

        enriched.append(RoomOffer(
            room_id=room.room_id,
            room_type=room.room_type,
            bed_type=room.bed_type,
            price_per_night_pkr=room.price_per_night_pkr,
            max_guests=room.max_guests,
            is_refundable=room.is_refundable,
            amenities=room.amenities,
            rooms_available=avail,
            description=room.description,
            size_sqft=room.size_sqft,
            has_city_view=room.has_city_view,
            has_balcony=room.has_balcony,
            breakfast_included=room.breakfast_included,
            cancellation_policy=room.cancellation_policy or (
                "Free cancellation up to 24 hours before check-in"
                if room.is_refundable else "Non-refundable"
            ),
        ))
    return enriched


async def fetch_hotel_rooms(
    hotel_id: str,
    check_in: date,
    check_out: date,
    guests: int,
    cached_hotel: "HotelOffer | None" = None,
) -> list[RoomOffer]:
    """
    Public entry point: fetch real-time room availability for one hotel.
    - HC-{id} hotels (Hotels.com source) → call Hotels.com detail endpoint
    - Numeric hotels (TripAdvisor source) → call TripAdvisor getHotelDetails
    - All other sources → enrich cached rooms with deterministic availability
    """
    # Hotels.com sourced hotels
    if hotel_id.startswith("HC-") and _hotels_com_is_configured():
        raw_id = hotel_id[3:]  # strip "HC-" prefix
        hc_rooms = await _fetch_hotels_com_rooms(raw_id, check_in, check_out, guests)
        if hc_rooms:
            return hc_rooms

    # TripAdvisor sourced hotels (numeric IDs)
    if hotel_id.isdigit() and _rapidapi_is_configured():
        ta_rooms = await _fetch_tripadvisor_rooms(hotel_id, check_in, check_out, guests)
        if ta_rooms:
            return ta_rooms

    # All other sources — enrich cached rooms with date-seeded availability
    if cached_hotel and cached_hotel.rooms:
        return _enrich_rooms_with_availability(cached_hotel.rooms, check_in, check_out)

    return []


# Public API

async def search_hotels(
    city: str,
    check_in: date,
    check_out: date,
    guests: int = 1,
    rooms: int = 1,
) -> HotelSearchResponse:
    """
    Search hotels for a given city and date range.

        Merge strategy:
            1. RapidAPI (TripAdvisor) as primary source.
            2. Nominatim supplements missing/insufficient results.
            3. OSM Overpass supplements remaining gaps.
            4. Curated mock catalogue fills final gaps.
    """
    nights = max((check_out - check_in).days, 1)
    canonical = CITY_ALIASES.get(city.strip().lower(), city.strip())

    hotels: list[HotelOffer] = []
    rapid_count = 0
    google_count = 0
    nominatim_count = 0
    osm_count = 0
    mock_count = 0

    # Hotels.com Provider disabled — API returns empty skeleton objects (LodgingCard/__typename only)
    # Re-enable once RapidAPI fixes the response format.

    # 2) TripAdvisor (RapidAPI) — always run if configured; no cap on results
    if _rapidapi_is_configured():
        geo_id = await _get_geo_id(canonical)
        if geo_id:
            rapid_results = await _search_hotels_tripadvisor(
                geo_id=geo_id,
                check_in=check_in,
                check_out=check_out,
                guests=guests,
                rooms=rooms,
            )
            parsed_hotels: list[HotelOffer] = []
            for prop in rapid_results:
                try:
                    parsed_hotels.append(_parse_hotel(prop, check_in, check_out, canonical))
                except Exception as exc:
                    logger.debug("Skipping malformed RapidAPI hotel payload: %s", exc)
            rapid_count = len(parsed_hotels)
            hotels = _merge_hotel_lists(hotels, parsed_hotels)
        logger.info("TripAdvisor returned %d hotels for %s", rapid_count, canonical)

    # 3) Google Places — only if TripAdvisor returned too few results
    if len(hotels) < _MIN_FALLBACK_COUNT and _google_places_is_configured():
        google_hotels = await _fetch_google_places_hotels(canonical, limit=50)
        google_count = len(google_hotels)
        hotels = _merge_hotel_lists(hotels, google_hotels)

    # 4) Nominatim — only if still too few results
    if len(hotels) < _MIN_FALLBACK_COUNT:
        nominatim_hotels = await _fetch_nominatim_hotels(canonical, limit=50)
        nominatim_count = len(nominatim_hotels)
        hotels = _merge_hotel_lists(hotels, nominatim_hotels)

    # 5) OSM — only if still too few results
    if len(hotels) < _MIN_FALLBACK_COUNT:
        osm_hotels = await _fetch_overpass_hotels(canonical)
        osm_count = len(osm_hotels)
        hotels = _merge_hotel_lists(hotels, osm_hotels)

    # 6) Mock — last resort if all APIs failed
    if len(hotels) < _MIN_FALLBACK_COUNT:
        mock_hotels = _mock_hotels(city, check_in, check_out, guests, rooms)
        mock_count = len(mock_hotels)
        hotels = _merge_hotel_lists(hotels, mock_hotels)

    # Assign placeholder image to any hotel missing photos
    _PLACEHOLDER_IMAGES = [
        "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80",
        "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&q=80",
        "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80",
        "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800&q=80",
        "https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800&q=80",
    ]
    for h in hotels:
        if not h.images:
            h.images = [_PLACEHOLDER_IMAGES[abs(hash(h.hotel_id)) % len(_PLACEHOLDER_IMAGES)]]

    logger.info(
        "Hotel search merged for %s: rapid=%d, google=%d, nominatim=%d, osm=%d, mock=%d, final=%d",
        city,
        rapid_count,
        google_count,
        nominatim_count,
        osm_count,
        mock_count,
        len(hotels),
    )
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
            resp = await client.post(
                _OVERPASS_URL,
                content=urllib.parse.urlencode({"data": query}).encode("utf-8"),
                headers={
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json",
                    "User-Agent": "TravelloAI/1.0 (travel booking app)",
                },
            )
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
