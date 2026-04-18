# =============================================================================
# FILE: models/flight.py
# PURPOSE: Pydantic schemas for flight search, offer detail, and booking.
# =============================================================================



from datetime import date as Date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Search request
# ---------------------------------------------------------------------------

class FlightSearchRequest(BaseModel):
    origin:       str = Field(..., min_length=3, max_length=3,
                              description="IATA airport code, e.g. KHI")
    destination:  str = Field(..., min_length=3, max_length=3,
                              description="IATA airport code, e.g. LHE")
    date:         Date = Field(..., description="Departure date YYYY-MM-DD")
    return_date:  Optional[Date] = Field(None, description="Return date for round-trip")
    adults:       int  = Field(1, ge=1, le=9)
    cabin_class:  str  = Field("ECONOMY",
                               pattern="^(ECONOMY|PREMIUM_ECONOMY|BUSINESS|FIRST)$")

    class Config:
        json_schema_extra = {
            "example": {
                "origin": "KHI",
                "destination": "LHE",
                "date": "2024-05-15",
                "adults": 1,
                "cabin_class": "ECONOMY",
            }
        }


# ---------------------------------------------------------------------------
# Segment / itinerary building blocks
# ---------------------------------------------------------------------------

class FlightSegment(BaseModel):
    """One leg of a flight (departure → arrival at one airport)."""
    carrier_code:      str
    flight_number:     str
    departure_airport: str
    arrival_airport:   str
    departure_time:    datetime
    arrival_time:      datetime
    duration:          str        # ISO 8601 duration, e.g. "PT2H30M"
    cabin_class:       str
    aircraft_code:     Optional[str] = None


class FlightItinerary(BaseModel):
    """One direction of travel — could have 1 or more segments (layovers)."""
    duration:      str
    segments:      list[FlightSegment]


# ---------------------------------------------------------------------------
# Offer (search result)
# ---------------------------------------------------------------------------

class FlightOffer(BaseModel):
    """Single flight offer returned from Amadeus search."""
    offer_id:          str           # Amadeus offer ID (used for pricing)
    itineraries:       list[FlightItinerary]
    total_price_pkr:   float
    total_price_usd:   Optional[float] = None
    currency:          str = "PKR"
    seats_available:   Optional[int]  = None
    is_refundable:     bool = False
    baggage_allowance: Optional[str]  = None  # e.g. "23kg"
    raw:               Optional[Any]  = None  # Full Amadeus payload (not sent to Flutter)

    class Config:
        json_schema_extra = {
            "example": {
                "offer_id": "1",
                "total_price_pkr": 18500.0,
                "currency": "PKR",
            }
        }


class FlightSearchResponse(BaseModel):
    origin:      str
    destination: str
    date:        Date
    count:       int
    offers:      list[FlightOffer]


# ---------------------------------------------------------------------------
# Booking request
# ---------------------------------------------------------------------------

class FlightBookRequest(BaseModel):
    offer_id:      str   = Field(..., description="Amadeus offer ID from search results")
    contact_email: str   = Field(..., description="Email for booking confirmation")
    contact_phone: Optional[str] = None
    # Passenger info is submitted separately via /passengers endpoint
    # so we keep this minimal
