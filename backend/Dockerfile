# syntax=docker/dockerfile:1.7

FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libpq-dev libpq5 libffi-dev libssl-dev curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --upgrade pip

# --- dev stage: hot-reload for docker compose ---
# Source is volume-mounted at runtime (./backend:/app in docker-compose).
# PYTHONPATH=/app makes Python import from the mount point, so edits are live
# without needing pip install -e (which requires hatchling to build an editable
# wheel and was the original source of build failures).
FROM base AS dev
COPY pyproject.toml ./
COPY app ./app
RUN pip install ".[dev]"
ENV PYTHONPATH=/app
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# --- builder stage: compile production wheel ---
FROM base AS builder
COPY pyproject.toml ./
COPY app ./app
RUN pip install --prefix=/install .

# --- runtime: minimal final image ---
FROM python:3.12-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -u 1001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app ./app
COPY alembic.ini ./
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8000/healthz || exit 1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
