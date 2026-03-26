# ==============================================================================
# FastAPI Task Manager - Configuration (via environment variables)
# ==============================================================================
from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # --- Application ---
    APP_NAME: str = "Task Manager API"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "dev"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"

    # --- Database ---
    DATABASE_HOST: str = "127.0.0.1"
    DATABASE_PORT: int = 5432
    DATABASE_NAME: str = "taskmanager"
    DATABASE_USER: str = "taskmanager"
    DATABASE_PASSWORD: str = ""
    DATABASE_POOL_SIZE: int = 5
    DATABASE_MAX_OVERFLOW: int = 10

    # --- Authentication ---
    JWT_SECRET_KEY: str = "HERE_JWT_SECRET_KEY"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 60

    # --- Rate Limiting ---
    RATE_LIMIT: str = "100/minute"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.DATABASE_USER}:{self.DATABASE_PASSWORD}"
            f"@{self.DATABASE_HOST}:{self.DATABASE_PORT}/{self.DATABASE_NAME}"
        )

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
