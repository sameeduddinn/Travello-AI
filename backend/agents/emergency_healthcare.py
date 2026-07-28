from __future__ import annotations
# =============================================================================
# PURPOSE: Deterministic emergency / healthcare responder.
#
# A medical emergency must NEVER depend on the LLM chain (Groq -> OpenRouter ->
# Gemini) being up. When every provider is rate-limited or the turn clock runs
# out, the agentic loop degrades a query like "emergency, nearest hospital in
# Skardu" to "try again in a minute" — the single worst reply when someone is
# hurt. Everything needed to answer such a query is already deterministic:
#   - _CITY_COORDS      : city name -> lat/lng (no geocoding call)
#   - _MOCK_HOSPITALS   : curated, city-tagged facilities with real phone numbers
#   - _mock_nearby       : pure haversine ranking, no network
#   - EMERGENCY_NUMBERS : the curated national numbers (Rescue 1122 / Edhi 115)
#
# So this module answers straight from that data — instant, offline, and immune
# to the quota wall. By construction it can NEVER invent a facility or phone
# number (a wrong medical number is dangerous), which also satisfies the
# healthcare-safety rules baked into the prompts.
# =============================================================================

import re

from routers.healthcare import (
    _CITY_COORDS,
    _MOCK_HOSPITALS,
    _MOCK_PHARMACIES,
    _mock_nearby,
)
from prompts.knowledge import EMERGENCY_NUMBERS  # noqa: F401  (kept for parity/callers)


# --- Intent detection --------------------------------------------------------
# Two branches, deliberately conservative so this never hijacks a booking turn:
#   1. an emergency SIGNAL ("emergency", "severe", "asap") next to a MEDICAL word
#      ("injury", "hospital", "bleeding"), or
#   2. a LOCATION request ("nearest", "closest") next to a FACILITY word
#      ("hospital", "clinic", "pharmacy").
# "urgent flight" (signal, no medical word) and "nearest hotel" (location, no
# facility word) both fall through — exactly what we want.

_EMERGENCY_RE = re.compile(
    r"\b(emergenc(?:y|ies)|urgent(?:ly)?|asap|severe(?:ly)?|critical(?:ly)?|"
    r"serious(?:ly)?|immediately|life[\s-]?threatening|dying)\b",
    re.IGNORECASE,
)
_MEDICAL_RE = re.compile(
    r"\b(hospitals?|clinics?|pharmac(?:y|ies)|chemist|doctors?|medical|ambulance|"
    r"injur(?:y|ed|ies)|wound(?:ed|s)?|bleeding|fractur(?:e|ed|es)|unconscious|"
    r"collapsed|heart\s+attack|stroke|first\s+aid|snake\s*bite)\b",
    re.IGNORECASE,
)
_LOCATION_RE = re.compile(
    r"\b(nearest|closest|nearby|near\s*by|near\s+me|around\s+me|close\s+by)\b",
    re.IGNORECASE,
)
_FACILITY_RE = re.compile(
    r"\b(hospitals?|clinics?|pharmac(?:y|ies)|chemist|doctors?|"
    r"medical\s+(?:help|centre|center|facility)|emergency\s+room)\b",
    re.IGNORECASE,
)

# Longest names first so "dera ghazi khan" wins over a bare "khan"-style partial.
_CITY_KEYS = sorted(_CITY_COORDS.keys(), key=len, reverse=True)


def has_emergency_signal(message: str) -> bool:
    """True when the wording carries genuine urgency (drives the 🚨 lead line)."""
    return bool(_EMERGENCY_RE.search(message or ""))


def is_medical_emergency(message: str) -> bool:
    """
    True when the message clearly asks for the nearest hospital/clinic or signals
    a medical emergency — the trigger for the deterministic fast-path that bypasses
    the LLM entirely. Deliberately strict (needs a medical/facility word) so a
    booking turn ("urgent flight", "nearest hotel") never lands here.
    """
    m = message or ""
    if _EMERGENCY_RE.search(m) and _MEDICAL_RE.search(m):
        return True
    if _LOCATION_RE.search(m) and _FACILITY_RE.search(m):
        return True
    return False


