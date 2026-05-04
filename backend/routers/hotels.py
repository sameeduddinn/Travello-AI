# =============================================================================
# FILE: routers/hotels.py
# PREFIX: /hotels
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // POST /hotels/search
# Future<Map<String, dynamic>> searchHotels({
#   required String city,
#   required String checkIn,   // 'YYYY-MM-DD'
#   required String checkOut,  // 'YYYY-MM-DD'
#   int guests = 1,
#   int rooms = 1,
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/hotels/search'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({
#       'city': city,
#       'check_in': checkIn,
#       'check_out': checkOut,
#       'guests': guests,
#       'rooms': rooms,
#     }),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
#   // response.hotels → List<HotelOffer>
# }
#
# // GET /hotels/{hotel_id}
# Future<Map<String, dynamic>> getHotelDetail(String hotelId) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/hotels/$hotelId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // POST /hotels/book
# Future<Map<String, dynamic>> bookHotel({
#   required String hotelId,
#   required String roomId,
#   required String checkIn,
#   required String checkOut,
#   required String contactEmail,
#   int guests = 1,
#   int rooms = 1,
#   String? contactPhone,
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/hotels/book'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({
#       'hotel_id': hotelId,
#       'room_id': roomId,
#       'check_in': checkIn,
#       'check_out': checkOut,
#       'contact_email': contactEmail,
#       'guests': guests,
#       'rooms': rooms,
#       if (contactPhone != null) 'contact_phone': contactPhone,
#     }),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
# =============================================================================

import logging
import time
from datetime import date

from fastapi import APIRouter, HTTPException, status

from core.auth import CurrentUser
from models.hotel import HotelBookRequest, HotelOffer, HotelSearchRequest, HotelSearchResponse
from services.booking_service import create_booking
from services.hotel_service import get_hotel_detail, search_hotels

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/hotels", tags=["Hotels"])

# In-memory hotel offer cache (hotel_id → (HotelOffer, timestamp))
_CACHE_TTL = 1800  # 30 minutes
_hotel_cache: dict[str, tuple[HotelOffer, float]] = {}


# ---------------------------------------------------------------------------
# POST /hotels/search
# ---------------------------------------------------------------------------

@router.post("/search", response_model=HotelSearchResponse)
async def search_hotels_endpoint(payload: HotelSearchRequest):
    """
    Search hotels in a given city for the specified date range.
    Uses RapidAPI Hotels4 if configured, otherwise returns mock Pakistani hotels.

    Supported cities (mock): Karachi, Lahore, Islamabad, Multan,
                              Peshawar, Quetta, Faisalabad
    """
    if payload.check_out <= payload.check_in:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="check_out must be after check_in.",
        )

    response = await search_hotels(
        city=payload.city,
        check_in=payload.check_in,
        check_out=payload.check_out,
        guests=payload.guests,
        rooms=payload.rooms,
    )

    # Cache all returned hotels
    ts = time.time()
    for hotel in response.hotels:
        _hotel_cache[hotel.hotel_id] = (hotel, ts)

    return response


# ---------------------------------------------------------------------------
# GET /hotels/{hotel_id}
# ---------------------------------------------------------------------------

@router.get("/{hotel_id}", response_model=HotelOffer)
async def get_hotel_detail_endpoint(hotel_id: str, user: CurrentUser):
    """
    Return details for a specific hotel.
    Checks the in-memory cache first, then falls back to the mock catalogue.
    """
    # Check cache first (respect TTL)
    cached = _hotel_cache.get(hotel_id)
    if cached and time.time() - cached[1] <= _CACHE_TTL:
        return cached[0]

    # Fall back to mock catalogue
    hotel = await get_hotel_detail(hotel_id)
    if not hotel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Hotel '{hotel_id}' not found. Please search again.",
        )

    _hotel_cache[hotel_id] = (hotel, time.time())
    return hotel


# ---------------------------------------------------------------------------
# POST /hotels/book
# ---------------------------------------------------------------------------

@router.post("/book", status_code=status.HTTP_201_CREATED)
async def book_hotel(payload: HotelBookRequest, user: CurrentUser):
    """
    Create a hotel booking record.
    Status starts as 'pending' — complete payment via /payments/initiate to confirm.
    """
    if payload.check_out <= payload.check_in:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="check_out must be after check_in.",
        )

    # Fix 3: Reject past check-in dates
    if payload.check_in < date.today():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="check_in must not be in the past.",
        )

    # Look up hotel (respect cache TTL)
    cached = _hotel_cache.get(payload.hotel_id)
    hotel = cached[0] if cached and time.time() - cached[1] <= _CACHE_TTL else None
    if not hotel:
        hotel = await get_hotel_detail(payload.hotel_id, payload.city or "")
    if not hotel and payload.city:
        # If in-memory cache was missed, rebuild from a fresh city search.
        refreshed = await search_hotels(
            city=payload.city,
            check_in=payload.check_in,
            check_out=payload.check_out,
            guests=payload.guests,
            rooms=payload.rooms,
        )
        ts = time.time()
        for h in refreshed.hotels:
            _hotel_cache[h.hotel_id] = (h, ts)
        hotel = next((h for h in refreshed.hotels if h.hotel_id == payload.hotel_id), None)
    if not hotel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hotel not found. Please search again.",
        )

    # Find the requested room
    room = next((r for r in hotel.rooms if r.room_id == payload.room_id), None)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Room '{payload.room_id}' not found in this hotel.",
        )

    nights = (payload.check_out - payload.check_in).days
    total_amount = round(room.price_per_night_pkr * nights * payload.rooms, 2)

    raw_payload = {
        "hotel_id": hotel.hotel_id,
        "hotel_name": hotel.name,
        "star_rating": hotel.star_rating,
        "address": hotel.address,
        "city": hotel.city,
        "room_id": room.room_id,
        "room_type": room.room_type,
        "bed_type": room.bed_type,
        "price_per_night_pkr": room.price_per_night_pkr,
        "nights": nights,
        "rooms": payload.rooms,
        "guests": payload.guests,
        "amenities": hotel.amenities,
        "images": hotel.images[:3],
    }

    booking = await create_booking(
        user_id=user.id,
        booking_type="hotel",
        contact_email=payload.contact_email,
        contact_phone=payload.contact_phone,
        total_amount=total_amount,
        raw_payload=raw_payload,
        hotel_name=hotel.name,
        check_in=payload.check_in,
        check_out=payload.check_out,
        destination=hotel.city,
    )

    return {
        "booking_id": booking.booking_id,
        "booking_uuid": booking.id,
        "pnr": booking.pnr,
        "status": booking.status,
        "hotel_name": hotel.name,
        "room_type": room.room_type,
        "check_in": str(payload.check_in),
        "check_out": str(payload.check_out),
        "nights": nights,
        "rooms": payload.rooms,
        "guests": payload.guests,
        "total_amount": total_amount,
        "currency": "PKR",
        "message": "Hotel booking created. Proceed to payment to confirm.",
    }
