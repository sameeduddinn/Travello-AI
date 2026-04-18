# =============================================================================
# FILE: services/weather_service.py
# PURPOSE: Real-time weather data via Open-Meteo API.
#          Open-Meteo is completely free — no API key required.
#          Docs: https://open-meteo.com/en/docs
#
# Supported cities: all major Pakistani cities + popular international
#                   destinations (Dubai, London, Doha, etc.)
# =============================================================================

from __future__ import annotations

import logging
from typing import Any

import httpx

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

# City → (latitude, longitude)
CITY_COORDS: dict[str, tuple[float, float]] = {
    # Pakistan
    "Karachi":     (24.8607,  67.0011),
    "Lahore":      (31.5204,  74.3587),
    "Islamabad":   (33.7294,  73.0931),
    "Rawalpindi":  (33.6007,  73.0679),
    "Faisalabad":  (31.4504,  73.1350),
    "Multan":      (30.1978,  71.4711),
    "Peshawar":    (34.0151,  71.5249),
    "Quetta":      (30.1798,  66.9750),
    "Sialkot":     (32.4945,  74.5229),
    "Gujranwala":  (32.1877,  74.1945),
    "Hyderabad":   (25.3960,  68.3578),
    "Sukkur":      (27.7052,  68.8574),
    "Murree":      (33.9072,  73.3943),
    "Gilgit":      (35.9219,  74.3085),
    "Skardu":      (35.2971,  75.6349),
    # International popular destinations
    "Dubai":       (25.2048,  55.2708),
    "Abu Dhabi":   (24.4539,  54.3773),
    "Doha":        (25.2854,  51.5310),
    "London":      (51.5074,  -0.1278),
    "New York":    (40.7128, -74.0060),
    "Istanbul":    (41.0082,  28.9784),
    "Kuala Lumpur":(3.1390,  101.6869),
    "Bangkok":     (13.7563,  100.5018),
}


# ---------------------------------------------------------------------------
# WMO weather-code → human-readable condition + Flutter icon name
# ---------------------------------------------------------------------------

def _wmo_to_condition(code: int) -> tuple[str, str]:
    """
    Map WMO Weather Interpretation Code to (condition_string, icon_name).
    icon_name matches Flutter's Icons constants used in the weather screen.
    """
    if code == 0:
        return "Clear Sky", "wb_sunny"
    if code in (1, 2):
        return "Partly Cloudy", "wb_cloudy"
    if code == 3:
        return "Overcast", "cloud"
    if code in (45, 48):
        return "Foggy", "foggy"
    if code in (51, 53, 55):
        return "Drizzle", "grain"
    if code in (61, 63):
        return "Rain", "water_drop"
    if code == 65:
        return "Heavy Rain", "thunderstorm"
    if code in (71, 73, 75, 77):
        return "Snow", "ac_unit"
    if code in (80, 81, 82):
        return "Rain Showers", "water_drop"
    if code in (85, 86):
        return "Snow Showers", "ac_unit"
    if code == 95:
        return "Thunderstorm", "thunderstorm"
    if code in (96, 99):
        return "Thunderstorm with Hail", "thunderstorm"
    return "Cloudy", "cloud"


# ---------------------------------------------------------------------------
# Travel warning heuristics
# ---------------------------------------------------------------------------

def _travel_warning(
    condition: str,
    temp_c: float,
    wind_kmh: float,
    humidity: int,
) -> tuple[bool, str]:
    """Return (has_warning, warning_message) based on weather parameters."""
    if temp_c >= 42:
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


# ---------------------------------------------------------------------------
# Fallback / default weather
# ---------------------------------------------------------------------------

def _default_weather(city: str) -> dict[str, Any]:
    return {
        "city": city,
        "temperature": 27.0,
        "feels_like": 27.0,
        "humidity": 55,
        "wind_speed": 10.0,
        "condition": "Pleasant",
        "icon": "wb_sunny",
        "travel_warning": False,
        "warning_message": "",
        "source": "fallback",
    }


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def get_weather(city: str) -> dict[str, Any]:
    """
    Fetch current weather for a city using Open-Meteo (free, no API key).
    Returns a dict compatible with the Flutter WeatherData model.
    """
    # Exact match
    coords = CITY_COORDS.get(city)

    # Case-insensitive fuzzy match if exact not found
    if coords is None:
        city_lower = city.lower().strip()
        for k, v in CITY_COORDS.items():
            if k.lower() == city_lower or city_lower in k.lower() or k.lower() in city_lower:
                coords = v
                break

    if coords is None:
        logger.warning("No coordinates found for city '%s' — returning fallback.", city)
        return _default_weather(city)

    lat, lon = coords

    params = {
        "latitude": lat,
        "longitude": lon,
        "current": ",".join([
            "temperature_2m",
            "apparent_temperature",
            "relative_humidity_2m",
            "weather_code",
            "wind_speed_10m",
        ]),
        "timezone": "auto",
        "wind_speed_unit": "kmh",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(OPEN_METEO_URL, params=params)

        if response.status_code != 200:
            logger.error(
                "Open-Meteo error %s for %s: %s",
                response.status_code, city, response.text[:200],
            )
            return _default_weather(city)

        data = response.json()
        current: dict = data.get("current", {})

        temp_c: float = round(float(current.get("temperature_2m", 27)), 1)
        feels_like: float = round(float(current.get("apparent_temperature", temp_c)), 1)
        humidity: int = int(current.get("relative_humidity_2m", 55))
        wind_kmh: float = round(float(current.get("wind_speed_10m", 10)), 1)
        weather_code: int = int(current.get("weather_code", 0))

        condition, icon = _wmo_to_condition(weather_code)
        has_warning, warning_msg = _travel_warning(condition, temp_c, wind_kmh, humidity)

        return {
            "city": city,
            "temperature": temp_c,
            "feels_like": feels_like,
            "humidity": humidity,
            "wind_speed": wind_kmh,
            "condition": condition,
            "icon": icon,
            "travel_warning": has_warning,
            "warning_message": warning_msg,
            "source": "open-meteo",
        }

    except Exception as exc:
        logger.error("Open-Meteo request failed for '%s': %s", city, exc)
        return _default_weather(city)


async def get_all_cities_weather() -> list[dict[str, Any]]:
    """Fetch weather for all Pakistani cities in parallel."""
    import asyncio

    pk_cities = [
        "Karachi", "Lahore", "Islamabad", "Rawalpindi", "Faisalabad",
        "Multan", "Peshawar", "Quetta", "Sialkot", "Gujranwala",
        "Hyderabad", "Sukkur", "Murree", "Gilgit", "Skardu",
    ]
    results = await asyncio.gather(
        *[get_weather(city) for city in pk_cities],
        return_exceptions=True,
    )
    return [
        r if isinstance(r, dict) else _default_weather(pk_cities[i])
        for i, r in enumerate(results)
    ]
