"""Application configuration."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings loaded from environment variables."""

    app_name: str = "Smart Hydroponics Management API"
    app_version: str = "0.1.0"
    database_url: str = (
        "postgresql+asyncpg://postgres:postgres@localhost:5432/hydroponics"
    )
    groq_api_key: str = ""
    groq_model_name: str = "llama-3.3-70b-versatile"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached application settings."""
    return Settings()

