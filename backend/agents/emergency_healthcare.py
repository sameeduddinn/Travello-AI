from __future__ import annotations
# PURPOSE: Deterministic emergency / healthcare responder.
import re

from routers.healthcare import (
    _CITY_COORDS,
    _MOCK_HOSPITALS,
    _MOCK_PHARMACIES,
    _mock_nearby,
)

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


def _text(message: object) -> str:
    """Coerce any input to a safe string. A non-str (int, dict, None from a
    misbehaving caller) becomes "" so the regexes never raise — these gates sit on
    the safety-critical path and must degrade, not crash, on unexpected input."""
    return message if isinstance(message, str) else ""


def has_emergency_signal(message: str) -> bool:
    """True when the wording carries genuine urgency (drives the 🚨 lead line)."""
    return bool(_EMERGENCY_RE.search(_text(message)))


def is_medical_emergency(message: str) -> bool:
    """
    True when the message clearly asks for the nearest hospital/clinic or signals
    a medical emergency — the trigger for the deterministic fast-path that bypasses
    the LLM entirely. Deliberately strict (needs a medical/facility word) so a
    booking turn ("urgent flight", "nearest hotel") never lands here.
    """
    m = _text(message)
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
    return bool(_MEDICAL_RE.search(_text(message)))


# --- City extraction (deterministic, no geocoding) ---------------------------

def _extract_city(message: str, history_texts: list[str] | None = None) -> str | None:
    """
    Find a supported city in the current message; if none, scan earlier user
    turns (most recent first) so a follow-up like "it's an emergency, nearest
    clinic" still resolves the city named a turn ago. Word-boundary matched so a
    city name embedded in another word can't false-match.
    """
    texts = [_text(message)]
    if history_texts:
        texts.extend(_text(t) for t in reversed(history_texts))
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
    device_lat: float | None = None,
    device_lng: float | None = None,
    prefer_device: bool = False,
) -> str:
    """
    Build the user-facing emergency answer entirely from curated data. Always
    returns usable text: from the user's live GPS (a "near me" query) or a named
    city it lists the nearest hospitals (and a pharmacy) with real phone numbers
    and true distances; with neither it still gives the national emergency numbers
    and asks for the city. Stays LLM- and network-independent by design.
    """
    lead = (
        "🚨 If this is life-threatening, get an ambulance now — call Rescue 1122 "
        "or Edhi Ambulance 115."
        if urgent else
        "If it's urgent, call Rescue 1122 or Edhi Ambulance 115."
    )

    # A city named in the CURRENT message is the strongest, least-ambiguous signal.
    # If the user says "hospitals near me in Lahore" while their GPS sits in Karachi,
    # the explicit "Lahore" must win over the "near me" cue — handing Karachi
    # hospitals to someone asking about Lahore is exactly wrong in a medical context.
    # Device GPS only fills a genuine gap: a "near me" with no city, or no city at all.
    # The is-not-None checks live in the elif condition itself so the coordinates
    # narrow to plain floats inside the branch.
    current_city = _extract_city(message)
    context_city = current_city or _extract_city(message, history_texts)
    if current_city:
        lat, lng = _CITY_COORDS[current_city]
        where = f"in {current_city.title()}"
    elif (
        device_lat is not None and device_lng is not None
        and (prefer_device or not context_city)
    ):
        lat, lng = float(device_lat), float(device_lng)
        where = "near your current location"
    elif context_city:
        lat, lng = _CITY_COORDS[context_city]
        where = f"in {context_city.title()}"
    else:
        return (
            f"{lead}\n\n{_NUMBERS_LINE}\n\n"
            "Tell me which city or town you're in and I'll list the nearest "
            "hospitals with their phone numbers."
        )

    hospitals = _mock_nearby(lat, lng, 15.0, _MOCK_HOSPITALS)[:3]
    pharmacies = _mock_nearby(lat, lng, 5.0, _MOCK_PHARMACIES)[:1]

    parts: list[str] = [lead, ""]
    if hospitals:
        parts.append(f"Nearest hospitals {where}:")
        parts.extend(f"• {_facility_line(h)}" for h in hospitals)
    else:
        parts.append(
            f"I don't have specific facilities listed {where}, so please "
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
