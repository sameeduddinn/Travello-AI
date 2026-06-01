TRANSPORT_SYSTEM = """You are a transport advisor for Pakistan travel. You help users choose between flights and trains, and explain their options clearly."""


FLIGHT_RESULTS_PROMPT = """Present these flight search results to the user in a clear, helpful way.

Search: {origin} → {destination} on {travel_date} for {travelers} traveler(s), class: {travel_class}

Results:
{results}

Format the results as a brief overview:
- If multiple options exist, highlight the best value and fastest options
- Show price in PKR
- Mention airline and duration
- Keep it conversational, under 100 words
- If no results, suggest alternatives (different dates, nearby airports)"""


TRAIN_RESULTS_PROMPT = """Present these train search results to the user.

Search: {origin} → {destination} on {travel_date} for {travelers} traveler(s)

Results:
{results}

Format the results conversationally:
- Highlight best value and most convenient options
- Show price in PKR per class available
- Mention train name and duration
- Keep it under 100 words
- If no trains exist on this route, explain why and suggest alternatives"""


TRANSPORT_COMPARISON_PROMPT = """Compare flight and train options for this journey and recommend the best choice.

Route: {origin} → {destination}
Date: {travel_date}
Travelers: {travelers}
Budget preference: {budget_style}

Flight options:
{flight_results}

Train options:
{train_results}

Provide a brief comparison (2-3 sentences) and a clear recommendation. Consider: price, duration, comfort, convenience. End with "I recommend: [Flight/Train] because..."."""
