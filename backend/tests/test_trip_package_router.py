"""
routers/trip_packages.py — the HTTP surface for the native Trip Package UI.

Both endpoints are thin wrappers around the EXISTING engine
(trip_selection.build_options/build_plan, master_agent.
complete_trip_planner_confirmation) — these tests mostly cover the router's
OWN gating and wiring (ownership, scope, completeness, pickup-required), plus
one full end-to-end run proving /confirm really drives the same deterministic
engine the chat flow uses, not a second implementation of it.
"""
import asyncio
import json

import pytest
from fastapi import HTTPException

from agents import master_agent as ma
from agents import trip_selection as ts
from core.auth import AuthUser
from routers import trip_packages as tp

USER = AuthUser(id="user-1", email="user@test.com", phone=None, role="authenticated")

FLIGHTS_JSON = json.dumps({
    "search_date": "2027-06-10", "passengers": 2,
    "flights": [
        {"flight_number": "PA911", "airline": "Airblue", "from": "Karachi", "to": "Islamabad",
         "depart": "2027-06-10 08:00", "arrive": "10:00", "cabin": "ECONOMY",
         "total_price_pkr": 25000},
    ],
})
HOTELS_JSON = json.dumps({
    "city": "Naran", "nights": 2, "rooms": 1, "guests": 2,
    "hotels": [
        {"name": "Pine View Hotel", "stars": 3, "price_per_night_pkr": 9000,
         "total_stay_pkr": 18000},
    ],
})
EMPTY_FLIGHTS_JSON = json.dumps({"flights": [], "available_count": 0, "search_date": "2027-06-10"})
RETURN_FLIGHTS_JSON = json.dumps({
    "search_date": "2027-06-12", "passengers": 2,
    "flights": [
        {"flight_number": "PA912", "airline": "Airblue", "from": "Islamabad", "to": "Karachi",
         "depart": "2027-06-12 18:00", "arrive": "20:00", "cabin": "ECONOMY",
         "total_price_pkr": 27000},
    ],
})


def _owned(*_a, **_k):
    class _R:
        data = [{"id": "conv-1"}]
    return _R()


def _not_owned(*_a, **_k):
    class _R:
        data = []
    return _R()


def _sample_options() -> dict:
    """A real is_valid_planner_state()-shaped options block, built the same
    way the router itself would — not hand-crafted, so it can't drift from
    what build_options() actually produces."""
    gathered = [("search_flights", FLIGHTS_JSON), ("search_hotels", HOTELS_JSON)]
    options = ts.build_options(
        gathered,
        "Naran",
        passengers=2,
        preferred_mode="flight",
    )
    options["_travel_date"] = "2027-06-10"
    return options


# ─ /trip-packages/search

def test_search_rejects_a_destination_outside_the_four_supported():
    payload = tp.TripRequirements(
        origin="Karachi", destination="Lahore", travel_date="2027-06-10",
        travelers=2, preferred_mode="flight",
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.search_trip_package(payload, USER))
    assert exc.value.status_code == 422
    assert "Naran, Hunza, Swat and Skardu" in exc.value.detail


def test_hub_city_for_every_supported_destination_and_mode():
    # Confirmed directly against services.northern_routes.NORTHERN_DESTINATIONS:
    # Naran/Hunza/Swat each list BOTH a flight and a train hub (their train
    # hub is Rawalpindi, a real station — the traveller flies/rides there,
    # then transfers by road). Skardu ([]) has its own airport, but — a real
    # bug, caught live — "has its own airport" is not "has its own train
    # station": services.train_service.STATIONS marks Skardu bus_only (no
    # Pakistan Railways line reaches it at all), so its train hub must be
    # None, not "Skardu" itself (which used to run a doomed search that
    # always came back empty as an unhelpful generic 404).
    assert tp._hub_city_for("Naran", "flight") == "Islamabad"
    assert tp._hub_city_for("Naran", "train") == "Rawalpindi"
    assert tp._hub_city_for("Hunza", "flight") == "Gilgit"
    assert tp._hub_city_for("Hunza", "train") == "Rawalpindi"
    assert tp._hub_city_for("Skardu", "flight") == "Skardu"
    assert tp._hub_city_for("Skardu", "train") is None
    assert tp._hub_city_for("Lahore", "flight") is None   # not northern at all
    assert tp._hub_city_for("Naran", "bus") is None        # no hub serves this mode


