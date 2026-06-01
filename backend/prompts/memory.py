MEMORY_SYSTEM = """You are a memory manager for a travel assistant. Your job is to extract and summarize key information from conversations to build user travel preferences."""


PREFERENCE_EXTRACTION_PROMPT = """Analyze this conversation and extract the user's travel preferences and patterns.

Conversation:
{conversation}

Current saved preferences:
{existing_preferences}

Extract and return a JSON object with updated preferences (merge with existing, don't overwrite unless the user explicitly changed something):
{{
  "origin_city": "user's home city or most frequent departure city",
  "preferred_class": "Economy | Business | First",
  "travel_style": "budget | standard | luxury",
  "companion_type": "solo | couple | family | group",
  "budget_style": "budget | standard | premium",
  "past_destinations": ["list of cities the user has searched or visited"],
  "preferred_transport": "flight | train | any",
  "language_preference": "english | urdu | mixed"
}}

Only include fields where you have reasonable confidence. Return null for unknown fields."""


CONVERSATION_SUMMARY_PROMPT = """Summarize this travel conversation in 2-3 sentences, capturing:
- What the user was looking for
- Key details (destinations, dates, budget if mentioned)
- Outcome (did they find what they needed? did they book?)

Conversation:
{conversation}

Return plain text summary only (no JSON, no bullet points)."""


CONTEXT_INJECTION_PROMPT = """The user is asking a new question. Here is relevant context from their previous conversations and preferences:

Previous preferences: {preferences}
Recent conversation history: {recent_history}

Use this context to better understand what the user likely wants, but do NOT mention that you have this memory unless they ask."""
