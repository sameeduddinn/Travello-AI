# =============================================================================
# PURPOSE: asyncpg connection pool for raw SQL queries.
#          Used when the supabase-py client is too limiting
#          (e.g., complex JOINs, transactions, bulk inserts).
# =============================================================================

from __future__ import annotations

import logging
from typing import Any

import asyncpg
from asyncpg import Pool, Record

from core.config import settings

logger = logging.getLogger(__name__)

# Module-level pool - initialised by lifespan in main.py
_pool: Pool | None = None


async def init_db_pool() -> None:
    """Call once at app startup (inside lifespan context manager)."""
    global _pool

    if not settings.DATABASE_URL:
        logger.warning(
            "DATABASE_URL not set — asyncpg pool skipped. "
            "All DB access will use supabase-py client."
        )
        return

    try:
        _pool = await asyncpg.create_pool(
            dsn=settings.DATABASE_URL,
            min_size=2,
            max_size=10,
            command_timeout=30,
            # Supabase requires SSL; asyncpg handles it via the DSN's sslmode param.
        )
        logger.info("asyncpg connection pool initialised.")
    except Exception as exc:
        logger.error("Failed to create asyncpg pool: %s", exc)
        # Don't crash the app — fall back to supabase-py
        _pool = None


async def close_db_pool() -> None:
    """Call once at app shutdown (inside lifespan context manager)."""
    global _pool
    if _pool:
        await _pool.close()
        logger.info("asyncpg pool closed.")
        _pool = None


def get_db_pool() -> Pool | None:
    """Return the pool (may be None if DATABASE_URL not configured)."""
    return _pool


# Helper functions — thin wrappers so routers don't import asyncpg directly

async def fetch_one(query: str, *args: Any) -> Record | None:
    """Execute query and return the first row, or None."""
    if not _pool:
        raise RuntimeError("asyncpg pool is not initialised.")
    async with _pool.acquire() as conn:
        return await conn.fetchrow(query, *args)


async def fetch_all(query: str, *args: Any) -> list[Record]:
    """Execute query and return all rows."""
    if not _pool:
        raise RuntimeError("asyncpg pool is not initialised.")
    async with _pool.acquire() as conn:
        return await conn.fetch(query, *args)


async def execute(query: str, *args: Any) -> str:
    """Execute a DML statement (INSERT / UPDATE / DELETE). Returns status string."""
    if not _pool:
        raise RuntimeError("asyncpg pool is not initialised.")
    async with _pool.acquire() as conn:
        return await conn.execute(query, *args)


async def fetch_val(query: str, *args: Any) -> Any:
    """Execute query and return a single scalar value."""
    if not _pool:
        raise RuntimeError("asyncpg pool is not initialised.")
    async with _pool.acquire() as conn:
        return await conn.fetchval(query, *args)
