# =============================================================================
# FILE: routers/trains.py
# PREFIX: /trains
# =============================================================================

import logging
import time
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status

from core.auth import CurrentUser
from models.train import TrainBookRequest, TrainOffer, TrainSearchRequest, TrainSearchResponse
from services.booking_service import create_booking
from services.train_service import search_trains, get_train_offer

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/trains", tags=["Trains"])

# In-memory offer cache (train_id → (TrainOffer, timestamp))
_CACHE_TTL = 1800  # 30 minutes
_train_cache: dict[str, tuple[TrainOffer, float]] = {}


# POST /trains/search

@router.post("/search", response_model=TrainSearchResponse)
async def search_trains_endpoint(payload: TrainSearchRequest):
    """
    Search Pakistan Railways trains for the given city pair and date.
    Returns real train names, schedules, and seat classes with prices in PKR.

    Supported cities: Karachi, Lahore, Islamabad, Rawalpindi, Multan,
                      Peshawar, Quetta, Faisalabad, Hyderabad, Sukkur,
                      Gujranwala, Sialkot, Sahiwal, Jacobabad, Attock
    """
    response = search_trains(
        origin=payload.origin,
        destination=payload.destination,
        travel_date=payload.date,
        passengers=payload.passengers,
    )

    # Cache each result by train_id for the /book endpoint
    ts = time.time()
    # Evict expired entries before writing new ones
    expired = [k for k, (_, t) in _train_cache.items() if ts - t > _CACHE_TTL]
    for k in expired:
        del _train_cache[k]
    for train in response.trains:
        _train_cache[train.train_id] = (train, ts)

    if response.count == 0:
        # Return empty list with helpful message rather than 404
        # so Flutter can display "No trains found" gracefully
        pass

    return response


# POST /trains/book

@router.post("/book", status_code=status.HTTP_201_CREATED)
async def book_train(payload: TrainBookRequest, user: CurrentUser):
    """
    Create a train booking record in the database.
    Status starts as 'pending' — complete payment via /payments/initiate to confirm.
    """
    # Try cache first (check TTL), then re-compute from train_id
    cached = _train_cache.get(payload.train_id)
    if cached and time.time() - cached[1] <= _CACHE_TTL:
        offer = cached[0]
    else:
        offer = get_train_offer(payload.train_id, passengers=payload.passengers)

    if not offer:
        # Fallback path for featured packages (train_id not in cache)
        if not payload.train_name or payload.total_price_pkr is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Train offer not found. Please search again.",
            )

        now = datetime.now(timezone.utc).replace(tzinfo=None)
        try:
            dep_at = datetime.fromisoformat(payload.departure_at) if payload.departure_at else now
        except (ValueError, TypeError):
            dep_at = now
        try:
            arr_at = datetime.fromisoformat(payload.arrival_at) if payload.arrival_at else now
        except (ValueError, TypeError):
            arr_at = dep_at

        total_amount = payload.total_price_pkr * payload.passengers
        raw_payload = {
            "train_id": payload.train_id,
            "train_name": payload.train_name,
            "train_number": payload.train_number or "",
            "class_code": payload.class_code,
            "class_name": payload.class_name or payload.class_code,
            "passengers": payload.passengers,
            "amenities": [],
        }
        if payload.facilities:
            raw_payload.update(payload.facilities)

        booking = await create_booking(
            user_id=user.id,
            booking_type="train",
            contact_email=payload.contact_email,
            contact_phone=payload.contact_phone,
            total_amount=total_amount,
            raw_payload=raw_payload,
            origin=payload.origin or "",
            destination=payload.destination or "",
            departure_at=dep_at,
            arrival_at=arr_at,
        )

        return {
            "booking_id": booking.booking_id,
            "booking_uuid": booking.id,
            "pnr": booking.pnr,
            "status": booking.status,
            "train_name": payload.train_name,
            "train_number": payload.train_number or "",
            "class": payload.class_name or payload.class_code,
            "origin": payload.origin or "",
            "destination": payload.destination or "",
            "departure_at": dep_at.isoformat(),
            "arrival_at": arr_at.isoformat(),
            "total_amount": total_amount,
            "currency": "PKR",
            "message": "Train booking created. Proceed to payment to confirm.",
        }

    # Find the requested seat class
    seat_class = next(
        (c for c in offer.classes if c.class_code == payload.class_code),
        None,
    )
    if not seat_class:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Seat class '{payload.class_code}' not available on this train.",
        )

    if seat_class.seats_available < payload.passengers:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Only {seat_class.seats_available} seat(s) available in "
                f"{seat_class.class_name}. Requested: {payload.passengers}."
            ),
        )

    total_amount = seat_class.price_pkr  # already multiplied by passengers in service

    raw_payload = {
        "train_id": offer.train_id,
        "train_name": offer.train_name,
        "train_number": offer.train_number,
        "class_code": payload.class_code,
        "class_name": seat_class.class_name,
        "passengers": payload.passengers,
        "amenities": seat_class.amenities,
    }
    if payload.facilities:
        raw_payload.update(payload.facilities)

    booking = await create_booking(
        user_id=user.id,
        booking_type="train",
        contact_email=payload.contact_email,
        contact_phone=payload.contact_phone,
        total_amount=total_amount,
        raw_payload=raw_payload,
        origin=offer.origin,
        destination=offer.destination,
        departure_at=offer.departure_at,
        arrival_at=offer.arrival_at,
    )

    return {
        "booking_id": booking.booking_id,
        "booking_uuid": booking.id,
        "pnr": booking.pnr,
        "status": booking.status,
        "train_name": offer.train_name,
        "train_number": offer.train_number,
        "class": seat_class.class_name,
        "origin": offer.origin,
        "destination": offer.destination,
        "departure_at": offer.departure_at.isoformat(),
        "arrival_at": offer.arrival_at.isoformat(),
        "total_amount": total_amount,
        "currency": "PKR",
        "message": "Train booking created. Proceed to payment to confirm.",
    }
