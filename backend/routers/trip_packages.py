from __future__ import annotations
# FILE: routers/trip_packages.py
# PURPOSE: HTTP surface for the native Trip Package UI. Both endpoints here
# are thin wrappers around the EXISTING Trip Planner engine
# (agents/trip_selection.py: build_options/build_plan/is_valid_planner_state)
# and the EXISTING deterministic booking engine
# (agents/master_agent.py: complete_trip_planner_confirmation, extracted to
# module scope for exactly this reuse). Neither composition, verification,
# repricing nor booking logic is reimplemented here — see CLAUDE.md's "one
# booking/payment engine" principle. The AI Assistant chat flow and this UI
# converge on the SAME functions from here on.
#
# SCOPE (confirmed by reading trip_selection.build_options, not assumed): the
# engine being reused only ever composes a package for the four northern
# destinations Naran/Hunza/Swat/Skardu — build_options() itself returns {}
# for anything else via `hub_options_for(destination) is None`. That is the
# actual capability of the engine, not a limitation invented here. This
# router surfaces that scope as a clear 422 rather than silently answering
# nothing for an unsupported destination.
#
# SESSION MODEL: a Trip Package "session" IS an ai_conversations row, exactly
# like a chat conversation — created via the same start_new_conversation()
# chat already uses, with its options/picks persisted via the same
# save_planner_state()/get_active_planner_state() the chat flow already uses.
# No new database structure. No LLM call anywhere in this file — every
# structured field (origin, destination, dates, party size, picks) comes
# straight from the request; only the two existing search tools and the
# existing composition/verification functions run.

import asyncio
import json
import logging
from datetime import date, timedelta
from typing import Literal

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from agents import trip_selection
from agents.master_agent import complete_trip_planner_confirmation
from agents.memory_agent import (
    get_active_planner_state,
    save_planner_state,
    start_new_conversation,
)
from agents.self_improvement import dispatch_tool_with_retry
from core.auth import CurrentUser
from core.supabase_client import supabase_admin
from services.northern_routes import NORTHERN_DESTINATIONS, canonical_destination, hub_options_for
from services.train_service import STATIONS as _TRAIN_STATIONS

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trip-packages", tags=["Trip Packages"])


def _verify_conversation_owner(conversation_id: str, user_id: str):
    return (
        supabase_admin.table("ai_conversations")
        .select("id")
        .eq("id", conversation_id)
        .eq("user_id", user_id)
        .execute()
    )


def _add_days_iso(date_str: str, days: int) -> str:
    try:
        y, m, d = (int(p) for p in date_str.split("-"))
        return (date(y, m, d) + timedelta(days=max(days, 1))).isoformat()
    except (TypeError, ValueError):
        return date_str


def _nights_between(check_in: str, check_out: str) -> int:
    try:
        y1, m1, d1 = (int(p) for p in check_in.split("-"))
        y2, m2, d2 = (int(p) for p in check_out.split("-"))
        return max((date(y2, m2, d2) - date(y1, m1, d1)).days, 1)
    except (TypeError, ValueError):
        return 2


def _hub_city_for(destination: str, mode: str) -> str | None:
    """
    The city search_flights/search_trains should actually search TO for this
    destination and mode — the real hub (e.g. Islamabad for Naran), or the
    destination itself when it already has its own airport/station (Skardu:
    hub_options_for returns [] — see that function's own docstring). None
    when this destination has no route serving the requested mode at all
    (e.g. Skardu has no railway service — confirmed via
    services.train_service.STATIONS marking it bus_only; Naran/Hunza/Swat
    all resolve their "train" mode to a real station, Rawalpindi, via the
    for-loop below, so they never reach the bus_only check).
    """
    hubs = hub_options_for(destination)
    if hubs is None:
        return None
    if not hubs:
        # "Has its own airport" (hub_options_for returning []) is not the
        # same claim as "has its own train station" — Skardu is real-world
        # rail-less, and searching search_trains for it always comes back
        # empty, which surfaced to a traveller as an unhelpful generic
        # "nothing found" 404 instead of a clear "no train route" one.
        if mode == "train" and _is_rail_less(destination):
            return None
        return destination
    for hub in hubs:
        if hub.mode == mode:
            return hub.hub_city
    return None


def _is_rail_less(city: str) -> bool:
    """True when services.train_service's own station table marks this city
    bus_only — i.e. no railway reaches it in the (real-world-accurate) mocked
    data, regardless of whether it has its own airport."""
    low = city.strip().lower()
    return any(
        info.get("bus_only") and str(info.get("city", "")).lower() == low
        for info in _TRAIN_STATIONS.values()
    )


