RECOMMENDATION_SYSTEM = """You are a Pakistan travel recommendation expert. You give personalized suggestions based on user preferences, season, and budget.

You know Pakistan's travel seasons:
- Oct–Mar: Best for plains (Lahore, Karachi, Multan, Islamabad) — cool and pleasant
- Apr–Jun: Good for northern areas before summer heat below; northern areas open up
- Jul–Sep: Monsoon in plains, lush northern areas but some road closures
- Nov–Feb: Cold in north (some areas closed), perfect for Karachi beach trips"""


DESTINATION_RECOMMENDATION_PROMPT = """Recommend travel destinations in Pakistan based on the user's profile.

User preferences:
- Budget style: {budget_style}
- Companion type: {companion_type}
- Travel style: {travel_style}
- Past destinations: {past_destinations}
- Current month: {current_month}
- Origin city: {origin_city}
- Interests: {interests}

Return JSON with 3 destination recommendations:
{{
  "recommendations": [
    {{
      "destination": "city/region name",
      "tagline": "one compelling sentence",
      "why_now": "why this is good for the current month",
      "best_for": "who this suits (couples, families, adventure seekers, etc.)",
      "estimated_budget_pkr": {{
        "min": number,
        "max": number,
        "duration_days": 3
      }},
      "top_experiences": ["experience1", "experience2", "experience3"],
      "travel_from_{origin_city}": "brief transport note"
    }}
  ]
}}"""


ACTIVITY_RECOMMENDATION_PROMPT = """Suggest activities and attractions for a traveler in {destination}.

Traveler profile:
- Companion type: {companion_type}
- Travel style: {travel_style}
- Duration: {duration_days} days
- Interests: {interests}

Return a JSON list of recommended activities:
{{
  "must_do": ["activity1", "activity2"],
  "food_experiences": ["restaurant/dish1", "restaurant/dish2"],
  "hidden_gems": ["lesser-known place or experience"],
  "avoid": ["things to skip or be cautious about"],
  "best_time_to_visit": "morning/evening recommendation"
}}"""


SIMILAR_DESTINATIONS_PROMPT = """The user enjoyed or is interested in {liked_destination}. Suggest 2-3 similar destinations in Pakistan they might also enjoy.

Keep each suggestion to 1-2 sentences explaining why it's similar and what's unique about it."""
