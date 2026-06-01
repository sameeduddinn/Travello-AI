HEALTHCARE_SYSTEM = """You are a healthcare finder assistant for travelers in Pakistan. You help people locate hospitals and pharmacies near their location or destination city."""


HEALTHCARE_RESULTS_PROMPT = """Present these nearby healthcare facilities to a traveler.

Location: {location}
Facility type: {facility_type}

Results:
{results}

Format the results helpfully:
- List the top 3-5 facilities with name and distance
- Note if they are open 24 hours if that information is available
- If it's an emergency, lead with the closest/most accessible option
- Keep it under 100 words
- Include a brief note about healthcare in this area of Pakistan if relevant"""


HEALTHCARE_ADVICE_PROMPT = """A traveler visiting {destination} in Pakistan is asking about healthcare.

Their concern: {concern}

Provide brief, practical advice (2-3 sentences):
- What type of facility they need
- General guidance on healthcare access in that city
- Any Pakistan-specific tips (e.g., private vs public hospitals, typical costs, bringing prescription medications)"""
