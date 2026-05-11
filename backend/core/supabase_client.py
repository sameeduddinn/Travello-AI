# =============================================================================
# FILE: core/supabase_client.py
# PURPOSE: Two Supabase clients:
#   - supabase_anon    → for public/user-scoped operations (respects RLS)
#   - supabase_admin   → uses service role key (bypasses RLS) - server-side only
#

#
# NOTE: Clients are created lazily — the app starts even without Supabase keys
#       configured, falling back gracefully to mock data in search endpoints.
# =============================================================================

from __future__ import annotations

import logging
from typing import Optional

from supabase import create_client, Client
from core.config import settings

logger = logging.getLogger(__name__)

_anon_client: Optional[Client] = None
_admin_client: Optional[Client] = None


def _create_anon_client() -> Optional[Client]:
    """
    Anon client — uses the anon key.
    RLS policies are enforced. Returns None if Supabase is not configured.
    """
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        logger.warning("Supabase anon client not initialised — SUPABASE_URL/ANON_KEY missing.")
        return None
    try:
        return create_client(
            supabase_url=settings.SUPABASE_URL,
            supabase_key=settings.SUPABASE_ANON_KEY,
        )
    except Exception as exc:
        logger.warning("Failed to create Supabase anon client: %s", exc)
        return None


def _create_admin_client() -> Optional[Client]:
    """
    Admin / service-role client — bypasses ALL RLS policies.
    Use ONLY on the server side. Returns None if not configured.
    """
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
        logger.warning("Supabase admin client not initialised — SUPABASE_URL/SERVICE_ROLE_KEY missing.")
        return None
    try:
        return create_client(
            supabase_url=settings.SUPABASE_URL,
            supabase_key=settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    except Exception as exc:
        logger.warning("Failed to create Supabase admin client: %s", exc)
        return None


def get_anon_client() -> Optional[Client]:
    global _anon_client
    if _anon_client is None:
        _anon_client = _create_anon_client()
    return _anon_client


def get_admin_client() -> Optional[Client]:
    global _admin_client
    if _admin_client is None:
        _admin_client = _create_admin_client()
    return _admin_client


# Lazy proxies — accessing these triggers client creation on first use.
# Existing code that does `from core.supabase_client import supabase_anon` continues to work,
# but now the clients are created lazily instead of at import time.
class _LazyClient:
    """Transparent proxy that initialises the real client on first attribute access."""
    def __init__(self, factory):
        object.__setattr__(self, '_factory', factory)
        object.__setattr__(self, '_client', None)

    def _get(self):
        c = object.__getattribute__(self, '_client')
        if c is None:
            c = object.__getattribute__(self, '_factory')()
            object.__setattr__(self, '_client', c)
        return c

    def __getattr__(self, name):
        return getattr(self._get(), name)

    def __bool__(self):
        return self._get() is not None


supabase_anon: Client = _LazyClient(get_anon_client)   # type: ignore[assignment]
supabase_admin: Client = _LazyClient(get_admin_client)  # type: ignore[assignment]