def _tool_error_detail(result_json: str) -> str | None:
    """The model-facing error/instruction text from a tool result, if any —
    surfaced to the API caller instead of a generic 'nothing found'."""
    try:
        parsed = json.loads(result_json)
    except (TypeError, ValueError):
        return None
    if isinstance(parsed, dict) and parsed.get("error"):
        return str(parsed.get("instruction") or parsed.get("error"))
    return None


# ── Trip Requirements -> Package Options ─────────────────────────────────────

class TripRequirements(BaseModel):
    origin: str = Field(..., min_length=1, max_length=80)
    destination: str = Field(..., min_length=1, max_length=80)
    travel_date: str = Field(..., min_length=8, max_length=10)   # YYYY-MM-DD
    return_date: str | None = None
    nights: int | None = Field(None, ge=1, le=30)   # used only if return_date is absent
    travelers: int = Field(1, ge=1, le=9)
    preferred_mode: Literal["flight", "train"]
    cabin_class: str | None = None
    min_hotel_stars: int | None = Field(None, ge=1, le=5)
    # Continue an existing Trip Package session (e.g. re-searching after
    # changing dates) or omit to start a fresh one — mirrors POST /agent/chat.
    conversation_id: str | None = None


class TripPackageOptionsResponse(BaseModel):
    conversation_id: str
    options: dict


@router.post("/search", response_model=TripPackageOptionsResponse)
async def search_trip_package(payload: TripRequirements, user: CurrentUser):
    """
    Trip Requirements -> Package Options.

    Runs the same search_flights/search_trains + search_hotels tool calls a
    Trip Planner chat turn would make, then composes them with the SAME
    agents.trip_selection.build_options() the chat flow uses. Nothing here
    picks a component or sets a price — every figure in the response traces
    to a live search result.
    """
    destination = canonical_destination(payload.destination)
    if destination not in NORTHERN_DESTINATIONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Trip Package currently covers Naran, Hunza, Swat and Skardu only "
                "— the same destinations the AI Assistant's Trip Planner supports. "
                f"'{payload.destination}' isn't one of them."
            ),
        )

    # Validate everything deterministic (destination scope, hub/mode) BEFORE
    # touching the database — an invalid request should never cost a
    # conversation row or an ownership round-trip.
    hub = _hub_city_for(destination, payload.preferred_mode)
    if hub is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{destination} has no {payload.preferred_mode} route — try the other mode.",
        )

    if payload.conversation_id:
        conv = await asyncio.to_thread(
            _verify_conversation_owner, payload.conversation_id, user.id
        )
        if not conv.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found.",
            )
        conversation_id = payload.conversation_id
    else:
        conversation_id = await start_new_conversation(
            user.id, title=f"Trip Package — {destination}"
        )

    nights = (
        _nights_between(payload.travel_date, payload.return_date)
        if payload.return_date else (payload.nights or 2)
    )
    check_out = _add_days_iso(payload.travel_date, nights)

    transport_tool = "search_flights" if payload.preferred_mode == "flight" else "search_trains"
    transport_args: dict = {
        "origin_city": payload.origin,
        "destination_city": hub,
        "travel_date": payload.travel_date,
        "passengers": payload.travelers,
    }
    if payload.preferred_mode == "flight":
        transport_args["cabin_class"] = payload.cabin_class or "ECONOMY"

    hotel_args: dict = {
        "city": destination,
        "check_in": payload.travel_date,
        "check_out": check_out,
        "guests": payload.travelers,
        "rooms": 1,   # same assumption trip_selection.confirmation_booking_payloads makes
    }
    if payload.min_hotel_stars:
        hotel_args["min_stars"] = payload.min_hotel_stars

    transport_result, hotel_result = await asyncio.gather(
        dispatch_tool_with_retry(
            user_id=user.id, conversation_id=conversation_id,
            user_message=f"[Trip Package UI] {transport_tool}",
            name=transport_tool, args=transport_args,
            has_user_date=True,   # a native date picker — always genuinely user-supplied
        ),
        dispatch_tool_with_retry(
            user_id=user.id, conversation_id=conversation_id,
            user_message="[Trip Package UI] search_hotels",
            name="search_hotels", args=hotel_args, has_user_date=True,
        ),
    )
    gathered = [(transport_tool, transport_result), ("search_hotels", hotel_result)]

    options = trip_selection.build_options(
        gathered, destination, passengers=payload.travelers,
        preferred_mode=payload.preferred_mode,
    )
    if not options:
        detail = (
            _tool_error_detail(transport_result) or _tool_error_detail(hotel_result)
            or "No matching flights/trains and hotels were found for this trip. "
               "Try different dates or check the origin city."
        )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)

    # Belt and braces for confirm's fallback_date — never actually needed for
    # options built fresh here (their transport rows always carry a full
    # "YYYY-MM-DD HH:MM" depart, unlike the chat fallback path's rendered-text
    # round trip — see trip_selection.confirmation_booking_payloads'
    # docstring). Extra key is safe: is_valid_planner_state() only checks the
    # keys build_options() itself defines, never rejects additional ones.
    options["_travel_date"] = payload.travel_date
    await save_planner_state(conversation_id, user.id, options)
    return TripPackageOptionsResponse(conversation_id=conversation_id, options=options)


