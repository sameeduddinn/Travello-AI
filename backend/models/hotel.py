# =============================================================================
# PURPOSE: Pydantic schemas for hotel search, detail, and booking.
# =============================================================================



from datetime import date
from typing import Any, Optional

from pydantic import BaseModel, Field


# Search request

class HotelSearchRequest(BaseModel):
    city:      str  = Field(..., description="City name, e.g. Lahore")
    check_in:  date = Field(..., description="Check-in date YYYY-MM-DD")
    check_out: date = Field(..., description="Check-out date YYYY-MM-DD")
    guests:    int  = Field(1, ge=1, le=10)
    rooms:     int  = Field(1, ge=1, le=5)

    class Config:
        json_schema_extra = {
            "example": {
                "city": "Lahore",
                "check_in": "2024-05-20",
                "check_out": "2024-05-22",
                "guests": 2,
                "rooms": 1,
            }
        }


# Room offer within a hotel

class RoomOffer(BaseModel):
    room_id:              str
    room_type:            str              # "Standard", "Deluxe", "Suite"
    bed_type:             str              # "King", "Twin", "Double"
    price_per_night_pkr:  float
    max_guests:           int
    is_refundable:        bool = True
    amenities:            list[str] = []   # ["WiFi", "TV", "AC", ...]
    rooms_available:      int = 10         # live availability count
    description:          str = ""
    size_sqft:            Optional[int] = None
    has_city_view:        bool = False
    has_balcony:          bool = False
    breakfast_included:   bool = False
    cancellation_policy:  str = ""


# Hotel offer (search result)

class HotelOffer(BaseModel):
    hotel_id:    str
    name:        str
    star_rating: float    # 1.0 – 5.0
    address:     str
    city:        str
    latitude:    Optional[float] = None
    longitude:   Optional[float] = None
    images:      list[str] = []          # URLs (from RapidAPI)
    amenities:   list[str] = []          # ["Pool", "Gym", "Restaurant", ...]
    rooms:       list[RoomOffer]
    review_score: Optional[float] = None  # out of 10
    review_count: Optional[int]   = None

    # Convenience - cheapest room per night
    @property
    def min_price_per_night_pkr(self) -> float:
        if not self.rooms:
            return 0.0
        return min(r.price_per_night_pkr for r in self.rooms)


class HotelSearchResponse(BaseModel):
    city:      str
    check_in:  date
    check_out: date
    nights:    int
    count:     int
    hotels:    list[HotelOffer]


# Booking request

class HotelBookRequest(BaseModel):
    hotel_id:            str  = Field(..., description="hotel_id from search results")
    room_id:             str  = Field(..., description="room_id from hotel detail")
    city:                Optional[str]   = Field(None, description="City used during hotel search")
    check_in:            date
    check_out:           date
    guests:              int  = Field(1, ge=1, le=10)
    rooms:               int  = Field(1, ge=1, le=5)
    contact_email:       str
    contact_phone:       Optional[str]   = None
    # Optional fallback fields for featured packages (no prior search required)
    hotel_name:          Optional[str]   = None
    star_rating:         Optional[float] = None
    price_per_night_pkr: Optional[float] = None
    room_type:           Optional[str]   = None
