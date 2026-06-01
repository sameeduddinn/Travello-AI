BUDGET_SYSTEM = """You are a Pakistan travel budget calculator. You provide accurate, realistic cost estimates in PKR based on current market rates."""


BUDGET_ESTIMATE_PROMPT = """Calculate a detailed travel budget for this trip.

Trip details:
- Origin: {origin}
- Destination: {destination}
- Duration: {duration_days} days
- Travelers: {travelers}
- Travel style: {budget_style}

Real data available:
- Flight/train cost: {transport_cost_pkr} PKR (total for all travelers)
- Hotel cost: {hotel_cost_pkr} PKR (total for stay)

Estimate remaining costs and return JSON:
{{
  "summary": {{
    "total_estimated_pkr": number,
    "per_person_pkr": number,
    "budget_style": "{budget_style}"
  }},
  "breakdown": {{
    "transport_pkr": {transport_cost_pkr},
    "accommodation_pkr": {hotel_cost_pkr},
    "meals_pkr": estimated total,
    "activities_pkr": estimated total,
    "local_transport_pkr": estimated total,
    "miscellaneous_pkr": estimated (10% buffer)
  }},
  "daily_allowance_per_person_pkr": number,
  "budget_tips": ["tip1", "tip2", "tip3"],
  "is_feasible": true/false,
  "feasibility_note": "comment if budget seems tight or generous"
}}

Pakistan cost reference (adjust for travel style):
Budget style meals: 500-1500 PKR/day/person
Standard style meals: 1500-3000 PKR/day/person
Luxury style meals: 3000-8000 PKR/day/person
Local rickshaw/taxi: 200-1000 PKR/trip
Entry fees major sites: 100-500 PKR/person"""


BUDGET_COMPARISON_PROMPT = """Compare these travel options by total cost and value.

Option A (Flight): {flight_option}
Option B (Train): {train_option}
Hotel options: {hotel_options}
Duration: {duration_days} days, {travelers} travelers

Give a brief cost comparison (3-4 sentences) and state which combination gives the best value for a {budget_style} traveler."""
