# PURPOSE: Pydantic schemas for flight search, offer detail, and booking.

from datetime import date as Date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


# Search request

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


# Segment / itinerary building blocks

class FlightSegment(BaseModel):
    """One leg of a flight (departure → arrival at one airport)."""
    carrier_code:      str
    # Human airline name for this carrier code. The code alone is NOT enough:
    # the agent used to show only the code, leaving the model to translate it
    # from memory — it rendered AirSial (ER) as "Airblue" and Airblue (PA) as
    # "PIA", and that invented name reached a paid booking and its ticket.
    # Optional so any caller constructing a segment without it still validates.
    carrier_name:      Optional[str] = None
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


# Offer (search result)

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


# Booking request

class FlightBookRequest(BaseModel):
    offer_id:        str   = Field(..., description="Amadeus offer ID from search results")
    contact_email:   str   = Field(..., description="Email for booking confirmation")
    contact_phone:   Optional[str] = None
    # Optional fallback fields — used when offer_id is not in cache (e.g. featured packages)
    origin:          Optional[str]   = None
    destination:     Optional[str]   = None
    departure_date:  Optional[str]   = None   # "YYYY-MM-DD"
    departure_time:  Optional[str]   = None   # "HH:MM"
    arrival_time:    Optional[str]   = None   # "HH:MM"
    airline_name:    Optional[str]   = None
    airline_code:    Optional[str]   = None
    cabin_class:     Optional[str]   = None
    total_price_pkr: Optional[float] = None
    is_refundable:   Optional[bool]  = False
    duration:        Optional[str]   = None
    facilities:      Optional[dict]  = None  # car transfer selections from facilities screen
