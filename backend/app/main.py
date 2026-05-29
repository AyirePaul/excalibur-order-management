from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.graphql.schema import graphql_app
from app.api.rest.health import router as health_router
from app.api.rest.orders import router as orders_router
from app.core.config import get_settings
from app.core.logging import setup_logging

log = structlog.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    setup_logging(settings.app_log_level)

    # OTel initialisation is best-effort — skip if collector unreachable in local dev
    try:
        from app.core.telemetry import setup_telemetry

        setup_telemetry(app)
    except Exception as exc:  # noqa: BLE001
        log.warning("otel_init_skipped", reason=str(exc))

    log.info("startup", env=settings.app_env)
    yield
    log.info("shutdown")


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Order Management API",
        version="1.0.0",
        docs_url="/docs" if settings.enable_docs else None,
        redoc_url="/redoc" if settings.enable_docs else None,
        openapi_url="/openapi.json" if settings.enable_docs else None,
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health_router)
    app.include_router(orders_router, prefix="/orders")
    app.include_router(graphql_app, prefix="/graphql")

    @app.get("/api/reports/latest-url")
    def latest_report_url():
        from app.reporting.presign import get_latest_report_url

        url = get_latest_report_url()
        return {"url": url}

    return app


app = create_app()
