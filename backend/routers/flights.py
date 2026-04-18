# =============================================================================
# FILE: routers/flights.py
# PREFIX: /flights
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // POST /flights/search
# Future<Map<String, dynamic>> searchFlights({
#   required String origin,       // IATA code e.g. 'KHI'
#   required String destination,  // IATA code e.g. 'LHE'
#   required String date,         // 'YYYY-MM-DD'
#   int adults = 1,
#   String cabinClass = 'ECONOMY',
#   String? returnDate,
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/flights/search'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({
#       'origin': origin,
#       'destination': destination,
#       'date': date,
#       'adults': adults,
#       'cabin_class': cabinClass,
#       if (returnDate != null) 'return_date': returnDate,
#     }),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
#   // response.offers → List of flight offers
# }
#
# // GET /flights/{offer_id}   (offer_id from search results)
# Future<Map<String, dynamic>> getFlightDetail(String offerId) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/flights/$offerId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // POST /flights/book
# Future<Map<String, dynamic>> bookFlight({
#   required String offerId,
#   required String contactEmail,
#   String? contactPhone,
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/flights/book'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({
#       'offer_id': offerId,
#       'contact_email': contactEmail,
#       if (contactPhone != null) 'contact_phone': contactPhone,
#     }),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
#   // response keys: booking_id, pnr, status, total_amount
# }
# =============================================================================

import json
import logging
import time
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from core.auth import CurrentUser
from models.flight import FlightBookRequest, FlightOffer, FlightSearchRequest, FlightSearchResponse
from services.flight_service import search_flights as _search_flights
from services.booking_service import create_booking
from typing import Any

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/flights", tags=["Flights"])

# In-memory offer cache — maps offer_id → (FlightOffer, timestamp).
# In production, use Redis. For FYP demo, per-process dict is fine.
_CACHE_TTL = 1800  # 30 minutes
_offer_cache: dict[str, tuple[FlightOffer, float]] = {}


# ---------------------------------------------------------------------------
# POST /flights/search
# ---------------------------------------------------------------------------

@router.post("/search", response_model=FlightSearchResponse)
async def search_flights_endpoint(
    payload: FlightSearchRequest,
):
    """
    Search for available flights.
    Domestic Pakistan routes → seeded mock data (no API quota used).
    International routes → AviationStack API (if key set) or generated mock.
    Results cached in memory so GET /flights/{offer_id} can retrieve them.
    """
    offers = await _search_flights(
        origin=payload.origin,
        destination=payload.destination,
        date=payload.date,
        adults=payload.adults,
        cabin_class=payload.cabin_class,
        return_date=payload.return_date,
    )

    ts = time.time()
    for offer in offers:
        _offer_cache[offer.offer_id] = (offer, ts)

    return FlightSearchResponse(
        origin=payload.origin.upper(),
        destination=payload.destination.upper(),
        date=payload.date,
        count=len(offers),
        offers=offers,
    )


# ---------------------------------------------------------------------------
# GET /flights/{offer_id}
# ---------------------------------------------------------------------------

@router.get("/{offer_id}", response_model=FlightOffer)
async def get_flight_offer(offer_id: str, user: CurrentUser):
    """
    Return a single cached flight offer by its ID.
    The Flutter app calls this before the booking confirmation screen
    to display full itinerary details.
    """
    cached = _offer_cache.get(offer_id)
    if not cached or time.time() - cached[1] > _CACHE_TTL:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                f"Flight offer '{offer_id}' not found or expired. "
                "Please search again — results are cached for 30 minutes."
            ),
        )
    return cached[0]


# ---------------------------------------------------------------------------
# POST /flights/book
# ---------------------------------------------------------------------------

