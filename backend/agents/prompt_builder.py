from __future__ import annotations
# PURPOSE: Decide what actually goes into a tool-calling request.
#
#   select_tools()        — which tool schemas this turn could plausibly need
#   build_system_prompt() — the compact core prompt plus only the rule blocks
#                           that apply to this turn
#   estimate_fixed_tokens()— what that combination costs, for logging


import re

from services.llm_service import estimate_request_tokens
from agents.agent_tools import TOOL_SCHEMAS, TOOL_SCHEMAS_BY_NAME
from prompts.master_agent import (
    MASTER_AGENTIC_CORE,
    AGENTIC_BOOKING_BLOCK,
    AGENTIC_CAR_BLOCK,
)

# Sent when the message matched NOTHING — the unknown-request case, which is
# most of what real users type. This is the safety net, so it has to hold
# everything the agent might need to serve a request we failed to recognise.
#
# The regexes above catch what they were written for, and travellers write in
# Roman Urdu, English and a mix: "mausam kaisa hai" matches, "mujhe Lahore jana
# hai" does not. That second one lands here and is served fine. But "gari
# chahiye airport se" also landed here and was NOT served, because book_car
# wasn't in this list — the agent was asked for a car and handed no way to
# arrange one. find_healthcare had the same hole, and it is the one tool where
# failing to serve a request can actually matter.
#
# Both are cheap (285 and 75 tokens). prepare_booking stays out at 793 tokens:
# it is the most expensive schema by far, it is meaningless before a search has
# produced something to book, and it is selected explicitly on a pick.
_DEFAULT_TOOLS = (
    "search_flights", "search_trains", "search_hotels", "get_weather",
    "find_healthcare", "book_car",
)

# NOTE: "airport" is deliberately NOT here. A car ride "to the airport" is the
# commonest standalone-car request in this app, and treating it as a flight
# signal dragged the flight schema (and the whole booking block) into every one.
# Pure small talk with nothing else in it — matched against the WHOLE message,
# not a keyword inside it, so "hi, book me a flight to lahore" is untouched.
# Gated on there being no history at all (see select_tool_names): a greeting
# mid-conversation ("thanks!") is a real turn that still needs whatever tool
# the conversation was already using, and this must never strand it.
#
# Deliberately a small closed list. A false NEGATIVE (a greeting not matched)
# costs nothing — it falls through to the ordinary fallback tools, unused but
# harmless. A false POSITIVE (a real request matched as a greeting) costs a
# whole extra turn: no tools, the agent has to ask, the user answers, and only
# then does a real search happen. That asymmetry is why this stays narrow
# rather than trying to catch every possible greeting.
_PURE_GREETING_RE = re.compile(
    r"^\s*(?:"
    r"hi|hello|hey|hiya|yo|"
    r"salam|assalam(?:u|o)?\s*[o0]?\s*alaikum|as-?salamu?\s*alaikum|"
    r"good\s?(?:morning|afternoon|evening|night)|"
    r"how\s+are\s+you|what'?s\s+up|kaise\s+ho|kya\s+haal\s+hai|"
    r"who\s+are\s+you|what\s+can\s+you\s+do|what\s+do\s+you\s+do|"
    r"thanks?|thank\s+you|shukriya|"
    r"ok|okay|k|great|cool|nice|good|awesome"
    r")\s*[.!?]*\s*$",
    re.I,
)


def _is_pure_greeting(message: str, history: list[dict] | None) -> bool:
    """True only for small talk with no travel content, as the FIRST turn."""
    if history:
        return False
    return bool(_PURE_GREETING_RE.match(message or ""))


_FLIGHT_RE = re.compile(
    r"\b(flight|flights|fly|flying|flew|plane|air\s?line|airline|"
    r"pia|airblue|air\s?sial|serene|jazeera|boarding|one\s?way|round\s?trip|"
    r"return\s+flight|air\s?ticket)\b", re.I)
_TRAIN_RE = re.compile(
    r"\b(train|trains|rail|railway|railways|tezgam|khyber|green\s?line|"
    r"business\s?express|awam|jaffar|bogie|berth|coach)\b", re.I)
_HOTEL_RE = re.compile(
    r"\b(hotel|hotels|room|rooms|stay|staying|accommodation|lodging|lodge|"
    r"guest\s?house|resort|check\s?in|check\s?out|night|nights)\b", re.I)
_WEATHER_RE = re.compile(
    r"\b(weather|temperature|temp|forecast|rain|raining|snow|hot|cold|humid|"
    r"sunny|cloudy|storm|mausam|garmi|sardi|what\s+to\s+pack|packing)\b", re.I)