def test_search_gives_a_clear_422_for_skardu_by_train_not_a_dead_end_404():
    """The bug as actually observed: a traveller picking Skardu + Train got a
    generic 'nothing found, try different dates' 404 after a real (wasted)
    search, instead of being told plainly that Skardu has no train route."""
    payload = tp.TripRequirements(
        origin="Karachi", destination="Skardu", travel_date="2027-06-10",
        travelers=1, preferred_mode="train",
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.search_trip_package(payload, USER))
    assert exc.value.status_code == 422
    assert "no train route" in exc.value.detail.lower()


def test_search_404s_when_an_existing_conversation_id_is_not_owned(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _not_owned)
    payload = tp.TripRequirements(
        origin="Karachi", destination="Naran", travel_date="2027-06-10",
        travelers=2, preferred_mode="flight", conversation_id="someone-elses-conv",
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.search_trip_package(payload, USER))
    assert exc.value.status_code == 404


def test_search_builds_real_options_from_the_search_tools(monkeypatch):
    saved: dict = {}

    async def _dispatch(*, user_id, conversation_id, user_message, name, args, has_user_date):
        assert has_user_date is True
        if name == "search_flights":
            assert args["origin_city"] == "Karachi"
            assert args["destination_city"] == "Islamabad"   # Naran's flight hub
            assert args["cabin_class"] == "ECONOMY"
            return FLIGHTS_JSON
        assert name == "search_hotels"
        assert args["city"] == "Naran"
        assert args["rooms"] == 1
        return HOTELS_JSON

    async def _start_new_conversation(uid, title=""):
        return "conv-new"

    async def _save_state(cid, uid, state):
        saved["conversation_id"] = cid
        saved["state"] = state

    monkeypatch.setattr(tp, "dispatch_tool_with_retry", _dispatch)
    monkeypatch.setattr(tp, "start_new_conversation", _start_new_conversation)
    monkeypatch.setattr(tp, "save_planner_state", _save_state)

    payload = tp.TripRequirements(
        origin="Karachi", destination="Naran", travel_date="2027-06-10",
        travelers=2, preferred_mode="flight",
    )
    result = asyncio.run(tp.search_trip_package(payload, USER))

    assert result.conversation_id == "conv-new"
    assert result.options["destination"] == "Naran"
    assert result.options["transport"][0]["flight_number"] == "PA911"
    assert result.options["hotels"][0]["name"] == "Pine View Hotel"
    assert result.options["transfers"]        # Naran has a hub transfer
    assert saved["conversation_id"] == "conv-new"
    assert saved["state"]["destination"] == "Naran"
    assert saved["state"]["_travel_date"] == "2027-06-10"


def test_search_surfaces_a_clear_404_when_nothing_is_found(monkeypatch):
    async def _dispatch(*, user_id, conversation_id, user_message, name, args, has_user_date):
        return EMPTY_FLIGHTS_JSON if name == "search_flights" else HOTELS_JSON

    async def _start_new_conversation(uid, title=""):
        return "conv-new"

    monkeypatch.setattr(tp, "dispatch_tool_with_retry", _dispatch)
    monkeypatch.setattr(tp, "start_new_conversation", _start_new_conversation)

    payload = tp.TripRequirements(
        origin="Karachi", destination="Naran", travel_date="2027-06-10",
        travelers=2, preferred_mode="flight",
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.search_trip_package(payload, USER))
    assert exc.value.status_code == 404


# ── /trip-packages/confirm ────────────────────────────────────────────────

def test_confirm_404s_when_conversation_not_owned(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _not_owned)
    payload = tp.TripPackageConfirmRequest(
        conversation_id="not-mine", picks={"transport": 1, "hotel": 1},
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.confirm_trip_package(payload, USER))
    assert exc.value.status_code == 404


def test_confirm_409s_with_no_active_state(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)

    async def _no_state(cid):
        return None
    monkeypatch.setattr(tp, "get_active_planner_state", _no_state)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1},
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.confirm_trip_package(payload, USER))
    assert exc.value.status_code == 409


