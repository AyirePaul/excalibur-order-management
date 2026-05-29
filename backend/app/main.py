from contextlib import asynccontextmanager
from pathlib import Path

import structlog
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from app.api.rest.health import router as health_router
from app.api.rest.orders import router as orders_router
from app.core.config import get_settings
from app.core.logging import setup_logging

log = structlog.get_logger(__name__)

REPORTS_DIR = Path("/reports")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    setup_logging(settings.app_log_level)
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

    @app.get("/api/reports/latest")
    def latest_report():
        if not REPORTS_DIR.exists():
            raise HTTPException(status_code=404, detail="No reports directory")
        pdfs = sorted(REPORTS_DIR.glob("*.pdf"))
        if not pdfs:
            raise HTTPException(status_code=404, detail="No report generated yet")
        return FileResponse(pdfs[-1], media_type="application/pdf")

    return app


app = create_app()