_HEALTH_RE = re.compile(
    r"\b(hospital|hospitals|clinic|clinics|pharmacy|pharmacies|chemist|doctor|"
    r"medical|medicine|emergency|ambulance|sick|ill|injur|hurt|pain|fever|"
    r"first\s?aid|health)\b", re.I)
_CAR_RE = re.compile(
    r"\b(car|cars|driver|ride|taxi|cab|rickshaw|vehicle|sedan|suv|van|"
    r"pick\s?up|pickup|drop\s?off|dropoff|transfer)\b", re.I)
# An explicit request for a car AS THE BOOKING, which is what book_car is for.
# "yes add a car transfer" mentions a car but means the transfer FIELD on
# prepare_booking — sending book_car for it offers the model a way to split one
# checkout into two bookings, which is exactly what the package rules forbid.
_STANDALONE_CAR_RE = re.compile(
    r"\b(?:book|need|want|get|arrange|hire|order|send)\b[^.?!]{0,20}?"
    r"\b(car|cab|taxi|ride|driver|sedan|suv|van)\b"
    r"|\bcar\s+(?:booking|tab)\b", re.I)
# A trip that spans days needs several tools at once.
_PLANNING_RE = re.compile(
    r"\b(plan|planning|itinerary|tour|holiday|vacation|package|honeymoon|"
    r"weekend|getaway)\b|\btrip\b", re.I)
# A duration on its own ("3 nights", "4 days") only means trip planning when the
# message hasn't already named a mode — "a hotel for 3 nights" is a hotel search,
# and expanding it to flights + trains + weather was pure wasted payload.
_DURATION_RE = re.compile(r"\b\d+\s*(?:day|days|night|nights)\b", re.I)

# The user is asking to commit to something already shown.
_BOOKING_INTENT_RE = re.compile(
    r"\b(book|booking|reserve|reservation|confirm|proceed|purchase|buy|pay|"
    r"payment|checkout|take\s+(?:the|option)|go\s+with|i'?ll\s+take|select|"
    r"choose|finalis|finaliz)\b", re.I)
# Words that name a CONCRETE option rather than a category — a flight number
# ("PA401", "PK-304"), a named train, or a superlative that resolves against a
# list. "Book a flight to Karachi" is a request to SEE options; "book PA401" is
# a commitment, and only the latter needs the prepare_booking schema.
_CONCRETE_OPTION_RE = re.compile(
    r"\b(tezgam|khyber\s?mail|green\s?line|business\s?express|awam\s?express|"
    r"jaffar\s?express|pakistan\s?express|karakoram)\b"
    r"|\bthe\s+(cheapest|earliest|latest|first|last|second|third|morning|evening)\b",
    re.I)
# A flight/train code — CASE SENSITIVE on purpose. Matched case-insensitively,
# "PA401" and the "to 25" of "15 aug to 25 aug" are the same pattern, and every
# date range was read as naming a specific flight.
_FLIGHT_CODE_RE = re.compile(r"\b[A-Z]{2}\s?-?\d{2,4}\b")


def _names_concrete_option(message: str) -> bool:
    return bool(_CONCRETE_OPTION_RE.search(message) or _FLIGHT_CODE_RE.search(message))
# A bare pick answering a numbered list: "2", "option 3", "1 and 2", "the second one".
_PICK_RE = re.compile(
    r"^\s*(?:option|number|no\.?|#|item)?\s*\d{1,2}\s*[.!)]?\s*$"
    r"|\b(?:option|flight|train|hotel|choice|number)\s*#?\s*\d{1,2}\b"
    r"|\b(first|second|third|fourth|fifth)\s+(one|option|flight|train|hotel)\b",
    re.I)
