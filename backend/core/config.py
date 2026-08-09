# PURPOSE: All environment variables and app settings via pydantic-settings.
#          Loaded once at startup; access anywhere via `from core.config import settings`.
import logging

from pydantic import field_validator
from pydantic_settings import BaseSettings
from functools import lru_cache

logger = logging.getLogger(__name__)


_TRUEISH = {"1", "true", "t", "yes", "y", "on", "debug", "development", "dev"}
_FALSEISH = {"0", "false", "f", "no", "n", "off", "release", "production", "prod", ""}


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Travello AI"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    @field_validator("DEBUG", mode="before")
    @classmethod
    def _tolerant_debug(cls, v):
        if isinstance(v, str):
            word = v.strip().lower()
            if word in _TRUEISH:
                return True
            if word in _FALSEISH:
                return False
            logger.warning(
                "DEBUG=%r is not a boolean — treating it as False. Set DEBUG=true "
                "or DEBUG=false explicitly if this was meant for us.", v,
            )
            return False
        return v

    # Supabase
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Found in: Supabase Dashboard -> Settings -> API -> JWT Secret
    SUPABASE_JWT_SECRET: str = ""

    # asyncpg direct connection — found in Supabase Dashboard -> Settings -> Database
    DATABASE_URL: str = ""

    # AviationStack (real domestic flight schedules  https://aviationstack.com)
    AVIATIONSTACK_KEY: str = ""

    # RapidAPI (hotel search - TripAdvisor)
    RAPIDAPI_KEY: str = ""
    RAPIDAPI_HOST: str = "tripadvisor16.p.rapidapi.com"

    # RapidAPI (hotel rooms - Hotels.com Provider)
    # Same RAPIDAPI_KEY, different host - subscribe at rapidapi.com
    HOTELS_COM_HOST: str = "hotels-com-provider.p.rapidapi.com" # in process

    # Google Maps Platform (Places API + Weather API + Healthcare nearby search)
    GOOGLE_PLACES_API_KEY: str = ""
    

    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"


    GROQ_API_KEY: str = ""
    GROQ_API_KEY_1: str = ""
    GROQ_API_KEY_2: str = ""

    GROQ_MODEL: str = "llama-3.3-70b-versatile"

    @property
    def groq_api_keys(self) -> list[str]:

        ordered: list[str] = []
        for raw in (self.GROQ_API_KEY_1 or self.GROQ_API_KEY, self.GROQ_API_KEY_2):
            key = (raw or "").strip()
            if key and key not in ordered:
                ordered.append(key)
        return ordered


    OPENROUTER_API_KEY: str = ""

    OPENROUTER_MODEL: str = "openai/gpt-oss-20b:free,nvidia/nemotron-3-super-120b-a12b:free"



    # Email: Gmail SMTP
    EMAIL_FROM: str = "Travello AI <travelloo.ai@gmail.com>"
    EMAIL_REPLY_TO: str = "support@travello.ai"


    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""

    # Currency
    USD_TO_PKR_RATE: float = 278.0
    EUR_TO_PKR_RATE: float = 305.0

    # Admin
    ADMIN_SECRET_KEY: str = ""
    BACKEND_BASE_URL: str = "https://travello-ai.onrender.com"

    # OTP settings
    OTP_EXPIRE_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 3

  
    AGENT_DAILY_MESSAGE_LIMIT: int = 100

   
    CORS_ORIGINS: str = "*"

    @property
    def cors_origins_list(self) -> list[str]:
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [o.strip() for o in self.CORS_ORIGINS.split(",")]

    # Pagination defaults
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


# Convenience singleton: import this directly in other modules
settings: Settings = get_settings()
