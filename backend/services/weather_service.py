from __future__ import annotations
# =============================================================================
# LOOKUP CHAIN per city:
#   1. Google Weather API  — primary  (accurate, real-time, global coverage)
#   2. Open-Meteo          — fallback (free, no key, WMO-code based)
#   3. Static default      — last resort (always returns something)
# =============================================================================

import asyncio
import logging
import time
from typing import Any

import httpx
from core.config import settings

# Configuration

_GOOGLE_API_KEY: str = settings.GOOGLE_PLACES_API_KEY
_GOOGLE_WEATHER_URL = "https://weather.googleapis.com/v1/currentConditions:lookup"
_OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

# Limit concurrent Open-Meteo requests
_OPEN_METEO_SEMAPHORE = asyncio.Semaphore(5)

# Per-city cache: city -> (result_dict, fetched_at_monotonic) — 5-min TTL
_CACHE: dict[str, tuple[dict, float]] = {}
_CACHE_TTL = 300  # 5 minutes

# All-cities bulk cache — 2-hour TTL, shared across all users
_ALL_CITIES_CACHE: tuple[list, float] | None = None
_ALL_CITIES_TTL = 7200  # 2 hours

logger = logging.getLogger(__name__)

# City coordinates  (used as fallback when API doesn't resolve by name)
CITY_COORDS: dict[str, tuple[float, float]] = {
    # Pakistan - major cities 
    "Karachi":          (24.8607,  67.0011),
    "Lahore":           (31.5204,  74.3587),
    "Islamabad":        (33.7294,  73.0931),
    "Rawalpindi":       (33.6007,  73.0679),
    "Faisalabad":       (31.4504,  73.1350),
    "Multan":           (30.1978,  71.4711),
    "Peshawar":         (34.0151,  71.5249),
    "Quetta":           (30.1798,  66.9750),
    "Sialkot":          (32.4945,  74.5229),
    "Gujranwala":       (32.1877,  74.1945),
    "Bahawalpur":       (29.3956,  71.6836),
    "Hyderabad":        (25.3960,  68.3578),
    "Sukkur":           (27.7052,  68.8574),
    "Larkana":          (27.5580,  68.2150),
    "Dera Ghazi Khan":  (30.0571,  70.6350),
    "Gwadar":           (25.1264,  62.3225),
    "Mirpur":           (33.1475,  73.7511),
    # ─ Northern Pakistan & tourism 
    "Murree":           (33.9072,  73.3943),
    "Nathiagali":       (34.0741,  73.3778),
    "Gilgit":           (35.9219,  74.3085),
    "Skardu":           (35.2971,  75.6349),
    "Hunza":            (36.3167,  74.6500),
    "Naran":            (34.9030,  73.6540),
    "Kaghan":           (34.7733,  73.5419),
    "Chitral":          (35.8518,  71.7864),
    "Swat":             (34.7462,  72.3578),
    "Abbottabad":       (34.1463,  73.2117),
    "Mansehra":         (34.3300,  73.2000),
    "Muzaffarabad":     (34.3700,  73.4711),
    "Rawalakot":        (33.8575,  73.7614),
    "Ziarat":           (30.3810,  67.7285),
    "Fairy Meadows":    (35.3753,  74.5958),
    "Kalash Valley":    (35.7000,  71.6000),
    "Deosai":           (35.0000,  75.5000),
    # ── International popular destinations ───────────────────────────────────
    "Dubai":            (25.2048,  55.2708),
    "Abu Dhabi":        (24.4539,  54.3773),
    "Doha":             (25.2854,  51.5310),
    "London":           (51.5074,  -0.1278),
    "New York":         (40.7128, -74.0060),
    "Istanbul":         (41.0082,  28.9784),
    "Kuala Lumpur":     ( 3.1390, 101.6869),
    "Bangkok":          (13.7563, 100.5018),
}


# Condition normalisation helpers

