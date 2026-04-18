# =============================================================================
# FILE: routers/weather.py
# PREFIX: /weather
# Public endpoints — no authentication required.
# =============================================================================

from fastapi import APIRouter
from services.weather_service import get_weather, get_all_cities_weather

router = APIRouter(prefix="/weather", tags=["Weather"])


@router.get("/{city}")
async def city_weather(city: str):
    """
    Get current weather for a city.
    Uses Open-Meteo (free, no API key). Falls back to defaults if city unknown.

    Flutter call:
      GET /weather/Karachi
      GET /weather/Lahore
    """
    return await get_weather(city)


@router.get("/")
async def all_cities_weather():
    """
    Get current weather for all Pakistani cities in one call.
    Flutter weather screen uses this to populate the city list.
    """
    return {"cities": await get_all_cities_weather()}