# A numbered list in an assistant turn = offers are on the table, so the very next
# message may be a pick even if it looks like nothing ("2", "the cheapest").
_OFFER_LIST_RE = re.compile(r"^\s*\|?\s*\d{1,2}\s*[.)\-:|]\s*\S", re.M)
# A numbered SHAPE isn't enough on its own — the assistant's own clarifying
# questions are numbered too ("1. Outbound date... 2. Return date..."), and
# _OFFER_LIST_RE alone can't tell that apart from a real numbered list of
# flights/trains/hotels. A genuine offer always carries a real price
# somewhere in the message; a numbered QUESTION does not. Same shape of fix as
# master_agent.py's _looks_like_offers/_PRICE_IN_LABEL_RE, applied here too —
# that one guards the atomic-package/already-booked checks, this one guards
# which tool schemas ship. Deliberately checked against the WHOLE message, not
# the matched line itself: a train listing puts the number+name on one line
# and each class's price on an indented line below it, which must still count.
#
# Adversarial review (see the currency-notation cases below) found this was
# originally too narrow: it required the literal string "PKR", which is what
# the deterministic renderer always uses, but a free-form LLM reply (the
# budget/planning/package turns this whole gate exists for) may write "Rs."
# or the Rupee sign instead — both plausible, neither previously covered — and
# that regression would have silently dropped prepare_booking on a real offer
# list, exactly the opposite failure from the one this file was built to fix.
# "Rs" alone is short enough to risk false hits, so it stays \b-anchored and
# digit-adjacent — verified clear of "8 hrs", "Mrs. Khan", "2 yrs", "ERS204".
#
# Two currency-notation gaps were found and NOT closed here, on purpose: a
# message that states the currency once in an intro and gives bare numbers
# after, and one with no currency marker anywhere. Closing those with a bare
# "any 4+ digit number" fallback was tested and rejected — it flags a
# clarifying question list as an offer the moment a date in it has a 4-digit
# year ("25 August 2026"), reopening the exact bug this file exists to fix.
_PRICE_IN_LABEL_RE = re.compile(
    r"\b(?:PKR|Rs\.?|Rupees?)\s*[\d,]+|₨\s*[\d,]+", re.IGNORECASE
)

# Tool ids we can detect in an earlier assistant/tool turn, to carry forward.
_CARRY_FORWARD_LOOKBACK = 6

# The app's own confirmation milestone — written back into the conversation by
# the Flutter client after payment succeeds. Same marker the already-paid gate
# in agent_tools keys off.
_CONFIRMED_RE = re.compile(r"(?:booking|package)\s+confirmed|\*\*PNR:\*\*", re.I)


def _looks_like_offer_list(text: str) -> bool:
    """A numbered list of PRICED options — not just any numbered list."""
    text = text or ""
    return bool(_OFFER_LIST_RE.search(text)) and bool(_PRICE_IN_LABEL_RE.search(text))


def _recent_assistant_offers(history: list[dict] | None) -> bool:
    """
    Is there still a numbered list of options the user could be replying to?

    A confirmation retires the list it came from. Those options were picked,
    summarised, paid for and given a PNR — they are not on the table any more,
    they are a booking. Treating them as live is what made "now i want driver
    at lahore airport" ship prepare_booking (and suppress the standalone-car
    rule that would have removed it), so the model re-proposed the flight the
    traveller had just paid for, with the car added on top.
    """
    for m in reversed(list(history or [])[-_CARRY_FORWARD_LOOKBACK:]):
        if (m.get("role") or "").lower() != "assistant":
            continue
        text = m.get("content") or ""
        if _CONFIRMED_RE.search(text):
            return False
        if _looks_like_offer_list(text):
            return True
    return False


def _signals(text: str) -> set[str]:
    """Tool names a single piece of text argues for."""
    found: set[str] = set()
    if _FLIGHT_RE.search(text):
        found.add("search_flights")
    if _TRAIN_RE.search(text):
        found.add("search_trains")
    if _HOTEL_RE.search(text):
        found.add("search_hotels")
    if _WEATHER_RE.search(text):
        found.add("get_weather")
    if _HEALTH_RE.search(text):
        found.add("find_healthcare")
    if _CAR_RE.search(text):
        found.add("book_car")
    if _PLANNING_RE.search(text) or (_DURATION_RE.search(text) and not found):
        # A multi-day trip is transport + stay + weather, whatever words were used.
        found.update(("search_flights", "search_trains", "search_hotels", "get_weather"))
    return found


