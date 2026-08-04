# FILE: models/booking.py
# PURPOSE: Pydantic schemas for the bookings and passengers endpoints.



from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


# Passenger schemas (used by both bookings and /passengers router)

class PassengerCreate(BaseModel):
    title:           Optional[str]  = Field(None, pattern="^(Mr|Mrs|Ms|Dr|Prof)$")
    first_name:      str            = Field(..., min_length=1, max_length=60)
    last_name:       str            = Field(..., min_length=1, max_length=60)
    date_of_birth:   Optional[date] = None
    gender:          Optional[str]  = Field(None, pattern="^(male|female)$")
    nationality:     Optional[str]  = Field("Pakistani", max_length=60)
    cnic:            Optional[str]  = Field(None, max_length=15)
    passport_number: Optional[str]  = Field(None, max_length=20)
    seat_number:     Optional[str]  = None
    passenger_type:  str            = Field("adult",
                                            pattern="^(adult|child|infant)$")


class PassengerOut(PassengerCreate):
    id:         str
    booking_id: str
    user_id:    str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Booking list / detail

class BookingOut(BaseModel):
    id:            str
    user_id:       str
    booking_id:    str             # human-readable: TRV-FL-20240417-A1B2
    booking_type:  str             # flight | train | hotel
    pnr:           Optional[str]   = None
    transaction_id: Optional[str]  = None
    contact_email: str
    contact_phone: Optional[str]   = None
    total_amount:  float
    currency:      str             = "PKR"
    status:        str             # pending | paid | confirmed | cancelled | refunded
    origin:        Optional[str]   = None
    destination:   Optional[str]   = None
    departure_at:  Optional[datetime] = None
    arrival_at:    Optional[datetime] = None
    hotel_name:    Optional[str]   = None
    check_in:      Optional[date]  = None
    check_out:     Optional[date]  = None
    raw_payload:   Optional[Any]   = None
    passengers:    list[PassengerOut] = []
    created_at:    Optional[datetime] = None
    updated_at:    Optional[datetime] = None

    class Config:
        from_attributes = True


class BookingListResponse(BaseModel):
    total:    int
    page:     int
    per_page: int
    bookings: list[BookingOut]


# Ticket (structured for Flutter PDF/card rendering)

class TicketOut(BaseModel):
    """
    GET /bookings/{booking_id}/ticket
    Returns a structured payload that Flutter uses to render a ticket card or PDF.
    """
    booking_id:    str
    pnr:           Optional[str]  = None
    booking_type:  str
    status:        str
    contact_email: str
    contact_phone: Optional[str] = None
    total_amount:  float
    currency:      str

    # Flight / Train specific
    origin:       Optional[str]      = None
    destination:  Optional[str]      = None
    departure_at: Optional[datetime] = None
    arrival_at:   Optional[datetime] = None
    duration:     Optional[str]      = None

    # Hotel specific
    hotel_name:   Optional[str]  = None
    hotel_address: Optional[str] = None
    check_in:     Optional[date] = None
    check_out:    Optional[date] = None
    nights:       Optional[int]  = None

    passengers:   list[PassengerOut] = []
    issued_at:    datetime           = Field(default_factory=datetime.utcnow)