# Google Weather API condition type -> (condition_label, flutter_icon)
_GOOGLE_CONDITION_MAP: dict[str, tuple[str, str]] = {
    "CLEAR":                       ("Clear Sky",              "wb_sunny"),
    "MOSTLY_CLEAR":                ("Clear Sky",              "wb_sunny"),
    "PARTLY_CLOUDY":               ("Partly Cloudy",          "wb_cloudy"),
    "MOSTLY_CLOUDY":               ("Overcast",               "cloud"),
    "CLOUDY":                      ("Overcast",               "cloud"),
    "WINDY":                       ("Windy",                  "air"),
    "FOGGY":                       ("Foggy",                  "foggy"),
    "HAZE":                        ("Hazy",                   "foggy"),
    "CHANCE_OF_FOG":               ("Foggy",                  "foggy"),
    "DRIZZLE":                     ("Drizzle",                "grain"),
    "LIGHT_RAIN":                  ("Drizzle",                "grain"),
    "CHANCE_OF_RAIN":              ("Drizzle",                "grain"),
    "RAIN":                        ("Rain",                   "water_drop"),
    "RAIN_SHOWERS":                ("Rain Showers",           "water_drop"),
    "HEAVY_RAIN":                  ("Heavy Rain",             "thunderstorm"),
    "CHANCE_OF_THUNDERSTORM":      ("Thunderstorm",           "thunderstorm"),
    "THUNDERSTORM":                ("Thunderstorm",           "thunderstorm"),
    "THUNDERSTORM_WITH_HAIL":      ("Thunderstorm with Hail", "thunderstorm"),
    "LIGHT_SNOW":                  ("Snow",                   "ac_unit"),
    "SNOW":                        ("Snow",                   "ac_unit"),
    "HEAVY_SNOW":                  ("Snow",                   "ac_unit"),
    "BLIZZARD":                    ("Snow",                   "ac_unit"),
    "SNOW_SHOWERS":                ("Snow Showers",           "ac_unit"),
    "SLEET":                       ("Sleet",                  "grain"),
    "FREEZING_DRIZZLE":            ("Freezing Drizzle",       "grain"),
    "ICE_PELLETS":                 ("Ice Pellets",            "grain"),
    "WINTRY_MIX":                  ("Wintry Mix",             "grain"),
    "DUST":                        ("Dusty",                  "cloud"),
    "SMOKE":                       ("Smoky",                  "cloud"),
    "TROPICAL_STORM":              ("Thunderstorm",           "thunderstorm"),
    "HURRICANE":                   ("Thunderstorm",           "thunderstorm"),
}


def _google_type_to_condition(condition_type: str) -> tuple[str, str]:
    return _GOOGLE_CONDITION_MAP.get(condition_type.upper(), ("Cloudy", "cloud"))


def _wmo_to_condition(code: int) -> tuple[str, str]:
    """Map WMO Weather Interpretation Code to (condition_label, flutter_icon)."""
    if code == 0:                      return "Clear Sky",              "wb_sunny"
    if code in (1, 2):                 return "Partly Cloudy",          "wb_cloudy"
    if code == 3:                      return "Overcast",               "cloud"
    if code in (45, 48):               return "Foggy",                  "foggy"
    if code in (51, 53, 55):           return "Drizzle",                "grain"
    if code in (61, 63):               return "Rain",                   "water_drop"
    if code == 65:                     return "Heavy Rain",             "thunderstorm"
    if code in (71, 73, 75, 77):       return "Snow",                   "ac_unit"
    if code in (80, 81, 82):           return "Rain Showers",           "water_drop"
    if code in (85, 86):               return "Snow Showers",           "ac_unit"
    if code == 95:                     return "Thunderstorm",           "thunderstorm"
    if code in (96, 99):               return "Thunderstorm with Hail", "thunderstorm"
    return "Cloudy", "cloud"


def _travel_warning(condition: str, temp_c: float, wind_kmh: float) -> tuple[bool, str]:
    if temp_c >= 38:
        return True, "Extreme heat warning. Stay hydrated and avoid outdoor travel during peak hours."
    if temp_c <= 0:
        return True, "Freezing temperatures. Ice on roads likely — travel with extreme caution."
    if wind_kmh >= 50:
        return True, "Strong wind warning. Outdoor activities and driving may be hazardous."
    if "thunderstorm" in condition.lower():
        return True, "Thunderstorm alert. Avoid outdoor travel and seek shelter."
    if "heavy rain" in condition.lower():
        return True, "Heavy rain warning. Roads may be flooded — check conditions before travelling."
    if "snow" in condition.lower() and temp_c < 5:
        return True, "Snow expected. Mountain roads may be blocked. Carry warm clothing."
    return False, ""


