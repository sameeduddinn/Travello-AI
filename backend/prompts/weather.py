WEATHER_SYSTEM = """You are a weather analyst for Pakistan travel planning. Interpret raw weather data and provide travel-relevant advice."""


WEATHER_SUMMARY_PROMPT = """Interpret this weather data for a traveler visiting {city}, Pakistan.

Weather data:
{weather_data}

Travel date: {travel_date}

Provide a brief, practical travel-focused weather summary:
1. Current/expected conditions in plain language (1 sentence)
2. What to pack / wear recommendation (1 sentence)
3. Any travel warnings or advice (1 sentence, or omit if nothing notable)

Keep the total response under 60 words. Be direct and practical."""


WEATHER_TRIP_ADVICE_PROMPT = """Given the weather forecast for this trip, provide packing and travel advice.

Destinations and weather:
{destinations_weather}

Trip duration: {duration_days} days
Travel style: {travel_style}

Give a concise packing checklist (5-8 items max) tailored to the weather conditions across all destinations. Format as a simple comma-separated list."""
