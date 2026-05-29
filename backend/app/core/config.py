from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    app_env: str = "local"
    app_log_level: str = "INFO"

    # DB
    database_url: str = "postgresql+psycopg://orders:orders@localhost:5432/orders"

    # API
    cors_origins: str = "http://localhost:5173"
    enable_docs: bool = True

    # AWS
    aws_region: str = "us-east-1"

    # Cognito
    cognito_user_pool_id: str = ""
    cognito_app_client_id: str = ""
    cognito_region: str = "us-east-1"
    cognito_domain: str = ""

    # Reports
    reports_bucket: str = ""
    report_runner_task_definition: str = ""

    # OTel
    otel_exporter_otlp_endpoint: str = "http://localhost:4318"
    otel_service_name: str = "orders-api"

    @property
    def cors_origins_list(self) -> list[str]:
        # Guard against empty string yielding [""] which CORS middleware treats as a valid origin
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
