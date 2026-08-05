from __future__ import annotations

VISA_BASICS = (
    "Visa basics for foreign travelers entering Pakistan: Pakistan operates an "
    "online e-visa system for most nationalities — apply before travel via the "
    "official Pakistan government e-visa portal. Visa-on-arrival exists at select "
    "airports (Islamabad, Karachi, Lahore) for some nationalities, typically tied "
    "to an approved tour group or prior approval. Exact requirements vary by "
    "nationality and change over time — always tell the user to confirm current "
    "requirements on the official e-visa portal or the nearest Pakistani embassy/"
    "consulate before booking travel. Never state a specific country's exact "
    "requirement as fixed or guaranteed."
)

BAGGAGE_ALLOWANCE = (
    "Domestic airline baggage allowance (Pakistan International Airlines, "
    "Airblue, AirSial — the carriers this app searches): Economy is typically "
    "20kg checked baggage + 7kg cabin bag. Business class (where offered) is "
    "typically 30-40kg checked + 7kg cabin. Overweight baggage is charged per-kg "
    "at the airline's counter rate, which varies by airline/route/fare and isn't "
    "something to quote precisely. Always tell the user to confirm exact "
    "allowance with the airline at booking, since promotional fares sometimes "
    "carry reduced allowance."
)

RAILWAY_CLASSES = (
    "Pakistan Railways class names (matches what search_trains actually "
    "returns): Economy (EC) — standard seating, cheapest. AC Standard (AC) — "
    "air-conditioned seating. AC Business (ACB) — air-conditioned, more "
    "spacious. Sleeper (SL) — berths for overnight journeys. Parlour Car (PAR) "
    "— premium daytime seating. Standard Bus / AC Bus (BUS-STD / BUS-AC) — "
    "rail-affiliated bus service on routes without a direct train. Not every "
    "class runs on every route — always rely on the actual search_trains "
    "result for what's available on a specific train; this only defines what "
    "the class names mean."
)

EMERGENCY_NUMBERS = (
    "Pakistan nationwide emergency numbers: Police 15. Rescue (ambulance/fire, "
    "Punjab/KP and other provinces) 1122. Edhi Foundation Ambulance 115. "
    "Motorway Police 130."
)

# Real nearest-hub facts for the four northern destinations this app plans
# multi-modal trips to. Skardu already has its own airport (no substitution);
# the other three need a hub flight/train leg plus Car for the final stretch.
NORTHERN_HUB_FACTS: dict[str, str] = {
    "Naran": (
        "Naran/Kaghan has no airport or railway station. Nearest real hub: "
        "Islamabad (flight) or Rawalpindi (train), then ~190km / 6-7 hours by "
        "road. Use Car for that road leg — real route fare, not the flat "
        "in-city rate."
    ),
    "Hunza": (
        "Hunza (Karimabad/Aliabad) has no airport or railway station. Nearest "
        "real hub: Gilgit (flight), then ~100km / 2.5-3 hours by road. Use Car "
        "for that road leg — real route fare, not the flat in-city rate."
    ),
    "Swat": (
        "Swat/Mingora has no airport or railway station. Nearest real hub: "
        "Islamabad (flight) or Rawalpindi (train), then ~160km / 4-5 hours by "
        "road. Use Car for that road leg — real route fare, not the flat "
        "in-city rate."
    ),
    "Skardu": (
        "Skardu already has its own real airport — search flights directly "
        "there, no hub substitution needed. Only the ordinary airport-to-hotel "
        "Car transfer applies."
    ),
}
_NORTHERN_KEYWORDS: dict[str, tuple[str, ...]] = {
    "Naran": ("naran", "kaghan"),
    "Hunza": ("hunza", "karimabad", "aliabad"),
    "Swat": ("swat", "mingora"),
    "Skardu": ("skardu", "skardo"),
}

# Keyword triggers — deliberately include natural phrasings a real user would
# type ("do i need a visa", "how much luggage can i bring", "what's AC Standard"),
# not just the literal category word, so the match isn't overly literal.
_VISA_KEYWORDS = (
    "visa", "e-visa", "evisa", "entry requirement", "entry permit",
    "need a visa", "visa on arrival", "visa-on-arrival",
)
_BAGGAGE_KEYWORDS = (
    "baggage", "luggage", "checked bag", "cabin bag", "carry-on", "carry on",
    "how much can i bring", "how much can i pack", "how much weight",
    "how much luggage",
)
_TRAIN_CLASS_KEYWORDS = (
    "train class", "ac standard", "ac business", "parlour", "parlor",
    "sleeper class", "which class", "what class", "what's ac", "whats ac",
    "difference between economy and", "economy class train",
)
_HEALTHCARE_KEYWORDS = (
    "hospital", "clinic", "pharmacy", "emergency", "ambulance", "doctor",
    "nearest medical", "medical help", "urgent care", "not feeling well",
    "feel sick", "feel dizzy", "injured", "injury",
)


def get_relevant_facts(user_message: str, destination: str = "") -> str:
    """
    Return the concatenation of any curated fact blocks relevant to this
    message, or '' if none match. Cheap keyword match — deliberately covers
    common natural phrasings, not just the literal category word, so it
    doesn't miss the way people actually ask.

    `destination` (from the already-derived TripState) is checked against the
    northern-hub facts too, so the fact survives even when the current turn's
    own text doesn't re-mention the city — e.g. a follow-up "what about the
    car?" after Naran was named a few turns earlier.
    """
    msg = (user_message or "").lower()
    dest = (destination or "").lower()
    blocks: list[str] = []
    if any(k in msg for k in _VISA_KEYWORDS):
        blocks.append(VISA_BASICS)
    if any(k in msg for k in _BAGGAGE_KEYWORDS):
        blocks.append(BAGGAGE_ALLOWANCE)
    if any(k in msg for k in _TRAIN_CLASS_KEYWORDS):
        blocks.append(RAILWAY_CLASSES)
    if any(k in msg for k in _HEALTHCARE_KEYWORDS):
        blocks.append(EMERGENCY_NUMBERS)
    for name, keywords in _NORTHERN_KEYWORDS.items():
        if any(k in msg for k in keywords) or (dest and any(k in dest for k in keywords)):
            blocks.append(NORTHERN_HUB_FACTS[name])
    return "\n\n".join(blocks)
