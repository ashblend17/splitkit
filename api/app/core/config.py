from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "dev"
    database_url: str = "postgresql+psycopg://splitkit:splitkit@localhost:5433/splitkit"
    jwt_secret: str = "dev-only-insecure-secret-change-me-please"
    jwt_ttl_minutes: int = 60 * 24 * 7
    admin_session_ttl_minutes: int = 60 * 4
    """How long an admin's view-as token lasts. Ending the session stops it sooner."""
    cors_origins: list[str] = ["http://localhost:8080"]

    # Tricount sync (app/modules/tricount_sync). Unofficial API: see that module's docstring.
    tricount_api_url: str = "https://api.tricount.bunq.com"
    tricount_user_agent: str = "com.bunq.tricount.android:RELEASE:7.0.7:3174:ANDROID:13:C"
    """The API only accepts writes from clients that identify as Tricount's Android app."""
    tricount_poll_seconds: int = 60
    """How often a linked group is pulled from Tricount while someone in it is active."""
    tricount_active_minutes: int = 10
    """A group counts as active this long after one of its members last used the app."""


@lru_cache
def get_settings() -> Settings:
    return Settings()
