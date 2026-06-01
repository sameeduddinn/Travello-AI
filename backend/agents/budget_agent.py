from __future__ import annotations

import logging

from services.llm_service import generate_text, GeminiError
from prompts.budget import BUDGET_SYSTEM, BUDGET_ESTIMATE_PROMPT

logger = logging.getLogger(__name__)


async def calculate_budget(
    destination: str,
    duration_days: int,
    travelers: int,
    travel_style: str,
    transport_info: str | None = None,
    hotel_info: str | None = None,
) -> str:
    """
    Ask Gemini to estimate a detailed travel budget breakdown in PKR.
    Returns '' on any error — never raises.
    """
    context = (
        f"Calculate budget for {duration_days} days in {destination} "
        f"for {travelers} traveler(s). "
        f"Style: {travel_style}."
    )
    if transport_info:
        context += f" Transport options: {transport_info}"
    if hotel_info:
        context += f" Hotel options: {hotel_info}"

    prompt = BUDGET_ESTIMATE_PROMPT.format(
        origin="origin city",
        destination=destination,
        duration_days=duration_days,
        travelers=travelers,
        budget_style=travel_style,
        transport_cost_pkr=0,   # unknown at this stage — Gemini will estimate
        hotel_cost_pkr=0,
    )

    messages = [
        {"role": "system", "content": BUDGET_SYSTEM},
        {"role": "user", "content": context + "\n\n" + prompt},
    ]

    try:
        return await generate_text(messages, temperature=0.3, max_output_tokens=1024)
    except GeminiError as exc:
        logger.warning("budget_agent Gemini call failed for dest=%s: %s", destination, exc)
        return ""
    except Exception as exc:
        logger.warning("budget_agent failed for dest=%s: %s", destination, exc)
        return ""