def test_confirm_422s_on_incomplete_picks(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1},   # no hotel
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.confirm_trip_package(payload, USER))
    assert exc.value.status_code == 422
    assert "Incomplete selection" in exc.value.detail


def test_confirm_422s_when_transfer_needed_but_no_pickup_given(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()
    assert options["transfers"], "sanity: Naran must offer a transfer for this test to mean anything"

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1, "transfer": 1},
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.confirm_trip_package(payload, USER))
    assert exc.value.status_code == 422
    assert "Pickup address" in exc.value.detail


def test_confirm_409s_when_the_engine_declines_to_verify(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    async def _declines(*a, **k):
        return None, None   # (result, stale) -- generic decline, not a stale pick
    monkeypatch.setattr(tp, "complete_trip_planner_confirmation", _declines)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1, "transfer": 1},
        pickup_location="Islamabad Airport",
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.confirm_trip_package(payload, USER))
    assert exc.value.status_code == 409
    assert "could no longer be verified" in exc.value.detail


def test_confirm_409s_with_a_specific_message_when_the_pick_went_stale(monkeypatch):
    """
    complete_trip_planner_confirmation distinguishes "can't verify, try
    again" (generic) from "this exact option vanished from a fresh search"
    (stale) -- the REST endpoint doesn't auto-recover the way chat does, but
    it should at least surface which component to blame instead of the
    generic message.
    """
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    async def _stale(*a, **k):
        return None, {"booking_type": "hotel", "bd": {"hotel_name": "Pine View Hotel"}}
    monkeypatch.setattr(tp, "complete_trip_planner_confirmation", _stale)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1, "transfer": 1},
        pickup_location="Islamabad Airport",
    )
    with pytest.raises(HTTPException) as exc:
        asyncio.run(tp.confirm_trip_package(payload, USER))
    assert exc.value.status_code == 409
    assert "Pine View Hotel" in exc.value.detail


def test_confirm_wires_the_pickup_address_into_the_grounding_texts(monkeypatch):
    """
    Neither the pickup address nor the destination came from chat — both came
    from native form fields — but both must still be threaded through as
    conversation_user_texts, since get_transfer_error grounds BOTH
    transfer_pickup_location and transfer_dropoff_location (== destination)
    against that list (agent_tools._location_grounded). Passing only the
    pickup address here (an earlier version of this endpoint did) leaves the
    dropoff ungrounded and every transfer booking gets refused — confirmed
    directly against the real gate, not assumed.
    """
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()
    captured: dict = {}

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    async def _capture(plan, opts, picks, pickup, **kwargs):
        captured.update(kwargs)
        captured["pickup"] = pickup
        return {
            "response": "ok", "conversation_id": kwargs["conversation_id"],
            "action": "package_choice", "booking_data": {"total_price_pkr": 1},
        }, None
    monkeypatch.setattr(tp, "complete_trip_planner_confirmation", _capture)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1, "transfer": 1},
        pickup_location="Islamabad Airport",
    )
    result = asyncio.run(tp.confirm_trip_package(payload, USER))

    assert captured["pickup"] == "Islamabad Airport"
    assert captured["conversation_user_texts"] == ["Islamabad Airport", "Naran"]
    assert captured["trip_destination"] == "Naran"
    assert captured["history"] == []
    assert captured["travel_date_fallback"] == "2027-06-10"
    assert result.action == "package_choice"


