import os
from functools import lru_cache
from pathlib import Path
from urllib.parse import quote

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT_ENV = Path(__file__).resolve().parents[3] / ".env"
"""The repo's .env, which docker compose reads too: run outside Docker (uvicorn, pytest, alembic,
the seed), the API takes its database and secrets from it. In a container there is none:
compose passes them in. NO_DOTENV (the tests set it) reads neither."""


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=() if os.environ.get("NO_DOTENV") else (ROOT_ENV, ".env"), extra="ignore"
    )

    env: str = "dev"
    app_name: str = "App"
    """What the app is called, in what the API says to people ("There's no App account with
    that email yet"). APP_NAME in .env."""

    database_url: str = ""
    """Given, or made from the parts below: the user, database and password docker compose
    starts PostgreSQL with, on its host port."""
    db_user: str = "app"
    db_name: str = "app"
    db_host: str = "localhost"
    db_port: int = 5433
    postgres_password: str = ""

    jwt_secret: str
    """Signs every token. No default: set JWT_SECRET (`openssl rand -hex 32`); changing it signs
    everyone out."""
    jwt_ttl_minutes: int = 60 * 24 * 7
    admin_session_ttl_minutes: int = 60 * 4
    """How long an admin's view-as token lasts. Ending the session stops it sooner."""
    seed_password: str = ""
    """What every account `python -m app.seed` makes signs in with. SEED_PASSWORD in .env;
    seeding refuses without one."""
    cors_origins: list[str] = ["http://localhost:8080"]

    # Tricount sync (app/modules/tricount_sync). Unofficial API: see that module's docstring.
    tricount_api_url: str = "https://api.tricount.bunq.com"
    tricount_user_agent: str = "com.bunq.tricount.android:RELEASE:7.0.7:3174:ANDROID:13:C"
    """The API only accepts writes from clients that identify as Tricount's Android app."""
    tricount_poll_seconds: int = 60
    """How often a linked group is pulled from Tricount while someone in it is active."""
    tricount_active_minutes: int = 10
    """A group counts as active this long after one of its members last used the app."""
    tricount_time_zone: str = "Asia/Kolkata"
    """Where the app's days are (an IANA zone). Tricount keeps an entry's time in UTC and its
    app shows it in the phone's zone, so a day here is turned into an instant in this zone
    and back. TRICOUNT_TIME_ZONE in the server's .env."""

    @model_validator(mode="after")
    def _database_url(self) -> "Settings":
        if not self.database_url:
            self.database_url = (
                f"postgresql+psycopg://{quote(self.db_user)}:{quote(self.postgres_password)}"
                f"@{self.db_host}:{self.db_port}/{quote(self.db_name)}"
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
