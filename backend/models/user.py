# =============================================================================
# PURPOSE: Pydantic schemas for user profile and preferences endpoints.
# =============================================================================



from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


# Profile

class ProfileUpdate(BaseModel):
    """PUT /auth/profile — fields the user may update."""
    full_name:       Optional[str]  = Field(None, max_length=120)
    phone:           Optional[str]  = Field(None, max_length=20)
    date_of_birth:   Optional[date] = None
    gender:          Optional[str]  = Field(None, pattern="^(male|female|other)$")
    nationality:     Optional[str]  = Field(None, max_length=60)
    cnic:            Optional[str]  = Field(None, max_length=15)
    passport_number: Optional[str]  = Field(None, max_length=20)
    avatar_url:      Optional[str]  = Field(None, max_length=500)


class ProfileOut(BaseModel):
    """Response shape for a user profile."""
    id:              str
    full_name:       Optional[str]  = None
    phone:           Optional[str]  = None
    date_of_birth:   Optional[date] = None
    gender:          Optional[str]  = None
    nationality:     Optional[str]  = None
    cnic:            Optional[str]  = None
    passport_number: Optional[str]  = None
    avatar_url:      Optional[str]  = None
    created_at:      Optional[datetime] = None
    updated_at:      Optional[datetime] = None

    class Config:
        from_attributes = True


# Preferences

class PreferencesUpdate(BaseModel):
    """PUT /auth/preferences."""
    origin_city: Optional[str] = Field(None, max_length=60)
    currency:    Optional[str] = Field(None, max_length=10)
    theme:       Optional[str] = Field(None, pattern="^(light|dark|system)$")
    language:    Optional[str] = Field(None, max_length=10)


class PreferencesOut(BaseModel):
    """Response shape for user preferences."""
    user_id:     str
    origin_city: Optional[str] = "Karachi"
    currency:    Optional[str] = "PKR"
    theme:       Optional[str] = "light"
    language:    Optional[str] = "en"

    class Config:
        from_attributes = True


# Combined /auth/me response

class MeOut(BaseModel):
    """GET /auth/me response — profile + preferences."""
    profile:     ProfileOut
    preferences: Optional[PreferencesOut] = None
