# =============================================================================
# FILE: core/auth.py
# PURPOSE: FastAPI dependency that verifies Supabase JWTs on every protected
#          route and returns the authenticated user's ID + email.
#
# How Supabase JWTs work:
#   - The Flutter app calls supabase.auth.signIn(...) and gets an access_token.
#   - Flutter sends: Authorization: Bearer <access_token> on every API call.
#   - We verify the token signature using SUPABASE_JWT_SECRET (HS256).
#   - The token payload contains: sub (user UUID), email, role, exp, etc.
#
# Usage in any router:
#   from core.auth import get_current_user, CurrentUser
#   @router.get("/me")
#   async def me(user: CurrentUser = Depends(get_current_user)):
#       return {"user_id": user.id}
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from core.config import settings

# HTTPBearer extracts the token from "Authorization: Bearer <token>" header.
# auto_error=True means FastAPI returns 403 automatically if the header is missing.
_bearer_scheme = HTTPBearer(auto_error=True)


@dataclass
class AuthUser:
    """Minimal user info extracted from a verified Supabase JWT."""
    id: str          # UUID string — matches auth.users.id in Supabase
    email: str | None
    phone: str | None
    role: str        # 'authenticated' for normal users


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(_bearer_scheme)],
) -> AuthUser:
    """
    FastAPI dependency — verify Bearer JWT and return AuthUser.

    Raises HTTP 401 if:
      - Token is missing / malformed
      - Signature is invalid
      - Token is expired
    """
    token = credentials.credentials

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication token.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # ── Debug bypass ──────────────────────────────────────────────────────────
    # When DEBUG=True and SUPABASE_JWT_SECRET is not yet configured, decode
    # without signature verification so local dev/testing works out of the box.
    # NEVER leave this enabled in production (set DEBUG=False in .env).
    # ─────────────────────────────────────────────────────────────────────────
    _jwt_secret = settings.SUPABASE_JWT_SECRET
    _is_configured = bool(_jwt_secret) and not _jwt_secret.startswith("REPLACE_WITH_")
    skip_verify = settings.DEBUG and not _is_configured

    try:
        decode_options: dict = {"verify_aud": False}
        if skip_verify:
            decode_options["verify_signature"] = False

        payload = jwt.decode(
            token,
            _jwt_secret if _is_configured else "dummy-secret-for-debug",
            algorithms=["HS256"],
            options=decode_options,
        )
    except JWTError:
        raise credentials_exception

    user_id: str | None = payload.get("sub")
    if not user_id:
        raise credentials_exception

    role: str = payload.get("role", "")
    if role not in ("authenticated", "service_role"):
        # Anon tokens (role == 'anon') are not allowed on protected routes
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Anonymous access is not permitted on this endpoint.",
        )

    return AuthUser(
        id=user_id,
        email=payload.get("email"),
        phone=payload.get("phone"),
        role=role,
    )


# Convenient type alias — use in route signatures for IDE autocomplete
CurrentUser = Annotated[AuthUser, Depends(get_current_user)]
