from __future__ import annotations

import asyncio
import logging

from fastapi import HTTPException

from routers.healthcare import (
    _nearby,
    _MOCK_HOSPITALS,
    _MOCK_PHARMACIES,
    _resolve_coordinates,
)
from services.llm_service import generate_text, GeminiError
from prompts.healthcare import HEALTHCARE_SYSTEM, HEALTHCARE_RESULTS_PROMPT

logger = logging.getLogger(__name__)


async def get_safety_briefing(city: str) -> str:
    """
    Locate nearby hospitals and pharmacies for `city`, then return a
    Gemini-generated safety briefing string.
    Returns a user-friendly message on city-not-found, '' on other errors.
    """
    # Step 1 — resolve city name to lat/lng
    try:
        lat, lng = _resolve_coordinates(None, None, None, city)
    except HTTPException:
        return (
            f"I could not find healthcare information for {city}. "
            "Please check the city name and try again."
        )
    except Exception as exc:
        logger.warning("healthcare_agent: coordinate resolution failed for city=%s: %s", city, exc)
        return ""

    # Step 2 — fetch hospitals and pharmacies in parallel
    try:
        hospitals, pharmacies = await asyncio.gather(
            _nearby(lat, lng, 15.0, "hospital", _MOCK_HOSPITALS),
            _nearby(lat, lng, 5.0,  "pharmacy", _MOCK_PHARMACIES),
        )
    except Exception as exc:
        logger.warning("healthcare_agent: _nearby calls failed for city=%s: %s", city, exc)
        hospitals, pharmacies = [], []

    # Step 3 — ask Gemini for a travel safety briefing
    prompt = HEALTHCARE_RESULTS_PROMPT.format(
        location=city,
        facility_type="hospitals and pharmacies",
        results={
            "hospitals":  (hospitals or [])[:5],
            "pharmacies": (pharmacies or [])[:3],
        },
    )

    messages = [
        {"role": "system", "content": HEALTHCARE_SYSTEM},
        {
            "role": "user",
            "content": (
                f"Provide a safety briefing for {city}. "
                f"Nearby hospitals: {(hospitals or [])[:5]}. "
                f"Nearby pharmacies: {(pharmacies or [])[:3]}.\n\n"
                + prompt
            ),
        },
    ]

    try:
        return await generate_text(messages, temperature=0.4, max_output_tokens=384)
    except GeminiError as exc:
        logger.warning("healthcare_agent Gemini call failed for city=%s: %s", city, exc)
        return ""
    except Exception as exc:
        logger.warning("healthcare_agent failed for city=%s: %s", city, exc)
        return ""