def _build_result(
    city: str,
    temp_c: float,
    feels_like: float,
    humidity: int,
    wind_kmh: float,
    condition: str,
    icon: str,
    source: str,
) -> dict[str, Any]:
    has_warning, warning_msg = _travel_warning(condition, temp_c, wind_kmh)
    return {
        "city":            city,
        "temperature":     round(temp_c, 1),
        "feels_like":      round(feels_like, 1),
        "humidity":        humidity,
        "wind_speed":      round(wind_kmh, 1),
        "condition":       condition,
        "icon":            icon,
        "travel_warning":  has_warning,
        "warning_message": warning_msg,
        "source":          source,
    }


def _default_weather(city: str) -> dict[str, Any]:
    return _build_result(city, 27.0, 27.0, 55, 10.0, "Pleasant", "wb_sunny", "fallback")


# Source 1 — Google Weather API

async def _fetch_google_weather(city: str, lat: float, lon: float) -> dict[str, Any] | None:
    """
    Call Google Weather API for current conditions at the given coordinates.
    Returns a normalised weather dict, or None on any failure.
    """
    if not _GOOGLE_API_KEY:
        return None

    params: dict[str, Any] = {
        "key":                _GOOGLE_API_KEY,
        "location.latitude":  lat,
        "location.longitude": lon,
        "unitsSystem":        "METRIC",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(_GOOGLE_WEATHER_URL, params=params)

        if response.status_code == 403:
            logger.error(
                "Google Weather API key rejected (403). "
                "Ensure 'Weather API' is enabled in Google Cloud Console."
            )
            return None

        if response.status_code != 200:
            logger.warning(
                "Google Weather HTTP %s for '%s' — falling back to Open-Meteo",
                response.status_code, city,
            )
            return None

        data = response.json()

        logger.debug("Google Weather raw response for '%s': %s", city, str(data)[:600])

        # "currentConditions" is the standard wrapper key; some API versions omit it
        current: dict = data.get("currentConditions") or data

        # Temperature — tries "degrees" (documented) and "value" (alternative)
        temp_obj   = current.get("temperature") or {}
        feels_obj  = current.get("feelsLikeTemperature") or {}
        temp_c     = float(temp_obj.get("degrees") or temp_obj.get("value") or 0.0)
        feels_like = float(feels_obj.get("degrees") or feels_obj.get("value") or temp_c)

        # Humidity
        humidity = int(current.get("humidity") or current.get("relativeHumidity") or 55)

        # Wind speed — tries "speed.value" and "speed.degrees"
        wind_obj  = current.get("wind") or {}
        speed_obj = wind_obj.get("speed") or {}
        wind_kmh  = float(speed_obj.get("value") or speed_obj.get("degrees") or 10.0)

        # Condition type — tries "weatherCondition.type" then description text
        cond_obj       = current.get("weatherCondition") or {}
        condition_type = cond_obj.get("type") or "CLOUDY"
        condition, icon = _google_type_to_condition(condition_type)

        # If temp is still 0, the schema didn't match — return None to fall back
        if temp_c == 0.0:
            logger.warning("Google Weather: could not parse temperature for '%s' — schema mismatch. Raw: %s", city, str(data)[:400])
            return None

        result = _build_result(city, temp_c, feels_like, humidity, wind_kmh, condition, icon, "google-weather")
        logger.debug("Google Weather: %s → %s %.1f°C", city, condition, temp_c)
        return result

    except Exception as exc:
        logger.warning("Google Weather request failed for '%s': %s", city, exc)
        return None


# Source 2 — Open-Meteo (fallback)

async def _fetch_open_meteo(city: str, lat: float, lon: float) -> dict[str, Any] | None:
    """
    Call Open-Meteo for current conditions. Semaphore-limited to avoid 429s.
    Returns a normalised weather dict, or None on any failure.
    """
    params = {
        "latitude":       lat,
        "longitude":      lon,
        "current":        "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m",
        "timezone":       "auto",
        "wind_speed_unit": "kmh",
    }

    try:
        async with _OPEN_METEO_SEMAPHORE:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(_OPEN_METEO_URL, params=params)

        if response.status_code != 200:
            logger.warning(
                "Open-Meteo HTTP %s for '%s': %s",
                response.status_code, city, response.text[:200],
            )
            return None

        data    = response.json()
        current = data.get("current", {})

        temp_c     = float(current.get("temperature_2m", 27))
        feels_like = float(current.get("apparent_temperature", temp_c))
        humidity   = int(current.get("relative_humidity_2m", 55))
        wind_kmh   = float(current.get("wind_speed_10m", 10))
        wmo_code   = int(current.get("weather_code", 0))

        condition, icon = _wmo_to_condition(wmo_code)
        result = _build_result(city, temp_c, feels_like, humidity, wind_kmh, condition, icon, "open-meteo")
        logger.debug("Open-Meteo: %s → %s %.1f°C", city, condition, temp_c)
        return result

    except Exception as exc:
        logger.warning("Open-Meteo request failed for '%s': %s", city, exc)
        return None


# Coordinate resolver

def _resolve_coords(city: str) -> tuple[float, float] | None:
    """Exact match first, then case-insensitive fuzzy match."""
    coords = CITY_COORDS.get(city)
    if coords:
        return coords
    city_lower = city.lower().strip()
    for k, v in CITY_COORDS.items():
        if k.lower() == city_lower or city_lower in k.lower() or k.lower() in city_lower:
            return v
    return None


# Public API

async def get_weather(city: str) -> dict[str, Any]:
    """
    Fetch current weather for a city.
    Chain: Google Weather API → Open-Meteo → static default.
    Results are cached for 5 minutes.
    """
    # Serve from cache if still fresh
    cached = _CACHE.get(city)
    if cached and (time.monotonic() - cached[1]) < _CACHE_TTL:
        return cached[0]

    coords = _resolve_coords(city)
    if coords is None:
        logger.warning("No coordinates for '%s' — returning fallback.", city)
        return _default_weather(city)

    lat, lon = coords

    # 1. Google Weather API (primary)
    result = await _fetch_google_weather(city, lat, lon)

    # 2. Open-Meteo (fallback)
    if result is None:
        logger.info("Google Weather unavailable for '%s' — trying Open-Meteo.", city)
        result = await _fetch_open_meteo(city, lat, lon)

    # 3. Static default (last resort)
    if result is None:
        logger.warning("All weather sources failed for '%s' — using default.", city)
        result = _default_weather(city)

    _CACHE[city] = (result, time.monotonic())
    return result


async def get_all_cities_weather() -> list[dict[str, Any]]:
    """
    Fetch weather for all Pakistani cities in parallel.
    Results are cached for 2 hours — shared across all users so the Google
    Weather API is called at most once per 2-hour window, not once per user.
    """
    global _ALL_CITIES_CACHE

    if _ALL_CITIES_CACHE is not None:
        data, fetched_at = _ALL_CITIES_CACHE
        if (time.monotonic() - fetched_at) < _ALL_CITIES_TTL:
            logger.debug("Serving all-cities weather from 2-hour cache.")
            return data

    pk_cities = [
        "Karachi", "Lahore", "Islamabad", "Rawalpindi", "Faisalabad",
        "Multan", "Peshawar", "Quetta", "Sialkot", "Gujranwala",
        "Bahawalpur", "Hyderabad", "Sukkur", "Larkana",
        "Murree", "Nathiagali", "Abbottabad", "Swat",
        "Gilgit", "Skardu", "Hunza", "Naran", "Chitral",
        "Muzaffarabad", "Ziarat", "Gwadar",
    ]
    results = await asyncio.gather(
        *[get_weather(city) for city in pk_cities],
        return_exceptions=True,
    )
    data = [
        r if isinstance(r, dict) else _default_weather(pk_cities[i])
        for i, r in enumerate(results)
    ]
    _ALL_CITIES_CACHE = (data, time.monotonic())
    logger.info("All-cities weather cache refreshed (%d cities).", len(data))
    return data