def test_confirm_end_to_end_drives_the_real_deterministic_engine(monkeypatch):
    """
    No mock of complete_trip_planner_confirmation here — only the true I/O
    edges (reprice_booking, save_turn, the fire-and-forget task logger) are
    stubbed, the same way process_message_agentic's own test fixtures do it.
    Proves the router really reaches verify_booking_payload's real gate
    sequence and a real reprice, through the SAME function the chat flow
    uses — not a second implementation of booking verification.
    """
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    async def _reprice(bd):
        verified = dict(bd)
        verified["total_price_pkr"] = bd.get("total_price_pkr") or 0
        return verified
    monkeypatch.setattr(ma, "reprice_booking", _reprice)

    saved: dict = {}

    async def _save_turn(cid, uid, msg, reply, **kw):
        saved["reply"] = reply
    monkeypatch.setattr(ma, "save_turn", _save_turn)

    async def _log_task(*a, **k):
        pass
    monkeypatch.setattr(ma, "_log_task", _log_task)

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1, "transfer": 1},
        pickup_location="Islamabad Airport",
    )
    result = asyncio.run(tp.confirm_trip_package(payload, USER))

    assert result.action == "package_choice"
    assert result.booking_data["total_price_pkr"] > 0
    components = result.booking_data.get("components") or []
    assert len(components) == 2   # flight (carrying the transfer) + hotel
    assert any(c.get("transfer_vehicle_type") for c in components)
    assert saved["reply"]          # a real chat-shaped summary was persisted too


# ── Optional return leg (native form) ────────────────────────────────────────
#
# The native form always has a real nights value (a required stepper, unlike
# chat where a return date may never be given at all) — want_return is the
# ONLY signal needed, no "was this a real date" ambiguity to gate on. Same
# "never search a leg the traveller didn't ask for" posture as the chat Trip
# Planner's own return-leg offer (trip_selection.build_return_options).

def test_search_without_want_return_never_searches_a_return_leg(monkeypatch):
    calls: list[str] = []

    async def _dispatch(*, user_id, conversation_id, user_message, name, args, has_user_date):
        calls.append(name)
        return FLIGHTS_JSON if name == "search_flights" else HOTELS_JSON

    async def _start_new_conversation(uid, title=""):
        return "conv-new"

    async def _save_state(cid, uid, state):
        pass

    monkeypatch.setattr(tp, "dispatch_tool_with_retry", _dispatch)
    monkeypatch.setattr(tp, "start_new_conversation", _start_new_conversation)
    monkeypatch.setattr(tp, "save_planner_state", _save_state)

    payload = tp.TripRequirements(
        origin="Karachi", destination="Naran", travel_date="2027-06-10",
        travelers=2, preferred_mode="flight",   # want_return defaults False
    )
    result = asyncio.run(tp.search_trip_package(payload, USER))

    assert calls == ["search_flights", "search_hotels"]
    assert "return_transport" not in result.options


def test_search_with_want_return_adds_return_transport_to_options(monkeypatch):
    calls: list[tuple[str, dict]] = []

    async def _dispatch(*, user_id, conversation_id, user_message, name, args, has_user_date):
        calls.append((name, args))
        if name == "search_hotels":
            return HOTELS_JSON
        # First search_flights call is outbound (Karachi->Islamabad), second
        # is the return leg (Islamabad->Karachi) — distinguished by args,
        # not call order, so the assertions below can't pass by accident.
        if args.get("destination_city") == "Karachi":
            return RETURN_FLIGHTS_JSON
        return FLIGHTS_JSON

    async def _start_new_conversation(uid, title=""):
        return "conv-new"

    saved: dict = {}

    async def _save_state(cid, uid, state):
        saved["state"] = state

    monkeypatch.setattr(tp, "dispatch_tool_with_retry", _dispatch)
    monkeypatch.setattr(tp, "start_new_conversation", _start_new_conversation)
    monkeypatch.setattr(tp, "save_planner_state", _save_state)

    payload = tp.TripRequirements(
        origin="Karachi", destination="Naran", travel_date="2027-06-10",
        nights=2, travelers=2, preferred_mode="flight", want_return=True,
    )
    result = asyncio.run(tp.search_trip_package(payload, USER))

    flight_calls = [args for name, args in calls if name == "search_flights"]
    assert len(flight_calls) == 2
    return_call = next(a for a in flight_calls if a["destination_city"] == "Karachi")
    assert return_call["origin_city"] == "Islamabad"   # Naran's own flight hub
    assert return_call["travel_date"] == "2027-06-12"  # travel_date + nights

    assert result.options["return_transport"][0]["flight_number"] == "PA912"
    assert result.options["_return_kind"] == "flight"
    assert result.options["_return_origin"] == "Karachi"
    assert result.options["_return_date"] == "2027-06-12"
    assert saved["state"]["return_transport"]   # persisted for /confirm too


