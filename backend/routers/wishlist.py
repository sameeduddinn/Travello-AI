# =============================================================================
# FILE: routers/wishlist.py
# PREFIX: /wishlist
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // GET /wishlist
# Future<List<dynamic>> getWishlist() async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/wishlist'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as List<dynamic>;
#   // Each item: {id, item_type, item_data, created_at}
# }
#
# // POST /wishlist
# Future<Map<String, dynamic>> addToWishlist({
#   required String itemType,   // 'flight' | 'train' | 'hotel'
#   required Map<String, dynamic> itemData,  // the full offer object
# }) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/wishlist'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode({'item_type': itemType, 'item_data': itemData}),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // DELETE /wishlist/{itemId}
# Future<void> removeFromWishlist(String itemId) async {
#   await http.delete(
#     Uri.parse('$baseUrl/wishlist/$itemId'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
# }
# =============================================================================

import uuid
import logging
from typing import Any

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from core.auth import CurrentUser
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/wishlist", tags=["Wishlist"])

VALID_ITEM_TYPES = {"flight", "train", "hotel"}


class WishlistAddRequest(BaseModel):
    item_type: str
    item_data: dict[str, Any]


class WishlistItemOut(BaseModel):
    id: str
    user_id: str
    item_type: str
    item_data: dict[str, Any]
    created_at: str | None = None


# ---------------------------------------------------------------------------
# GET /wishlist
# ---------------------------------------------------------------------------

@router.get("", response_model=list[WishlistItemOut])
async def list_wishlist(user: CurrentUser):
    """Return all wishlist items for the authenticated user, newest first."""
    result = (
        supabase_admin.table("wishlist")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", desc=True)
        .execute()
    )
    return [
        WishlistItemOut(
            id=str(r["id"]),
            user_id=str(r["user_id"]),
            item_type=r["item_type"],
            item_data=r["item_data"] or {},
            created_at=str(r.get("created_at", "")),
        )
        for r in (result.data or [])
    ]


# ---------------------------------------------------------------------------
# POST /wishlist
# ---------------------------------------------------------------------------

@router.post("", response_model=WishlistItemOut, status_code=status.HTTP_201_CREATED)
async def add_to_wishlist(payload: WishlistAddRequest, user: CurrentUser):
    """Save a flight, train, or hotel offer to the user's wishlist."""
    if payload.item_type not in VALID_ITEM_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"item_type must be one of: {', '.join(VALID_ITEM_TYPES)}",
        )

    row = {
        "id": str(uuid.uuid4()),
        "user_id": user.id,
        "item_type": payload.item_type,
        "item_data": payload.item_data,
    }

    result = supabase_admin.table("wishlist").insert(row).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to add to wishlist.")

    r = result.data[0]
    return WishlistItemOut(
        id=str(r["id"]),
        user_id=str(r["user_id"]),
        item_type=r["item_type"],
        item_data=r["item_data"] or {},
        created_at=str(r.get("created_at", "")),
    )


# ---------------------------------------------------------------------------
# DELETE /wishlist/{item_id}
# ---------------------------------------------------------------------------

@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_wishlist(item_id: str, user: CurrentUser):
    """Remove an item from the wishlist."""
    result = (
        supabase_admin.table("wishlist")
        .delete()
        .eq("id", item_id)
        .eq("user_id", user.id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Wishlist item not found.",
        )