# ── Confirm a selection -> deterministic verify + reprice ────────────────────

class TripPackageConfirmRequest(BaseModel):
    conversation_id: str
    # 1-based indices into the options block /search returned, e.g.
    # {"transport": 2, "hotel": 1, "transfer": 1} — "transfer" omitted when
    # this destination/options block has none.
    picks: dict[str, int]
    pickup_location: str | None = None


class TripPackageConfirmResponse(BaseModel):
    conversation_id: str
    action: str
    booking_data: dict
    summary: str


@router.post("/confirm", response_model=TripPackageConfirmResponse)
async def confirm_trip_package(payload: TripPackageConfirmRequest, user: CurrentUser):
    """
    The traveller's confirmed pick -> server verification, repricing and
    package assembly — via agents.master_agent.complete_trip_planner_confirmation,
    the EXACT function the AI Assistant chat flow uses for the same step. The
    response is the same package_choice-shaped booking_data the chat flow
    already produces, so Flutter hands it to the SAME shared
    widgets/booking/card_payment_sheet.dart CardPaymentSheet the chat flow
    uses — no second booking or payment implementation.
    """
    conv = await asyncio.to_thread(
        _verify_conversation_owner, payload.conversation_id, user.id
    )
    if not conv.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found.")

    options = await get_active_planner_state(payload.conversation_id)
    if not options or not trip_selection.is_valid_planner_state(options):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No active package search for this conversation. Call /trip-packages/search first.",
        )

    picks = {
        k: v for k, v in (payload.picks or {}).items()
        if k in ("transport", "hotel", "transfer") and isinstance(v, int)
    }
    if not trip_selection.complete(options, picks):
        missing = trip_selection.outstanding(options, picks)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Incomplete selection — still need: {', '.join(missing)}.",
        )

    plan = trip_selection.build_plan(options, picks)
    if plan is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="This selection could not be resolved into a trip plan.",
        )

    pickup_location = (payload.pickup_location or "").strip()
    if plan.transfer and not pickup_location:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Pickup address at {plan.transfer['hub']} is required for this trip's transfer.",
        )

    destination = options.get("destination") or ""
    # get_transfer_error grounds BOTH transfer_pickup_location AND
    # transfer_dropoff_location against `user_texts` (see agent_tools.
    # _location_grounded, reused from get_car_provenance_error) — confirmed
    # directly, not assumed: an earlier version of this endpoint passed only
    # the pickup address here and every transfer booking was refused,
    # because "Naran" (the dropoff, == destination) never appeared in that
    # list. Neither value came from chat, but both genuinely came from the
    # traveller — the pickup from the transfer-detail form field, the
    # destination from the Trip Requirements form earlier in this same
    # session — so both belong in the "user said this" list the gate checks.
    conversation_user_texts = [t for t in (pickup_location, destination) if t]
    result, stale = await complete_trip_planner_confirmation(
        plan, options, picks, pickup_location,
        user_id=user.id,
        conversation_id=payload.conversation_id,
        user_message=f"[Trip Package UI] confirmed package for {destination}",
        history=[],   # a fresh Trip Package session has no prior chat to check
        conversation_user_texts=conversation_user_texts,
        trip_destination=destination,
        travel_date_fallback=options.get("_travel_date", ""),
    )
    if result is None:
        # `stale` (a specific component no longer confirmable against a
        # fresh search — see complete_trip_planner_confirmation's docstring)
        # gets a clearer, more actionable detail than the generic case; chat
        # auto-recovers by re-searching, but for this UI the simplest safe
        # behavior is to say plainly what to do next — the client already has
        # a working "re-run /search" path via the Trip Requirements screen.
        if stale is not None:
            bd = stale.get("bd") or {}
            label = (
                bd.get("hotel_name") or bd.get("flight_number") or
                bd.get("train_name") or "That option"
            )
            detail = f"{label} is no longer available at that price — please search again."
        else:
            detail = (
                "This package could no longer be verified at its shown price "
                "(it may have changed or sold out). Please search again."
            )
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    return TripPackageConfirmResponse(
        conversation_id=result["conversation_id"],
        action=result["action"],
        booking_data=result["booking_data"],
        summary=result["response"],
    )
