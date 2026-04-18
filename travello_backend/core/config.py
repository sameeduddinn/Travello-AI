# =============================================================================
# FILE: core/config.py
# PURPOSE: All environment variables and app settings via pydantic-settings.
#          Loaded once at startup; access anywhere via `from core.config import settings`.
# =============================================================================

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # -------------------------------------------------------------------------
    # App
    # -------------------------------------------------------------------------
    APP_NAME: str = "Travello AI"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # -------------------------------------------------------------------------
    # Supabase
    # -------------------------------------------------------------------------
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Used to verify incoming JWTs from the Flutter app.
    # Found in: Supabase Dashboard → Settings → API → JWT Secret
    SUPABASE_JWT_SECRET: str = ""

    # asyncpg direct connection — found in Supabase Dashboard → Settings → Database
    # Format: postgresql://postgres:[password]@[host]:5432/postgres
    DATABASE_URL: str = ""

    # -------------------------------------------------------------------------
    # Amadeus (flight search — optional, kept for fallback)
    # -------------------------------------------------------------------------
    AMADEUS_CLIENT_ID: str = ""
    AMADEUS_CLIENT_SECRET: str = ""
    AMADEUS_HOSTNAME: str = "test"

    # -------------------------------------------------------------------------
    # AviationStack (real flight schedules — https://aviationstack.com)
    # Free tier: 100 req/month. Routes are cached 24 h to minimise calls.
    # Leave blank → rich mock flight data is used.
    # -------------------------------------------------------------------------
    AVIATIONSTACK_KEY: str = ""

    # -------------------------------------------------------------------------
    # RapidAPI (hotel search — TripAdvisor)
    # -------------------------------------------------------------------------
    RAPIDAPI_KEY: str = ""
    RAPIDAPI_HOST: str = "tripadvisor-com1.p.rapidapi.com"

    # -------------------------------------------------------------------------
    # Google Places API (healthcare nearby search — optional)
    # Sign up at: https://console.cloud.google.com → Enable Places API
    # Leave blank to use built-in mock Pakistani hospital data
    # -------------------------------------------------------------------------
    GOOGLE_PLACES_API_KEY: str = ""

    # -------------------------------------------------------------------------
    # Resend (email)
    # -------------------------------------------------------------------------
    RESEND_API_KEY: str = ""

    # Use onboarding@resend.dev for FYP demo — works without domain verification
    EMAIL_FROM: str = "Travello AI <onboarding@resend.dev>"
    EMAIL_REPLY_TO: str = "support@travello.ai"

    # -------------------------------------------------------------------------
    # Currency
    # -------------------------------------------------------------------------
    # Fixed conversion rates (no live API needed for demo)
    USD_TO_PKR_RATE: float = 278.0
    EUR_TO_PKR_RATE: float = 305.0

    # -------------------------------------------------------------------------
    # OTP settings
    # -------------------------------------------------------------------------
    OTP_EXPIRE_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 3

    # -------------------------------------------------------------------------
    # CORS
    # -------------------------------------------------------------------------
    # Comma-separated list of allowed origins.
    # Use "*" during development; restrict to your Flutter app URL in production.
    CORS_ORIGINS: str = "*"

    @property
    def cors_origins_list(self) -> list[str]:
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [o.strip() for o in self.CORS_ORIGINS.split(",")]

    # -------------------------------------------------------------------------
    # Pagination defaults
    # -------------------------------------------------------------------------
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """
    Return cached Settings instance.
    Use `from core.config import settings` everywhere — the cache ensures
    the .env file is only read once.
    """
    return Settings()


# Convenience singleton — import this directly in other modules
settings: Settings = get_settings()
