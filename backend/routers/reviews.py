# =============================================================================
# PREFIX: /reviews
# PURPOSE: Post-booking reviews — one review per completed booking.
# =============================================================================


import logging
from typing import Any, Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/reviews", tags=["Reviews"])


class ReviewRequest(BaseModel):
    booking_id: str
    rating:     int     = Field(..., ge=1, le=5, description="Star rating 1-5")
    comment:    Optional[str] = None


# POST /reviews

@router.post("", status_code=status.HTTP_201_CREATED)
async def submit_review(payload: ReviewRequest, user: CurrentUser) -> dict[str, Any]:
    """
    Submit a review for a completed booking.
    The booking must belong to the current user and have status 'paid' or 'confirmed'.
    """
    # Verify booking belongs to user and is completed
    try:
        booking = (
            supabase_admin.table("bookings")
            .select("id, status")
            .eq("id", payload.booking_id)
            .eq("user_id", user.id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Booking not found.")

    if not booking.data:
        raise HTTPException(status_code=404, detail="Booking not found.")

    if booking.data.get("status") not in ("paid", "confirmed"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can only review a completed booking.",
        )

    try:
        existing = (
            supabase_admin.table("reviews")
            .select("id")
            .eq("booking_id", payload.booking_id)
            .eq("user_id", user.id)
            .execute()
        )
    except Exception as exc:
        logger.error("Failed to check existing review: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to save review.")

    try:
        if existing.data:
            review_id = existing.data[0]["id"]
            supabase_admin.table("reviews").update(
                {"rating": payload.rating, "comment": payload.comment}
            ).eq("id", review_id).execute()
        else:
            result = supabase_admin.table("reviews").insert({
                "user_id": user.id,
                "booking_id": payload.booking_id,
                "rating": payload.rating,
                "comment": payload.comment,
            }).execute()
            review_id = result.data[0]["id"] if result.data else ""
    except Exception as exc:
        logger.error("Failed to save review: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to save review.")

    return {"id": review_id, "message": "Review submitted. Thank you!"}


# GET /reviews/booking/{booking_id}

@router.get("/booking/{booking_id}")
async def get_review_for_booking(booking_id: str, user: CurrentUser) -> dict[str, Any]:
    """Return the review for a specific booking (if one exists)."""
    try:
        result = (
            supabase_admin.table("reviews")
            .select("*")
            .eq("booking_id", booking_id)
            .eq("user_id", user.id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="No review found for this booking.")

    if not result.data:
        raise HTTPException(status_code=404, detail="No review found for this booking.")

    return result.data


# GET /reviews/my

@router.get("/my")
async def get_my_reviews(user: CurrentUser) -> list[dict[str, Any]]:
    """Return all reviews submitted by the current user, newest first."""
    try:
        result = (
            supabase_admin.table("reviews")
            .select("*")
            .eq("user_id", user.id)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception as exc:
        logger.error("Failed to fetch reviews: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch reviews.")

    return result.data or []
