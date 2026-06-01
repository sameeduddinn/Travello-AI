from __future__ import annotations

import logging
from datetime import date, timedelta

from services.llm_service import generate_text, GeminiError
from prompts.itinerary import ITINERARY_SYSTEM, ITINERARY_BUILD_PROMPT

logger = logging.getLogger(__name__)


async def generate_itinerary(
    destination: str,
    duration_days: int,
    travelers: int,
    travel_style: str,
    budget_pkr: float,
    weather_info: str | None = None,
    hotel_summary: str | None = None,
    transport_summary: str | None = None,
    travel_date: str | None = None,
) -> str:
    """
    Ask Gemini to build a day-by-day itinerary.
    Accepts real phase-1 agent outputs (weather, hotels, transport) so the
    itinerary reflects actual options rather than generic placeholders.
    `travel_date` should be a YYYY-MM-DD string — the user's actual start date.
    Returns '' on any error — never raises.
    """
    if travel_date:
        try:
            from datetime import datetime as _dt
            start_date = _dt.strptime(travel_date, "%Y-%m-%d").date()
        except ValueError:
            start_date = date.today() + timedelta(days=7)
    else:
        start_date = date.today() + timedelta(days=7)
    end_date = start_date + timedelta(days=duration_days - 1)

    context = (
        f"Create a {duration_days}-day itinerary for {destination} "
        f"for {travelers} traveler(s). "
        f"Budget: PKR {budget_pkr:,.0f}. "
        f"Style: {travel_style}."
    )
    if weather_info:
        context += f" Weather: {weather_info[:300]}"
    if transport_summary:
        context += f" Transport: {transport_summary[:300]}"
    if hotel_summary:
        context += f" Hotels: {hotel_summary[:300]}"

    prompt = ITINERARY_BUILD_PROMPT.format(
        destination=destination,
        duration_days=duration_days,
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        travelers=travelers,
        companion_type="travelers",
        budget_pkr=f"{budget_pkr:,.0f}",
        budget_style=travel_style,
        travel_style=travel_style,
        interests="general sightseeing, food, culture",
        weather_summary=weather_info or "not available",
        hotel_summary=hotel_summary or "see hotel recommendations",
        transport_summary=transport_summary or "see transport options",
    )

    messages = [
        {"role": "system", "content": ITINERARY_SYSTEM},
        {"role": "user", "content": context + "\n\n" + prompt},
    ]

    try:
        return await generate_text(messages, temperature=0.6, max_output_tokens=2048)
    except GeminiError as exc:
        logger.warning("itinerary_agent Gemini call failed for dest=%s: %s", destination, exc)
        return ""
    except Exception as exc:
        logger.warning("itinerary_agent failed for dest=%s: %s", destination, exc)
        return ""
