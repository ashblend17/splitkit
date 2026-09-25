from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "dev"
    database_url: str = "postgresql+psycopg://splitkit:splitkit@localhost:5433/splitkit"
    jwt_secret: str = "dev-only-insecure-secret-change-me-please"
    jwt_ttl_minutes: int = 60 * 24 * 7
    cors_origins: list[str] = ["http://localhost:8080"]


@lru_cache
def get_settings() -> Settings:
    return Settings()
