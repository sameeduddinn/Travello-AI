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
    # AviationStack (real domestic flight schedules — https://aviationstack.com)
    # -------------------------------------------------------------------------
    AVIATIONSTACK_KEY: str = ""

    # -------------------------------------------------------------------------
    # RapidAPI (hotel search — TripAdvisor)
    # -------------------------------------------------------------------------
    RAPIDAPI_KEY: str = ""
    RAPIDAPI_HOST: str = "tripadvisor16.p.rapidapi.com"

    # RapidAPI (hotel rooms — Hotels.com Provider)
    # Same RAPIDAPI_KEY, different host — subscribe at rapidapi.com
    HOTELS_COM_HOST: str = "hotels-com-provider.p.rapidapi.com"

    # -------------------------------------------------------------------------
    # Google Maps Platform (Places API + Weather API + Healthcare nearby search)
    # -------------------------------------------------------------------------
    GOOGLE_PLACES_API_KEY: str = ""



    # -------------------------------------------------------------------------
    # Email — Gmail SMTP
    # -------------------------------------------------------------------------
    EMAIL_FROM: str = "Travello AI <travelloo.ai@gmail.com>"
    EMAIL_REPLY_TO: str = "support@travello.ai"

    # Gmail SMTP (free, no domain needed, sends to any address)
    # 1. Enable 2-Step Verification on your Google account
    # 2. Google Account → Security → App Passwords → create one for "Mail"
    # 3. Set SMTP_USER=you@gmail.com  SMTP_PASSWORD=xxxx-xxxx-xxxx-xxxx
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""

    # -------------------------------------------------------------------------
    # Currency
    # -------------------------------------------------------------------------
    # Fixed conversion rates (no live API needed for demo)
    USD_TO_PKR_RATE: float = 278.0
    EUR_TO_PKR_RATE: float = 305.0

    # -------------------------------------------------------------------------
    # Admin
    # -------------------------------------------------------------------------
    # Set a strong random string in .env — used to protect the support reply endpoint
    ADMIN_SECRET_KEY: str = ""
    # Public base URL of the backend (used to build reply-form links in emails)
    BACKEND_BASE_URL: str = "https://travello-ai.onrender.com"

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
