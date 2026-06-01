from __future__ import annotations

import asyncio
import logging
from datetime import date as date_type, datetime, timedelta

from services.flight_service import search_flights
from services.train_service import search_trains
from agents.clarification_agent import CITY_TO_IATA
from services.llm_service import generate_text, GeminiError
from prompts.transport import TRANSPORT_SYSTEM

logger = logging.getLogger(__name__)


async def compare_transport(
    origin: str,
    destination: str,
    travel_date,          # str "YYYY-MM-DD" | date object | None
    passengers: int,
    budget_pkr: float,
) -> str:
    """
    Search flights and trains in parallel, then return a Gemini-generated
    comparison and recommendation string.
    Returns '' on any unrecoverable error — never raises.
    """
    # Convert travel_date to a Python date object (Gemini returns strings)
    if travel_date is None:
        travel_date = date_type.today() + timedelta(days=7)
    elif isinstance(travel_date, str):
        try:
            travel_date = datetime.strptime(travel_date, "%Y-%m-%d").date()
        except ValueError:
            travel_date = date_type.today() + timedelta(days=7)

    origin_iata = CITY_TO_IATA.get(origin.lower())
    dest_iata   = CITY_TO_IATA.get(destination.lower())

    async def _get_flights():
        if not origin_iata or not dest_iata:
            logger.info(
                "transport_agent: no IATA code for %s or %s — skipping flights",
                origin, destination,
            )
            return []
        try:
            return await search_flights(origin_iata, dest_iata, travel_date, passengers)
        except Exception as exc:
            logger.warning("search_flights failed: %s", exc)
            return []

    def _get_trains():
        try:
            return search_trains(origin, destination, travel_date, passengers)
        except Exception as exc:
            logger.warning("search_trains failed: %s", exc)
            return None

    flight_results, train_results = await asyncio.gather(
        _get_flights(),
        asyncio.to_thread(_get_trains),
    )

    messages = [
        {"role": "system", "content": TRANSPORT_SYSTEM},
        {
            "role": "user",
            "content": (
                f"Compare transport from {origin} to {destination} "
                f"on {travel_date.isoformat()} for {passengers} passenger(s). "
                f"Budget: PKR {budget_pkr:,.0f}.\n\n"
                f"Flight results: {flight_results or 'No flights found'}.\n\n"
                f"Train results: {train_results or 'No trains found'}."
            ),
        },
    ]

    try:
        return await generate_text(messages, temperature=0.5, max_output_tokens=512)
    except GeminiError as exc:
        logger.warning("transport_agent Gemini call failed: %s", exc)
        return ""
    except Exception as exc:
        logger.warning("transport_agent failed: %s", exc)
        return ""