def select_tool_names(
    user_message: str,
    history: list[dict] | None = None,
) -> list[str]:
    """
    The tool ids worth sending this turn, in a stable order.

    Carries forward whatever the recent conversation was already about, so a
    follow-up ("and a hotel too", "what about the 3pm one") never loses access to
    the tool the previous turn used.
    """
    message = user_message if isinstance(user_message, str) else ""

    # Pure small talk as the very first turn needs no tool at all — there is no
    # trip in progress yet for the agent to be tool-less FOR. See
    # _is_pure_greeting for why this is a narrow, whole-message match gated on
    # empty history rather than a keyword scan.
    if _is_pure_greeting(message, history):
        return []

    chosen = _signals(message)

    # Recent context — the last few turns of what was actually discussed.
    recent = list(history or [])[-_CARRY_FORWARD_LOOKBACK:]
    for m in recent:
        chosen |= _signals(m.get("content") or "")

    offers_on_table = _recent_assistant_offers(history)

    # prepare_booking is by far the most expensive schema, so it ships only when
    # the turn could actually COMMIT to something:
    #   - the user picked a list item ("2", "option 3", "1 and 2");
    #   - they named a concrete option ("book PA401", "take the cheapest");
    #   - offers are on the table and they answered briefly.
    # "Book me a flight to Karachi" with nothing shown yet is deliberately NOT
    # enough — by the assistant's own rules that is a request to SEE options, and
    # a booking with no prior offer would fail the provenance gate anyway.
    booking_intent = bool(_BOOKING_INTENT_RE.search(message))
    if (
        _PICK_RE.search(message)
        or (booking_intent and (offers_on_table or _names_concrete_option(message)))
        or (offers_on_table and len(message.strip()) <= 80)
    ):
        chosen.add("prepare_booking")
        # A booking turn still needs the search tool that produced the offer, so
        # repricing/re-searching stays possible.
        if not chosen & {"search_flights", "search_trains", "search_hotels"}:
            chosen.update(("search_flights", "search_trains", "search_hotels"))

    # A car mention inside a booking conversation is the airport TRANSFER — a
    # field on prepare_booking — not a standalone ride. Offering book_car there
    # hands the model a way to split one checkout into two bookings, which the
    # package rules explicitly forbid.
    if "book_car" in chosen and "prepare_booking" in chosen and not _STANDALONE_CAR_RE.search(message):
        chosen.discard("book_car")
    # Conversely, a clear standalone-car request ("book a sedan from A to B") has
    # no flight/train/hotel to commit to, so the booking and search schemas are
    # dead weight.
    if (
        "book_car" in chosen
        and _STANDALONE_CAR_RE.search(message)
        and not (_FLIGHT_RE.search(message) or _TRAIN_RE.search(message) or _HOTEL_RE.search(message))
        and not _PICK_RE.search(message)
        and not offers_on_table
    ):
        chosen.discard("prepare_booking")
        chosen -= {"search_flights", "search_trains", "search_hotels", "get_weather"}

    if not chosen:
        chosen = set(_DEFAULT_TOOLS)

    # Preserve TOOL_SCHEMAS order so the payload is byte-stable turn to turn,
    # which keeps provider-side prompt caching effective.
    return [t["function"]["name"] for t in TOOL_SCHEMAS if t["function"]["name"] in chosen]


def select_tools(
    user_message: str,
    history: list[dict] | None = None,
) -> list[dict]:
    """The tool SCHEMAS for this turn. See select_tool_names."""
    names = select_tool_names(user_message, history)
    return [TOOL_SCHEMAS_BY_NAME[n] for n in names if n in TOOL_SCHEMAS_BY_NAME]


def build_system_prompt(
    *,
    today: str,
    weekday: str,
    memory: str,
    tool_names: list[str] | None = None,
) -> str:
    """
    The compact core prompt plus only the rule blocks this turn can use.

    Keyed off the SELECTED TOOLS rather than re-reading the message, so the rules
    and the tools can never disagree — the model is never told how to book while
    holding no booking tool, and never handed prepare_booking without its rules.
    """
    prompt = MASTER_AGENTIC_CORE.format(
        today=today, weekday=weekday, memory=memory or "(no saved preferences yet)"
    )
    # `is None` and not `or`: an EMPTY list means "this turn needs no tools",
    # and `tool_names or [...]` treated that as "send every tool" — the exact
    # opposite — because an empty list is falsy. It made a no-tool prompt
    # measure LARGER (3,047 tokens) than a four-tool one (2,824), since both
    # rule blocks came along with the tools nobody asked for.
    if tool_names is None:
        tool_names = [n["function"]["name"] for n in TOOL_SCHEMAS]
    names = set(tool_names)
    if "prepare_booking" in names:
        prompt += AGENTIC_BOOKING_BLOCK
    if "book_car" in names:
        prompt += AGENTIC_CAR_BLOCK
    return prompt


def estimate_fixed_tokens(system_prompt: str, tools: list[dict] | None) -> int:
    """
    Token cost of the parts of a request that don't vary with history.

    Delegates to the one estimator in llm_service so a size reported here and a
    size logged at call time can never disagree.
    """
    return estimate_request_tokens(
        [{"role": "system", "content": system_prompt or ""}], tools)