@router.post("/book", status_code=status.HTTP_201_CREATED)
async def book_flight(payload: FlightBookRequest, user: CurrentUser):
    """
    Create a flight booking record in the database.
    Status starts as 'pending' — complete payment via /payments/initiate to confirm.
    Returns the booking_id, PNR, and total amount for the payment screen.
    """
    cached = _offer_cache.get(payload.offer_id)
    if not cached or time.time() - cached[1] > _CACHE_TTL:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight offer expired or not found. Please search again.",
        )
    offer = cached[0]

    # Extract itinerary details for denormalised columns
    first_itin = offer.itineraries[0] if offer.itineraries else None
    first_seg = first_itin.segments[0] if first_itin and first_itin.segments else None
    last_seg = (
        first_itin.segments[-1]
        if first_itin and first_itin.segments
        else None
    )

    # Fix 7: Reject bookings for already-departed flights
    if first_seg and first_seg.departure_time < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot book a flight that has already departed.",
        )

    raw_payload = {
        "offer_id": offer.offer_id,
        "itineraries": [
            {
                "duration": itin.duration,
                "segments": [
                    {
                        "carrier_code": seg.carrier_code,
                        "flight_number": seg.flight_number,
                        "departure_airport": seg.departure_airport,
                        "arrival_airport": seg.arrival_airport,
                        "departure_time": seg.departure_time.isoformat(),
                        "arrival_time": seg.arrival_time.isoformat(),
                        "duration": seg.duration,
                        "cabin_class": seg.cabin_class,
                    }
                    for seg in itin.segments
                ],
            }
            for itin in offer.itineraries
        ],
        "baggage_allowance": offer.baggage_allowance,
        "is_refundable": offer.is_refundable,
    }

    booking = await create_booking(
        user_id=user.id,
        booking_type="flight",
        contact_email=payload.contact_email,
        contact_phone=payload.contact_phone,
        total_amount=offer.total_price_pkr,
        raw_payload=raw_payload,
        origin=first_seg.departure_airport if first_seg else None,
        destination=last_seg.arrival_airport if last_seg else None,
        departure_at=first_seg.departure_time if first_seg else None,
        arrival_at=last_seg.arrival_time if last_seg else None,
    )

    return {
        "booking_id": booking.booking_id,
        "booking_uuid": booking.id,
        "pnr": booking.pnr,
        "status": booking.status,
        "total_amount": booking.total_amount,
        "currency": booking.currency,
        "message": "Flight booking created. Proceed to payment to confirm.",
    }


# ---------------------------------------------------------------------------
# GET /flights/deals  — Part 4C: Featured Pakistani route deals
# ---------------------------------------------------------------------------

@router.get("/deals")
async def get_flight_deals() -> list[dict[str, Any]]:
    """
    Return 6 popular Pakistani routes with discounted mock prices.
    No auth required — used on the home screen to inspire travel.

    // FLUTTER: Future<List<dynamic>> getDeals() async {
    //   final res = await http.get(Uri.parse('$baseUrl/flights/deals'));
    //   return jsonDecode(res.body) as List<dynamic>;
    // }
    """
    from datetime import date, timedelta
    import random

    today = date.today()
    # Deals valid for the next 14 days
    valid_until = (today + timedelta(days=14)).isoformat()

    deals = [
        {"origin": "KHI", "origin_city": "Karachi",
         "destination": "SKD", "destination_city": "Skardu",
         "price_pkr": 12_500, "original_price_pkr": 18_000,
         "discount_percent": 31, "airline": "PIA",
         "valid_until": valid_until,
         "image": "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600"},
        {"origin": "LHE", "origin_city": "Lahore",
         "destination": "ISB", "destination_city": "Islamabad",
         "price_pkr": 4_200,  "original_price_pkr": 6_500,
         "discount_percent": 35, "airline": "Airblue",
         "valid_until": valid_until,
         "image": "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=600"},
        {"origin": "KHI", "origin_city": "Karachi",
         "destination": "LHE", "destination_city": "Lahore",
         "price_pkr": 7_800,  "original_price_pkr": 11_000,
         "discount_percent": 29, "airline": "Serene Air",
         "valid_until": valid_until,
         "image": "https://images.unsplash.com/photo-1548574505-5e239809ee19?w=600"},
        {"origin": "ISB", "origin_city": "Islamabad",
         "destination": "PEW", "destination_city": "Peshawar",
         "price_pkr": 3_500,  "original_price_pkr": 5_200,
         "discount_percent": 33, "airline": "AirSial",
         "valid_until": valid_until,
         "image": "https://images.unsplash.com/photo-1587019158091-1a103c5dd17f?w=600"},
        {"origin": "KHI", "origin_city": "Karachi",
         "destination": "GIL", "destination_city": "Gilgit",
         "price_pkr": 14_000, "original_price_pkr": 20_000,
         "discount_percent": 30, "airline": "PIA",
         "valid_until": valid_until,
         "image": "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=600"},
        {"origin": "MUX", "origin_city": "Multan",
         "destination": "KHI", "destination_city": "Karachi",
         "price_pkr": 5_500,  "original_price_pkr": 8_000,
         "discount_percent": 31, "airline": "Airblue",
         "valid_until": valid_until,
         "image": "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=600"},
    ]
    return deals