def looks_like_healthcare(message: str) -> bool:
    """
    Loose gate for the failure-path fallback: any hospital/clinic/pharmacy/doctor/
    injury mention. Used ONLY after the LLM chain already failed, so a slightly
    generous match ("best hospital in Lahore?") just means the user gets real
    facilities + emergency numbers instead of a dead "try again".
    """
    return bool(_MEDICAL_RE.search(message or ""))


# --- City extraction (deterministic, no geocoding) ---------------------------

def _extract_city(message: str, history_texts: list[str] | None = None) -> str | None:
    """
    Find a supported city in the current message; if none, scan earlier user
    turns (most recent first) so a follow-up like "it's an emergency, nearest
    clinic" still resolves the city named a turn ago. Word-boundary matched so a
    city name embedded in another word can't false-match.
    """
    texts = [message or ""]
    if history_texts:
        texts.extend(t or "" for t in reversed(history_texts))
    for text in texts:
        low = text.lower()
        for city in _CITY_KEYS:
            if re.search(rf"\b{re.escape(city)}\b", low):
                return city
    return None


# --- Formatting --------------------------------------------------------------

def _facility_line(f: dict) -> str:
    name = f.get("name", "Facility")
    line = name
    if f.get("address"):
        line += f" — {f['address']}"
    extras = []
    if f.get("phone"):
        extras.append(f"📞 {f['phone']}")
    if f.get("distance_km") is not None:
        extras.append(f"~{f['distance_km']} km")
    if extras:
        line += f" ({', '.join(extras)})"
    return line


_NUMBERS_LINE = (
    "Nationwide emergency numbers — Police 15 · Rescue/ambulance 1122 · "
    "Edhi Ambulance 115 · Motorway Police 130."
)


def build_emergency_reply(
    message: str,
    history_texts: list[str] | None = None,
    *,
    urgent: bool = True,
) -> str:
    """
    Build the user-facing emergency answer entirely from curated data. Always
    returns usable text: with a resolved city it lists the nearest hospitals
    (and a pharmacy) with real phone numbers and true distances; without one it
    still gives the national emergency numbers and asks for the city.
    """
    lead = (
        "🚨 If this is life-threatening, get an ambulance now — call Rescue 1122 "
        "or Edhi Ambulance 115."
        if urgent else
        "If it's urgent, call Rescue 1122 or Edhi Ambulance 115."
    )

    city_key = _extract_city(message, history_texts)
    if not city_key:
        return (
            f"{lead}\n\n{_NUMBERS_LINE}\n\n"
            "Tell me which city or town you're in and I'll list the nearest "
            "hospitals with their phone numbers."
        )

    lat, lng = _CITY_COORDS[city_key]
    hospitals = _mock_nearby(lat, lng, 15.0, _MOCK_HOSPITALS)[:3]
    pharmacies = _mock_nearby(lat, lng, 5.0, _MOCK_PHARMACIES)[:1]
    city_title = city_key.title()

    parts: list[str] = [lead, ""]
    if hospitals:
        parts.append(f"Nearest hospitals in {city_title}:")
        parts.extend(f"• {_facility_line(h)}" for h in hospitals)
    else:
        parts.append(
            f"I don't have specific facilities listed for {city_title}, so please "
            "use the emergency numbers below."
        )
    if pharmacies:
        parts.append("")
        parts.append("Pharmacy nearby:")
        parts.extend(f"• {_facility_line(p)}" for p in pharmacies)
    parts.extend(["", _NUMBERS_LINE, ""])
    parts.append(
        "Call ahead if you can so they're ready for you. Tell me a specific area "
        "and I'll point you to the closest option."
    )
    return "\n".join(parts)
