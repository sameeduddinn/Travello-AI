# =============================================================================
# PURPOSE: FastAPI application entry point.
#          - Registers all routers
#          - Configures CORS (allow all origins for Flutter dev)
#          - Lifespan: init/close asyncpg pool
#          - Global exception handlers
#          - Health check endpoint
# =============================================================================

from __future__ import annotations

import asyncio
import logging
import time
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from core.database import close_db_pool, init_db_pool


# Logging

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# Prevent low-level HTTP debug logs from leaking sensitive headers/tokens.
for noisy_logger in ("httpcore", "httpx", "hpack"):
    logging.getLogger(noisy_logger).setLevel(logging.WARNING)

logger = logging.getLogger(__name__)


# Lifespan — startup / shutdown hooks

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager.
    Code before `yield` runs at startup; code after runs at shutdown.
    """
    logger.info("Starting %s v%s", settings.APP_NAME, settings.APP_VERSION)

    # Initialise asyncpg pool (no-op if DATABASE_URL not set)
    await init_db_pool()

    # Configuration checks
    if not settings.SUPABASE_URL:
        logger.error("❌ SUPABASE_URL not set — app will NOT work!")
    else:
        logger.info("✅ Supabase configured")

    if settings.SMTP_USER:
        logger.info("✅ Gmail SMTP configured — from: %s", settings.EMAIL_FROM)
    else:
        logger.warning("⚠️  No email backend configured — set SMTP_USER/SMTP_PASSWORD in .env")

    logger.info("Startup complete. Ready to accept requests.")

    # Pre-warm only 4 major cities - all-cities bulk fetch is lazy (on demand).
    async def _warm_weather_cache():
        try:
            from services.weather_service import get_weather
            major = ["Karachi", "Lahore", "Islamabad", "Rawalpindi"]
            logger.info("Pre-warming weather cache for %d major cities…", len(major))
            await asyncio.gather(*[get_weather(c) for c in major])
            logger.info("✅ Weather cache ready.")
        except Exception as exc:
            logger.warning("Weather cache pre-warm failed: %s", exc)

    asyncio.ensure_future(_warm_weather_cache())

    yield  # <--- app is running here

    logger.info("Shutting down %s …", settings.APP_NAME)
    await close_db_pool()
    logger.info("Shutdown complete.")


# App instance
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Travello AI — Pakistan's smart travel booking backend. "
        "Supports flights, trains, "
        "hotels (RapidAPI), bookings, payments (card), "
        "and booking confirmation emails via SMTP."
    ),
    docs_url="/docs",       # Swagger UI
    redoc_url="/redoc",     # ReDoc
    openapi_url="/openapi.json",
    lifespan=lifespan,
)


# CORS middleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,   # "*" during development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID", "X-Response-Time"],
)


# Request timing middleware
@app.middleware("http")
async def add_response_time_header(request: Request, call_next):
    """Attach X-Response-Time header to every response (useful for debugging)."""
    print(f">>> REQUEST: {request.method} {request.url}", flush=True)
    start = time.perf_counter()
    response = await call_next(request)
    elapsed_ms = round((time.perf_counter() - start) * 1000, 2)
    print(f">>> RESPONSE: {response.status_code} ({elapsed_ms}ms)", flush=True)
    response.headers["X-Response-Time"] = f"{elapsed_ms}ms"
    return response


# Global exception handlers

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """Consistent JSON error shape for all HTTPExceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": True,
            "status_code": exc.status_code,
            "detail": exc.detail,
            "path": str(request.url.path),
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Catch-all for unhandled exceptions.
    Logs the full traceback and returns a safe 500 response.
    """
    logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": True,
            "status_code": 500,
            "detail": "An internal server error occurred. Please try again later.",
            "path": str(request.url.path),
        },
    )


# Routers — import and register

from routers import auth, flights, trains, hotels, bookings, payments
from routers import passengers, wishlist, notifications, email as email_router
from routers import weather as weather_router
from routers import healthcare as healthcare_router
from routers import saved_searches as saved_searches_router
from routers import reviews as reviews_router
from routers import support as support_router
from routers import cars as cars_router
from routers import agent as agent_router

app.include_router(auth.router)
app.include_router(flights.router)
app.include_router(trains.router)
app.include_router(hotels.router)
app.include_router(bookings.router)
app.include_router(payments.router)
app.include_router(passengers.router)
app.include_router(wishlist.router)
app.include_router(notifications.router)
app.include_router(email_router.router)
app.include_router(weather_router.router)
app.include_router(healthcare_router.router)
app.include_router(saved_searches_router.router)
app.include_router(reviews_router.router)
app.include_router(support_router.router)
app.include_router(cars_router.router)
app.include_router(agent_router.router)


# Health check — no auth required (used by Render.com health checks)

@app.get("/health", tags=["Health"], include_in_schema=False)
async def health_check() -> dict[str, Any]:
    """
    Simple liveness probe.
    Render.com pings this endpoint to decide if the service is healthy.
    """
    return {
        "status": "ok",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
    }


@app.get("/", tags=["Root"], include_in_schema=False)
async def root() -> dict[str, str]:
    return {
        "message": f"Welcome to {settings.APP_NAME} API",
        "docs": "/docs",
        "health": "/health",
    }


# Dev entrypoint (python main.py)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="debug" if settings.DEBUG else "info",
    )
