
# FILE: core/auth.py
# PURPOSE: FastAPI dependency that verifies Supabase JWTs on every protected
#          route and returns the authenticated user's ID + email.


from __future__ import annotations

import base64
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from core.config import settings


def _load_jwt_key(secret: str) -> bytes | str:
    """
    Supabase shows the JWT secret as base64-encoded bytes in the dashboard.
    python-jose needs the raw bytes for HS256 to match Supabase's signing.
    Try base64-decode first; fall back to raw UTF-8 string if it fails.
    """
    try:
        decoded = base64.b64decode(secret)
        if len(decoded) >= 32:   # sanity: must be at least 256-bit key
            return decoded
    except Exception:
        pass
    return secret

# HTTPBearer extracts the token from "Authorization: Bearer <token>" header.
# auto_error=True means FastAPI returns 403 automatically if the header is missing.
_bearer_scheme = HTTPBearer(auto_error=True)


@dataclass
class AuthUser:
    """Minimal user info extracted from a verified Supabase JWT."""
    id: str          # UUID string - matches auth.users.id in Supabase
    email: str | None
    phone: str | None
    role: str        # 'authenticated' for normal users


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(_bearer_scheme)],
) -> AuthUser:
    """
    FastAPI dependency - verify Bearer JWT and return AuthUser.

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

    # - Debug bypass
    # NEVER leave this enabled in production (set DEBUG=False in .env).
    _jwt_secret = settings.SUPABASE_JWT_SECRET

    try:
        if settings.DEBUG:
   
            payload = jwt.decode(
                token,
                options={"verify_signature": False, "verify_aud": False, "verify_exp": False},
                algorithms=["HS256"],
                key="",
            )
        else:
            # Production: full HS256 verification with base64-decoded key
            jwt_key = _load_jwt_key(_jwt_secret)
            payload = jwt.decode(
                token,
                jwt_key,
                algorithms=["HS256"],
                options={"verify_aud": False},
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
