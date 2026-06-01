from __future__ import annotations

import logging
from datetime import date

from services.llm_service import generate_text, GeminiError
from prompts.recommendation import RECOMMENDATION_SYSTEM, DESTINATION_RECOMMENDATION_PROMPT

logger = logging.getLogger(__name__)


async def get_recommendations(
    user_memory: dict,
    past_destinations: list | None = None,
) -> str:
    """
    Return personalized Pakistan travel destination recommendations
    based on the user's saved preferences and travel history.
    Returns '' on any error — never raises.
    """
    context = (
        "Give personalized Pakistan travel recommendations. "
        f"User preferences: {user_memory}."
    )
    if past_destinations:
        context += f" Previously visited: {past_destinations}"

    origin_city    = user_memory.get("origin_city") or "your city"
    budget_style   = user_memory.get("budget_style") or "standard"
    companion_type = user_memory.get("companion_type") or "solo"
    travel_style   = user_memory.get("travel_style") or "standard"

    prompt = DESTINATION_RECOMMENDATION_PROMPT.format(
        budget_style=budget_style,
        companion_type=companion_type,
        travel_style=travel_style,
        past_destinations=past_destinations or [],
        current_month=date.today().strftime("%B"),
        origin_city=origin_city,
        interests="sightseeing, food, nature",
    )

    messages = [
        {"role": "system", "content": RECOMMENDATION_SYSTEM},
        {"role": "user", "content": context + "\n\n" + prompt},
    ]

    try:
        return await generate_text(messages, temperature=0.7, max_output_tokens=1024)
    except GeminiError as exc:
        logger.warning("recommendation_agent Gemini call failed: %s", exc)
        return ""
    except Exception as exc:
        logger.warning("recommendation_agent failed: %s", exc)
        return ""
