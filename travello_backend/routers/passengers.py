# =============================================================================
# FILE: routers/passengers.py
# PREFIX: /passengers
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // POST /passengers  — add one or more passengers to a booking
# Future<List<dynamic>> addPassengers({
#   required String bookingId,   // UUID of the booking
#   required List<Map<String, dynamic>> passengers,
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/passengers'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({
#       'booking_id': bookingId,
#       'passengers': passengers,
#       // Example passenger map:
#       // {
#       //   'title': 'Mr',
#       //   'first_name': 'Ali',
#       //   'last_name': 'Khan',
#       //   'date_of_birth': '1995-03-15',
#       //   'gender': 'male',
#       //   'cnic': '4210112345671',
#       //   'passenger_type': 'adult',
#       // }
#     }),
#   );
#   return jsonDecode(res.body) as List<dynamic>;
# }
#
# // GET /passengers/{bookingId}
# Future<List<dynamic>> getPassengers(String bookingId) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/passengers/$bookingId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as List<dynamic>;
# }
#
# // DELETE /passengers/{passengerId}
# Future<void> deletePassenger(String passengerId) async {
#   await http.delete(
#     Uri.parse('$baseUrl/passengers/$passengerId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
# }
# =============================================================================

import logging

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from core.auth import CurrentUser
from models.booking import PassengerCreate, PassengerOut
from services.booking_service import add_passengers, delete_passenger, list_passengers

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/passengers", tags=["Passengers"])


class AddPassengersRequest(BaseModel):
    booking_id: str
    passengers: list[PassengerCreate]


# ---------------------------------------------------------------------------
# POST /passengers
# ---------------------------------------------------------------------------

@router.post("", response_model=list[PassengerOut], status_code=status.HTTP_201_CREATED)
async def add_passengers_endpoint(payload: AddPassengersRequest, user: CurrentUser):
    """
    Add one or more passengers to an existing booking.
    Call this immediately after creating a booking (before payment).
    """
    if not payload.passengers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one passenger is required.",
        )
    return await add_passengers(
        booking_uuid=payload.booking_id,
        user_id=user.id,
        passengers=payload.passengers,
    )


# ---------------------------------------------------------------------------
# GET /passengers/{booking_id}
# ---------------------------------------------------------------------------

@router.get("/{booking_id}", response_model=list[PassengerOut])
async def list_passengers_endpoint(booking_id: str, user: CurrentUser):
    """Return all passengers for a given booking."""
    return await list_passengers(booking_uuid=booking_id, user_id=user.id)


# ---------------------------------------------------------------------------
# DELETE /passengers/{passenger_id}
# ---------------------------------------------------------------------------

@router.delete("/{passenger_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_passenger_endpoint(passenger_id: str, user: CurrentUser):
    """Remove a passenger from a booking."""
    await delete_passenger(passenger_uuid=passenger_id, user_id=user.id)
