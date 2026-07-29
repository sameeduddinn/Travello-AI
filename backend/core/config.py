# =============================================================================
# PURPOSE: All environment variables and app settings via pydantic-settings.
#          Loaded once at startup; access anywhere via `from core.config import settings`.
# =============================================================================

import logging

from pydantic import field_validator
from pydantic_settings import BaseSettings
from functools import lru_cache

logger = logging.getLogger(__name__)

# Values pydantic already accepts for a bool, plus the build-flavour words that
# collide with a generic DEBUG variable. Anything outside these sets is a value
# somebody else's tooling put in the environment, not an instruction to us.
_TRUEISH = {"1", "true", "t", "yes", "y", "on", "debug", "development", "dev"}
_FALSEISH = {"0", "false", "f", "no", "n", "off", "release", "production", "prod", ""}


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Travello AI"
    APP_VERSION: str = "1.0.0"
    # DEBUG is a dangerously generic environment variable name — build tools,
    # CI runners and Android/Flutter tooling all set it, and `DEBUG=release`
    # in the ambient environment used to abort the ENTIRE app at import time
    # with a pydantic bool_parsing error (there is no request to fail; the
    # container just never starts). An unparseable value now resolves to
    # False, which is the production-safe direction: worst case we run with
    # debug output off. It is never silent — the coercion is logged.
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

    # Found in: Supabase Dashboard → Settings → API → JWT Secret
    SUPABASE_JWT_SECRET: str = ""

    # asyncpg direct connection — found in Supabase Dashboard → Settings → Database
    DATABASE_URL: str = ""

    # AviationStack (real domestic flight schedules — https://aviationstack.com)
    AVIATIONSTACK_KEY: str = ""

    # RapidAPI (hotel search - TripAdvisor)
    RAPIDAPI_KEY: str = ""
    RAPIDAPI_HOST: str = "tripadvisor16.p.rapidapi.com"

    # RapidAPI (hotel rooms - Hotels.com Provider)
    # Same RAPIDAPI_KEY, different host - subscribe at rapidapi.com
    HOTELS_COM_HOST: str = "hotels-com-provider.p.rapidapi.com" # in process

    # Google Maps Platform (Places API + Weather API + Healthcare nearby search)
    GOOGLE_PLACES_API_KEY: str = ""
    
    # Gemini — the THIRD provider budget, and (since it speaks native function
    # calling) a full tool-capable fallback for the agentic loop, not just a
    # plain-text one.
    #
    # "gemini-flash-latest" is an alias that always resolves to the current Flash
    # model. The old pinned "gemini-2.5-flash" returns HTTP 404 —
    # "no longer available to new users" — for accounts created after it was
    # superseded, which silently disabled the whole Gemini fallback. Verified live
    # against this project's key: gemini-flash-latest works for both text and
    # function calling; gemini-2.5-flash and gemini-2.5-flash-lite 404.
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-flash-latest"

    # Groq (completely free — sign up at console.groq.com)
    #
    # TWO keys are supported, because the free tier's limit that actually bites
    # is per-DAY and per-ACCOUNT (TPD). A second account is a second daily
    # budget: when key 1's day is spent, key 2 carries the rest of it. They are
    # tried in order and their cooldowns are tracked independently in
    # services/llm_service.py.
    #
    #   GROQ_API_KEY_1  — primary
    #   GROQ_API_KEY_2  — optional second account; leave blank for one-key setup
    #   GROQ_API_KEY    — legacy single-key name, still honoured as the value for
    #                     key 1 when GROQ_API_KEY_1 is not set (deployments that
    #                     predate the split keep working untouched)
    GROQ_API_KEY: str = ""
    GROQ_API_KEY_1: str = ""
    GROQ_API_KEY_2: str = ""
    # Default is the demo/production model. 8B (llama-3.1-8b-instant) is cheaper for local
    # dev but follows instructions less reliably — it invents traveler counts for vague
    # group requests instead of asking (see .env comment / CHANGELOG_agent_hardening.md).
    GROQ_MODEL: str = "llama-3.3-70b-versatile"

    @property
    def groq_api_keys(self) -> list[str]:
        """
        Configured Groq keys, in the order they should be tried.

        Deduplicated: pointing both variables at the same key would create a
        phantom second budget — the rotation would "fail over" onto the very
        account that just reported its day was spent, and the exhaustion checks
        would count one dead budget twice.

        The VALUES are secrets. Callers pass them to the SDK and nowhere else —
        never to a log line, an error message or a persisted field.
        """
        ordered: list[str] = []
        for raw in (self.GROQ_API_KEY_1 or self.GROQ_API_KEY, self.GROQ_API_KEY_2):
            key = (raw or "").strip()
            if key and key not in ordered:
                ordered.append(key)
        return ordered

    # OpenRouter — OpenAI-compatible fallback used ONLY when Groq is rate-limited
    # (free-tier 12k TPM). A second, independent budget so a tool-using turn can
    # complete instead of showing the "try again in a minute" message. Free key at
    # openrouter.ai. Leave blank to disable the fallback (Groq-only behaviour).
    OPENROUTER_API_KEY: str = ""
    # Comma-separated, tried in order; a model that is rate-limited upstream (429) is
    # skipped and the next is tried. Both defaults were verified free + tool-capable +
    # actually available (the llama-3.3-70b:free variant is NOT — it is permanently
    # rate-limited via its upstream provider, so do not use it here).
    OPENROUTER_MODEL: str = "openai/gpt-oss-20b:free,nvidia/nemotron-3-super-120b-a12b:free"



    # Email — Gmail SMTP
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

    # Currency
    USD_TO_PKR_RATE: float = 278.0
    EUR_TO_PKR_RATE: float = 305.0

    # Admin
    # Set a strong random string in .env — used to protect the support reply endpoint
    ADMIN_SECRET_KEY: str = ""
    # Public base URL of the backend (used to build reply-form links in emails)
    BACKEND_BASE_URL: str = "https://travello-ai.onrender.com"

    # OTP settings
    OTP_EXPIRE_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 3

    # AI agent
    # Per-account cap on user messages per UTC day. This is an ABUSE / SAFETY
    # limit and nothing else — it is OURS, it is not a provider quota, and the
    # user-facing message must never imply the AI service is out of capacity
    # (routers/agent.py words them differently for exactly that reason). Provider
    # budgets are tracked separately and live, in services/llm_service.py.
    # Raise it via .env for a live demo or evaluation, where rehearsal messages
    # earlier in the day would otherwise consume the allowance beforehand.
    AGENT_DAILY_MESSAGE_LIMIT: int = 50

    # CORS
    # Comma-separated list of allowed origins.
    # Use "*" during development; restrict to your Flutter app URL in production.
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


# Convenience singleton — import this directly in other modules
settings: Settings = get_settings()
