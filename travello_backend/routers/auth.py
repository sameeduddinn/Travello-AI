# =============================================================================
# FILE: routers/auth.py
# PREFIX: /auth
# =============================================================================
#
# FLUTTER INTEGRATION (Flutter 3.28.3 / Dart 3.10.1)
# -------------------------------------------------------
# Add to pubspec.yaml:  http: ^1.2.0
#
# import 'dart:convert';
# import 'package:http/http.dart' as http;
# import 'package:supabase_flutter/supabase_flutter.dart';
#
# const String baseUrl = 'https://your-backend.onrender.com';
#
# String get _token =>
#     Supabase.instance.client.auth.currentSession!.accessToken;
#
# // GET /auth/me
# Future<Map<String, dynamic>> getMe() async {
#   final res = await http.get(
#     Uri.parse('$baseUrl/auth/me'),
#     headers: {'Authorization': 'Bearer $_token'},
#   );
#   return jsonDecode(res.body) as Map<String, dynamic>;
# }
#
# // PUT /auth/profile
# Future<void> updateProfile(Map<String, dynamic> data) async {
#   await http.put(
#     Uri.parse('$baseUrl/auth/profile'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode(data),
#   );
# }
#
# // PUT /auth/preferences
# Future<void> updatePreferences(Map<String, dynamic> data) async {
#   await http.put(
#     Uri.parse('$baseUrl/auth/preferences'),
#     headers: {
#       'Authorization': 'Bearer $_token',
#       'Content-Type': 'application/json',
#     },
#     body: jsonEncode(data),
#   );
# }
# =============================================================================

from fastapi import APIRouter, HTTPException, status

from core.auth import CurrentUser
from core.supabase_client import supabase_admin
from models.user import MeOut, PreferencesOut, PreferencesUpdate, ProfileOut, ProfileUpdate

router = APIRouter(prefix="/auth", tags=["Auth"])


# ---------------------------------------------------------------------------
# GET /auth/me
# ---------------------------------------------------------------------------

@router.get("/me", response_model=MeOut)
async def get_me(user: CurrentUser):
    """
    Return the authenticated user's profile and preferences.
    If no profile row exists yet, auto-creates one (handles race conditions
    where the trigger hasn't fired yet after a new sign-up).
    """
    # Fetch profile
    profile_res = (
        supabase_admin.table("profiles")
        .select("*")
        .eq("id", user.id)
        .execute()
    )

    if not profile_res.data:
        # Auto-create profile row (trigger may not have fired for very new users)
        new_profile = {"id": user.id, "full_name": None}
        supabase_admin.table("profiles").insert(new_profile).execute()
        profile_data = {"id": user.id}
    else:
        profile_data = profile_res.data[0]

    # Fetch preferences
    prefs_res = (
        supabase_admin.table("user_preferences")
        .select("*")
        .eq("user_id", user.id)
        .execute()
    )

    if not prefs_res.data:
        # Auto-create preferences row
        new_prefs = {"user_id": user.id}
        supabase_admin.table("user_preferences").insert(new_prefs).execute()
        prefs_data = {"user_id": user.id}
    else:
        prefs_data = prefs_res.data[0]

    return MeOut(
        profile=ProfileOut.model_validate(
            {**profile_data, "id": str(profile_data.get("id", user.id))}
        ),
        preferences=PreferencesOut.model_validate(
            {**prefs_data, "user_id": str(prefs_data.get("user_id", user.id))}
        ),
    )


# ---------------------------------------------------------------------------
# PUT /auth/profile
# ---------------------------------------------------------------------------

@router.put("/profile", response_model=ProfileOut)
async def update_profile(payload: ProfileUpdate, user: CurrentUser):
    """
    Update the authenticated user's profile.
    Only provided (non-None) fields are updated.
    """
    updates = payload.model_dump(exclude_none=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided to update.",
        )

    # Serialize date to ISO string for Supabase
    if "date_of_birth" in updates and updates["date_of_birth"]:
        updates["date_of_birth"] = str(updates["date_of_birth"])

    result = (
        supabase_admin.table("profiles")
        .update(updates)
        .eq("id", user.id)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found.")

    row = result.data[0]
    return ProfileOut.model_validate({**row, "id": str(row.get("id", user.id))})


# ---------------------------------------------------------------------------
# PUT /auth/preferences
# ---------------------------------------------------------------------------

@router.put("/preferences", response_model=PreferencesOut)
async def update_preferences(payload: PreferencesUpdate, user: CurrentUser):
    """
    Update the authenticated user's in-app preferences.
    Uses upsert so it works even if the preferences row doesn't exist yet.
    """
    updates = payload.model_dump(exclude_none=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided to update.",
        )

    updates["user_id"] = user.id

    result = (
        supabase_admin.table("user_preferences")
        .upsert(updates, on_conflict="user_id")
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to update preferences.")

    row = result.data[0]
    return PreferencesOut.model_validate(
        {**row, "user_id": str(row.get("user_id", user.id))}
    )
