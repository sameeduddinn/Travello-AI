# =============================================================================
# FILE: models/train.py
# PURPOSE: Pydantic schemas for Pakistan Railways train search and booking.
# =============================================================================



from datetime import date as Date, datetime
from typing import Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Search request
# ---------------------------------------------------------------------------

class TrainSearchRequest(BaseModel):
    origin:      str  = Field(..., description="Origin city, e.g. Karachi")
    destination: str  = Field(..., description="Destination city, e.g. Lahore")
    date:        Date = Field(..., description="Travel date YYYY-MM-DD")
    passengers:  int  = Field(1, ge=1, le=6)

    class Config:
        json_schema_extra = {
            "example": {
                "origin": "Karachi",
                "destination": "Lahore",
                "date": "2024-05-15",
                "passengers": 1,
            }
        }


# ---------------------------------------------------------------------------
# Seat class availability within a train
# ---------------------------------------------------------------------------

class SeatClass(BaseModel):
    class_name:      str    # "Economy", "AC Standard", "AC Business", "Sleeper"
    class_code:      str    # "EC", "AC", "ACB", "SL"
    price_pkr:       float
    seats_available: int
    amenities:       list[str] = []  # e.g. ["Air Conditioning", "Reclining Seats"]


# ---------------------------------------------------------------------------
# Train offer (search result)
# ---------------------------------------------------------------------------

class TrainOffer(BaseModel):
    train_id:     str    # internal mock ID
    train_name:   str    # e.g. "Tezgam Express"
    train_number: str    # e.g. "7-Up"
    origin:       str
    destination:  str
    departure_at: datetime
    arrival_at:   datetime
    duration:     str    # human readable, e.g. "12h 30m"
    classes:      list[SeatClass]

    # Convenience — cheapest available class price
    @property
    def min_price_pkr(self) -> float:
        if not self.classes:
            return 0.0
        return min(c.price_pkr for c in self.classes if c.seats_available > 0)


class TrainSearchResponse(BaseModel):
    origin:      str
    destination: str
    date:        Date
    count:       int
    trains:      list[TrainOffer]
    notes:       Optional[str] = None  # road travel info for bus-only routes


# ---------------------------------------------------------------------------
# Booking request
# ---------------------------------------------------------------------------

class TrainBookRequest(BaseModel):
    train_id:        str = Field(..., description="train_id from search results")
    class_code:      str = Field(..., description="Seat class code, e.g. EC, AC, ACB")
    contact_email:   str
    contact_phone:   Optional[str] = None
    passengers:      int = Field(1, ge=1, le=6)

    # Fallback fields — used when train_id is not in cache (e.g. featured packages)
    train_name:      Optional[str] = None
    train_number:    Optional[str] = None
    origin:          Optional[str] = None
    destination:     Optional[str] = None
    departure_at:    Optional[str] = None  # ISO datetime string
    arrival_at:      Optional[str] = None  # ISO datetime string
    class_name:      Optional[str] = None
    total_price_pkr: Optional[float] = None
