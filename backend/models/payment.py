# =============================================================================
# FILE: models/payment.py
# PURPOSE: Pydantic schemas for the payments endpoints.
# =============================================================================



from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Initiate payment
# ---------------------------------------------------------------------------

class PaymentInitiateRequest(BaseModel):
    booking_id: str  = Field(..., description="UUID of the booking to pay for")
    method:     str  = Field(..., pattern="^(jazzcash|easypaisa|card|bank_transfer)$")
    amount:     float = Field(..., gt=0)
    phone:      Optional[str] = Field(None, description="Mobile wallet phone number")
    email:      Optional[str] = Field(None, description="Override email for OTP delivery")

    class Config:
        json_schema_extra = {
            "example": {
                "booking_id": "550e8400-e29b-41d4-a716-446655440000",
                "method": "jazzcash",
                "amount": 18500.0,
                "phone": "03001234567",
            }
        }


class PaymentInitiateResponse(BaseModel):
    request_id:   str            # UUID of the payment_attempt row
    otp_required: bool           # True for jazzcash / easypaisa; False for card
    message:      str
    expires_at:   Optional[datetime] = None   # OTP expiry time (if otp_required)
    booking_id:   Optional[str] = None
    pnr:          Optional[str] = None
    transaction_id: Optional[str] = None


# ---------------------------------------------------------------------------
# Verify OTP
# ---------------------------------------------------------------------------

class OTPVerifyRequest(BaseModel):
    request_id: str = Field(..., description="request_id from /payments/initiate")
    otp:        str = Field(..., min_length=6, max_length=6, description="6-digit OTP")

    class Config:
        json_schema_extra = {
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "otp": "123456",
            }
        }


class OTPVerifyResponse(BaseModel):
    success:        bool
    booking_id:     str
    transaction_id: str
    pnr:            Optional[str] = None
    message:        str


# ---------------------------------------------------------------------------
# Payment history (GET /payments/{booking_id})
# ---------------------------------------------------------------------------

class PaymentAttemptOut(BaseModel):
    id:                 str
    booking_id:         str
    payment_method:     str
    amount:             float
    currency:           str
    status:             str
    provider_reference: Optional[str] = None
    metadata:           Optional[Any]  = None
    created_at:         Optional[datetime] = None
    updated_at:         Optional[datetime] = None

    class Config:
        from_attributes = True
