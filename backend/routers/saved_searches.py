# =============================================================================
# FILE: routers/saved_searches.py
# PREFIX: /saved-searches
# PURPOSE: Let users save and retrieve flight/train/hotel search queries.
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# // POST /saved-searches  — save a search
# Future<Map<String, dynamic>> saveSearch(Map<String, dynamic> query) async {
#   final res = await http.post(
#     Uri.parse('$baseUrl/saved-searches'),
#     headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
#     body: jsonEncode(query),
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // GET /saved-searches  — list my saved searches
# Future<List<dynamic>> getSavedSearches() async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/saved-searches'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as List<dynamic>;
# }
#
# // DELETE /saved-searches/{id}
# Future<void> deleteSavedSearch(String id) async {
#   await http.delete(
#     Uri.parse('$baseUrl/saved-searches/$id'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
# }
# =============================================================================

import logging
import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from core.auth import CurrentUser
from core.supabase_client import supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/saved-searches", tags=["Saved Searches"])


class SaveSearchRequest(BaseModel):
    search_type:   str          # 'flight', 'train', 'hotel'
    search_params: dict[str, Any]  # free-form query params


# ---------------------------------------------------------------------------
# POST /saved-searches
# ---------------------------------------------------------------------------

@router.post("/", status_code=status.HTTP_201_CREATED)
async def save_search(payload: SaveSearchRequest, user: CurrentUser) -> dict[str, Any]:
    """Save a search query so the user can quickly repeat it later."""
    row = {
        "id": str(uuid.uuid4()),
        "user_id": user.id,
        "search_type": payload.search_type,
        "search_params": payload.search_params,
    }
    try:
        supabase_admin.table("saved_searches").insert(row).execute()
    except Exception as exc:
        logger.error("Failed to save search: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to save search.")

    return {"id": row["id"], "message": "Search saved."}


# ---------------------------------------------------------------------------
# GET /saved-searches
# ---------------------------------------------------------------------------

@router.get("/")
async def list_saved_searches(user: CurrentUser) -> list[dict[str, Any]]:
    """Return all saved searches for the current user, newest first."""
    try:
        result = (
            supabase_admin.table("saved_searches")
            .select("*")
            .eq("user_id", user.id)
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
    except Exception as exc:
        logger.error("Failed to fetch saved searches: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to fetch saved searches.")

    return result.data or []


# ---------------------------------------------------------------------------
# DELETE /saved-searches/{id}
# ---------------------------------------------------------------------------

@router.delete("/{search_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_saved_search(search_id: str, user: CurrentUser) -> None:
    """Delete a saved search by ID. Only the owner can delete it."""
    try:
        result = (
            supabase_admin.table("saved_searches")
            .delete()
            .eq("id", search_id)
            .eq("user_id", user.id)
            .execute()
        )
    except Exception as exc:
        logger.error("Failed to delete saved search: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to delete saved search.")

    if not result.data:
        raise HTTPException(status_code=404, detail="Saved search not found.")
