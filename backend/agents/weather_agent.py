from __future__ import annotations

import logging
from datetime import date, timedelta

from services.weather_service import get_weather
from services.llm_service import generate_text, GeminiError
from prompts.weather import WEATHER_SYSTEM, WEATHER_SUMMARY_PROMPT

logger = logging.getLogger(__name__)


async def get_weather_intelligence(
    city: str,
    travel_date: str | None = None,
) -> str:
    """
    Fetch live weather for `city` then ask Gemini for practical travel advice.

    `travel_date` should be a YYYY-MM-DD string (the user's actual travel date).
    Falls back to today+7 if not provided so advice is still forward-looking.
    Returns '' on any error — never raises (safe to use in asyncio.gather).
    """
    try:
        weather_data = await get_weather(city)

        # Use actual travel date; default to one week out if unknown
        date_label = travel_date or (date.today() + timedelta(days=7)).isoformat()

        prompt = WEATHER_SUMMARY_PROMPT.format(
            city=city,
            weather_data=weather_data,
            travel_date=date_label,
        )

        messages = [
            {"role": "system", "content": WEATHER_SYSTEM},
            {"role": "user", "content": prompt},
        ]

        return await generate_text(messages, temperature=0.5, max_output_tokens=256)

    except GeminiError as exc:
        logger.warning("weather_agent Gemini call failed for city=%s: %s", city, exc)
        return ""
    except Exception as exc:
        logger.warning("weather_agent failed for city=%s: %s", city, exc)
        return ""
