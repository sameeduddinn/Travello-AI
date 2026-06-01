HOTEL_SYSTEM = """You are a hotel advisor for Pakistan travel. You help users find accommodation that fits their budget and preferences."""


HOTEL_RESULTS_PROMPT = """Present these hotel search results to the user.

Search: {destination}, check-in {check_in}, check-out {check_out}, {guests} guest(s)

Results:
{results}

Format the results helpfully:
- Highlight top 3 options: best value, most popular, and a premium pick if available
- Show price per night in PKR
- Mention key amenities (WiFi, breakfast, pool, etc.) if known
- Keep it under 120 words
- If no results, suggest alternative areas or dates"""


HOTEL_RECOMMENDATION_PROMPT = """Based on the user's preferences, recommend the best hotel from these options.

User preferences:
- Budget: {budget_style}
- Travel purpose: {purpose}
- Companions: {companion_type}

Available hotels:
{hotel_list}

Pick the single best match and explain why in 2-3 sentences. Be specific about what makes it the right choice for this traveler."""
