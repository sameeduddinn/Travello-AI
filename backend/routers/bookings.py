# =============================================================================
# FILE: routers/bookings.py
# PREFIX: /bookings
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // GET /bookings  (list all bookings, paginated)
# Future<Map<String, dynamic>> getBookings({
#   int page = 1,
#   int perPage = 20,
#   String? status,       // 'pending'|'paid'|'confirmed'|'cancelled'
#   String? bookingType,  // 'flight'|'train'|'hotel'
# }) async {
#   final params = {
#     'page': page.toString(),
#     'per_page': perPage.toString(),
#     if (status != null) 'status': status,
#     if (bookingType != null) 'booking_type': bookingType,
#   };
#   final res = await http.get(
#     Uri.parse('$baseUrl/bookings').replace(queryParameters: params),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
#   // response keys: total, page, per_page, bookings → List
# }
#
# // GET /bookings/{bookingId}
# Future<Map<String, dynamic>> getBookingDetail(String bookingId) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/bookings/$bookingId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // PUT /bookings/{bookingId}/cancel
# Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
#   final res = await http.put(
#     Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // GET /bookings/{bookingId}/ticket
# Future<Map<String, dynamic>> getTicket(String bookingId) async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/bookings/$bookingId/ticket'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
#   // Use this response to render a PDF ticket or ticket card in Flutter
# }
# =============================================================================

import logging

from fastapi import APIRouter, Query, status

from core.auth import CurrentUser
from models.booking import BookingListResponse, BookingOut, TicketOut
from services.booking_service import (
    cancel_booking,
    delete_booking,
    get_booking,
    get_ticket,
    list_bookings,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/bookings", tags=["Bookings"])


# ---------------------------------------------------------------------------
# GET /bookings
# ---------------------------------------------------------------------------

@router.get("", response_model=BookingListResponse)
async def list_bookings_endpoint(
    user: CurrentUser,
    page: int = Query(1, ge=1, description="Page number"),
    per_page: int = Query(20, ge=1, le=100, description="Items per page"),
    status_filter: str | None = Query(
        None, alias="status",
        description="Filter by status: pending, paid, confirmed, cancelled, refunded",
    ),
    booking_type: str | None = Query(
        None, description="Filter by type: flight, train, hotel"
    ),
):
    """
    Return a paginated list of all bookings for the authenticated user.
    Newest first. Optionally filter by status or booking type.
    """
    bookings, total = await list_bookings(
        user_id=user.id,
        page=page,
        per_page=per_page,
        status_filter=status_filter,
        booking_type=booking_type,
    )

    return BookingListResponse(
        total=total,
        page=page,
        per_page=per_page,
        bookings=bookings,
    )


# ---------------------------------------------------------------------------
# GET /bookings/{booking_id}
# ---------------------------------------------------------------------------

@router.get("/{booking_id}", response_model=BookingOut)
async def get_booking_endpoint(booking_id: str, user: CurrentUser):
    """
    Return a single booking including all its passengers.
    `booking_id` here is the UUID (not the human-readable TRV-FL-... code).
    """
    return await get_booking(booking_uuid=booking_id, user_id=user.id)


# ---------------------------------------------------------------------------
# PUT /bookings/{booking_id}/cancel
# ---------------------------------------------------------------------------

@router.put("/{booking_id}/cancel", response_model=BookingOut)
async def cancel_booking_endpoint(booking_id: str, user: CurrentUser):
    """
    Cancel a booking. Sets status to 'cancelled'.
    Only allowed if the booking is not already cancelled or refunded.
    Note: Payment refunds are not processed in this demo.
    """
    return await cancel_booking(booking_uuid=booking_id, user_id=user.id)


# ---------------------------------------------------------------------------
# DELETE /bookings/{booking_id}  — remove cancelled booking from history
# ---------------------------------------------------------------------------

@router.delete("/{booking_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_booking_endpoint(booking_id: str, user: CurrentUser):
    """
    Permanently delete a booking from the user's history.
    Only allowed for bookings with status 'cancelled' or 'refunded'.
    """
    await delete_booking(booking_uuid=booking_id, user_id=user.id)


# ---------------------------------------------------------------------------
# GET /bookings/{booking_id}/ticket
# ---------------------------------------------------------------------------

@router.get("/{booking_id}/ticket", response_model=TicketOut)
async def get_ticket_endpoint(booking_id: str, user: CurrentUser):
    """
    Return structured ticket data for Flutter to render as a ticket card or PDF.
    Includes: PNR, route, times, passengers, amount, and booking reference.

    Flutter usage tip:
      Use the `pdf` package (pub.dev/packages/pdf) with this data to generate
      a shareable ticket PDF directly on the device.
    """
    return await get_ticket(booking_uuid=booking_id, user_id=user.id)