def test_search_with_want_return_but_nothing_found_falls_back_to_one_way(monkeypatch):
    async def _dispatch(*, user_id, conversation_id, user_message, name, args, has_user_date):
        if name == "search_hotels":
            return HOTELS_JSON
        if args.get("destination_city") == "Karachi":
            return EMPTY_FLIGHTS_JSON   # no return flights found
        return FLIGHTS_JSON

    async def _start_new_conversation(uid, title=""):
        return "conv-new"

    async def _save_state(cid, uid, state):
        pass

    monkeypatch.setattr(tp, "dispatch_tool_with_retry", _dispatch)
    monkeypatch.setattr(tp, "start_new_conversation", _start_new_conversation)
    monkeypatch.setattr(tp, "save_planner_state", _save_state)

    payload = tp.TripRequirements(
        origin="Karachi", destination="Naran", travel_date="2027-06-10",
        nights=2, travelers=2, preferred_mode="flight", want_return=True,
    )
    result = asyncio.run(tp.search_trip_package(payload, USER))

    # A complete one-way package still comes back — the traveller ticking
    # "return trip" and getting nothing for it must never break the outbound
    # package they already have.
    assert result.options["destination"] == "Naran"
    assert result.options["transport"][0]["flight_number"] == "PA911"
    assert "return_transport" not in result.options


def test_confirm_applies_a_picked_return_leg_as_a_third_component(monkeypatch):
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()
    return_rows, return_kind = ts.build_return_options(
        [("search_flights", RETURN_FLIGHTS_JSON)]
    )
    options["return_transport"] = return_rows
    options["_return_kind"] = return_kind
    options["_return_origin"] = "Karachi"
    options["_return_date"] = "2027-06-12"

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    async def _reprice(bd):
        verified = dict(bd)
        verified["total_price_pkr"] = bd.get("total_price_pkr") or 0
        return verified
    monkeypatch.setattr(ma, "reprice_booking", _reprice)
    monkeypatch.setattr(ma, "save_turn", lambda *a, **k: _async_none())
    monkeypatch.setattr(ma, "_log_task", lambda *a, **k: _async_none())

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1",
        picks={"transport": 1, "hotel": 1, "transfer": 1, "return_transport": 1},
        pickup_location="Islamabad Airport",
    )
    result = asyncio.run(tp.confirm_trip_package(payload, USER))

    components = result.booking_data.get("components") or []
    assert len(components) == 3   # outbound flight (+transfer) + hotel + return flight
    return_leg = next(c for c in components if c.get("flight_number") == "PA912")
    assert return_leg["origin"] == "Islamabad" and return_leg["destination"] == "Karachi"
    assert return_leg["total_price_pkr"] == 27000


def test_confirm_without_a_return_pick_stays_two_components_even_when_offered(monkeypatch):
    """Ticking "return trip" and getting options doesn't force picking one —
    omitting return_transport from picks must book the outbound trip alone,
    same as if want_return had never been set."""
    monkeypatch.setattr(tp, "_verify_conversation_owner", _owned)
    options = _sample_options()
    return_rows, return_kind = ts.build_return_options(
        [("search_flights", RETURN_FLIGHTS_JSON)]
    )
    options["return_transport"] = return_rows
    options["_return_kind"] = return_kind

    async def _state(cid):
        return options
    monkeypatch.setattr(tp, "get_active_planner_state", _state)

    async def _reprice(bd):
        verified = dict(bd)
        verified["total_price_pkr"] = bd.get("total_price_pkr") or 0
        return verified
    monkeypatch.setattr(ma, "reprice_booking", _reprice)
    monkeypatch.setattr(ma, "save_turn", lambda *a, **k: _async_none())
    monkeypatch.setattr(ma, "_log_task", lambda *a, **k: _async_none())

    payload = tp.TripPackageConfirmRequest(
        conversation_id="conv-1", picks={"transport": 1, "hotel": 1, "transfer": 1},
        pickup_location="Islamabad Airport",
    )
    result = asyncio.run(tp.confirm_trip_package(payload, USER))

    components = result.booking_data.get("components") or []
    assert len(components) == 2


async def _async_none(*_a, **_k):
    return None
