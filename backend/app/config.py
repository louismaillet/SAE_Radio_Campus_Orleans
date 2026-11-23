from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration lue depuis les variables d'environnement (.env via docker-compose)."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "postgresql+psycopg://radio:radio@localhost:5432/radio_campus"

    JWT_SECRET_KEY: str = "dev-secret-change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    MEDIA_DIR: Path = Path("media")
    MEDIA_URL_PREFIX: str = "/media"
    MAX_UPLOAD_SIZE_MB: int = 5

    # Clé du compte de service Firebase (JSON). Absente = notifications simulées (logs).
    FIREBASE_CREDENTIALS: Path | None = None
    # Nombre max de notifications par radio sur 24 h glissantes
    NOTIFICATIONS_PER_DAY: int = 5


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
