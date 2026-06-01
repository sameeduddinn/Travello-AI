from __future__ import annotations

import logging
from datetime import date as date_type, datetime, timedelta

from services.hotel_service import search_hotels
from services.llm_service import generate_text, GeminiError
from prompts.hotel import HOTEL_SYSTEM

logger = logging.getLogger(__name__)


async def find_hotels(
    city: str,
    check_in,                       # str "YYYY-MM-DD" | date object | None
    check_out,                      # str "YYYY-MM-DD" | date object | None
    guests: int,
    rooms: int = 1,
    budget_per_night: float | None = None,
    travel_style: str = "standard",
) -> str:
    """
    Search hotels then return a Gemini-generated recommendation string.
    Returns '' on any unrecoverable error — never raises.
    """
    # Convert check_in / check_out to Python date objects
    today = date_type.today()

    if check_in is None:
        check_in = today + timedelta(days=7)
    elif isinstance(check_in, str):
        try:
            check_in = datetime.strptime(check_in, "%Y-%m-%d").date()
        except ValueError:
            check_in = today + timedelta(days=7)

    if check_out is None:
        check_out = check_in + timedelta(days=3)
    elif isinstance(check_out, str):
        try:
            check_out = datetime.strptime(check_out, "%Y-%m-%d").date()
        except ValueError:
            check_out = check_in + timedelta(days=3)

    try:
        hotel_data = await search_hotels(city, check_in, check_out, guests, rooms)
    except Exception as exc:
        logger.warning("search_hotels failed for city=%s: %s", city, exc)
        hotel_data = None

    budget_label = f"PKR {budget_per_night:,.0f}/night" if budget_per_night else "not specified"

    messages = [
        {"role": "system", "content": HOTEL_SYSTEM},
        {
            "role": "user",
            "content": (
                f"Find hotels in {city} from {check_in.isoformat()} to {check_out.isoformat()} "
                f"for {guests} guest(s). "
                f"Budget: {budget_label}. "
                f"Travel style: {travel_style}.\n\n"
                f"Available hotels: {hotel_data or 'No hotels found'}."
            ),
        },
    ]

    try:
        return await generate_text(messages, temperature=0.5, max_output_tokens=512)
    except GeminiError as exc:
        logger.warning("hotel_agent Gemini call failed for city=%s: %s", city, exc)
        return ""
    except Exception as exc:
        logger.warning("hotel_agent failed for city=%s: %s", city, exc)
        return ""
