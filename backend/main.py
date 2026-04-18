# =============================================================================
# FILE: main.py
# PURPOSE: FastAPI application entry point.
#          - Registers all routers
#          - Configures CORS (allow all origins for Flutter dev)
#          - Lifespan: init/close asyncpg pool
#          - Global exception handlers
#          - Health check endpoint
# =============================================================================

from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from core.database import close_db_pool, init_db_pool

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lifespan — startup / shutdown hooks
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager.
    Code before `yield` runs at startup; code after runs at shutdown.
    """
    logger.info("Starting %s v%s", settings.APP_NAME, settings.APP_VERSION)

    # Initialise asyncpg pool (no-op if DATABASE_URL not set)
    await init_db_pool()
    logger.info("Startup complete. Ready to accept requests.")

    yield  # <--- app is running here

    logger.info("Shutting down %s …", settings.APP_NAME)
    await close_db_pool()
    logger.info("Shutdown complete.")


# ---------------------------------------------------------------------------
# App instance
# ---------------------------------------------------------------------------

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Travello AI — Pakistan's smart travel booking backend. "
        "Supports flights (Amadeus), trains (Pakistan Railways mock), "
        "hotels (RapidAPI), bookings, payments (JazzCash/EasyPaisa OTP simulation), "
        "and booking confirmation emails via Resend."
    ),
    docs_url="/docs",       # Swagger UI
    redoc_url="/redoc",     # ReDoc
    openapi_url="/openapi.json",
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# CORS middleware
# ---------------------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,   # "*" during development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID", "X-Response-Time"],
)


# ---------------------------------------------------------------------------
# Request timing middleware
# ---------------------------------------------------------------------------

@app.middleware("http")
async def add_response_time_header(request: Request, call_next):
    """Attach X-Response-Time header to every response (useful for debugging)."""
    start = time.perf_counter()
    response = await call_next(request)
    elapsed_ms = round((time.perf_counter() - start) * 1000, 2)
    response.headers["X-Response-Time"] = f"{elapsed_ms}ms"
    return response


# ---------------------------------------------------------------------------
# Global exception handlers
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Routers — import and register
# ---------------------------------------------------------------------------

from routers import auth, flights, trains, hotels, bookings, payments
from routers import passengers, wishlist, notifications, email as email_router
from routers import weather as weather_router
from routers import healthcare as healthcare_router
from routers import saved_searches as saved_searches_router
from routers import reviews as reviews_router

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


# ---------------------------------------------------------------------------
# Health check — no auth required (used by Render.com health checks)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Dev entrypoint (python main.py)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="debug" if settings.DEBUG else "info",
    )
