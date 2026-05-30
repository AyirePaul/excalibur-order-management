# Order Management — Excalibur Assignment (Tier 3: Mid-Level)

A cloud-native order management system. This repo covers Tier 1 through Tier 3 of the Excalibur Full Stack Cloud & Web Application Developer assignment. The API is open (no authentication at Tier 3).

## Architecture

- **Frontend** — React 18 + Vite + TypeScript + Tailwind, served by nginx in Docker and as an ECS Fargate service in AWS.
- **Backend** — FastAPI on Python 3.12, SQLAlchemy 2.x + Alembic migrations. Runs on ECS Fargate behind an ALB.
- **Database** — PostgreSQL 16 on RDS (SSL disabled, VPC-internal traffic). Credentials in AWS Secrets Manager.
- **Reporting** — JasperReports `.jrxml` rendered by a containerised `report-runner`; PDF uploaded to S3, embedded in the UI via a 1-hour presigned URL. EventBridge triggers the runner daily at 06:00 UTC; on-demand via `make report-aws`.
- **IaC** — Terraform modules under `infra/modules/`, single-environment root at `infra/`.
- **Config management** — Single Ansible playbook (`ansible/playbooks/deploy.yml`): migrate → deploy → healthcheck.
- **CI/CD** — GitHub Actions: `ci.yml` (lint + test + tf validate), `cd.yml` (3 parallel image builds → tf plan → manual gate → tf apply → Ansible).

See `docs/architecture.svg` for the full diagram.

## Quick Start — Local

```bash
cp .env.example .env
make up           # docker compose: postgres + backend + frontend
make seed         # run migrations + load db/seed.sql (30 rows)
make test         # backend (pytest) + frontend (vitest)
```

- UI: <http://localhost:5173>
- API / Swagger: <http://localhost:8000/docs>
- Adminer: <http://localhost:8080>

### Sample curl requests

```bash
# Health check
curl http://localhost:8000/healthz

# Combine: amounts > $100 in current year
curl -s -X POST http://localhost:8000/orders/combine \
  -H "Content-Type: application/json" \
  -d '{"amountOp":"GT","amountValue":100}' | python3 -m json.tool

# Create an order
curl -s -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"order_date":"2026-06-01","order_amount":"299.99","order_description":"Widget bundle"}' \
  | python3 -m json.tool
```

### Generate a report locally

```bash
make report       # runs report-runner container, writes PDF to ./out/
# Then open: http://localhost:8000/api/reports/latest
```

## Quick Start — Cloud

Prereqs: AWS account, AWS CLI configured, Terraform ≥ 1.6.

```bash
make tf-bootstrap   # creates state bucket + DynamoDB lock, writes infra/backend.hcl
make tf-init        # terraform init -backend-config=backend.hcl
make tf-plan
make tf-apply
```

After the first apply, set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `ECR_REGISTRY` in the GitHub `production` Environment and push to `main` — the `cd.yml` workflow deploys automatically.

To trigger a report on-demand after deploy:
```bash
make report-aws   # runs report-runner ECS task, uploads PDF to S3
```

## API

| Surface | Path | Notes |
|---|---|---|
| REST | `/orders` (CRUD), `/orders/combine`, `/orders/export.csv` | OpenAPI at `/openapi.json` |
| Health | `/healthz`, `/readyz` | Liveness + DB ping |
| Report URL | `/api/reports/latest-url` | Returns `{ url }` — S3 presigned URL in prod, local path in dev |
| Report file | `/api/reports/latest` | Streams PDF from `/reports` volume (local dev only) |
| Docs | `/docs`, `/redoc` | Swagger + Redoc |

## Tech Choices

- **Python/FastAPI** — async-first, first-class OpenAPI generation, lightweight container.
- **PostgreSQL on RDS** — `NUMERIC(12,2)` native, straightforward Secrets Manager integration.
- **ECS Fargate** — no control-plane to operate; right-sized for this scope.
- **Plain Terraform** — single environment; Terragrunt would add layering overhead without benefit here.
- **JasperReports** — assignment names it explicitly; the `.jrxml` is portable and runs in a one-shot Fargate container.
- **S3 for reports** — decouples generation from serving; presigned URLs avoid cross-origin iframe issues.

## Repo Layout

```
order-management/
├── .env.example
├── docker-compose.yml          # postgres + backend + frontend (+ report-runner profile)
├── Makefile                    # up / seed / test / report / report-aws / tf-bootstrap / tf-plan / tf-apply
│
├── backend/
│   ├── Dockerfile
│   ├── pyproject.toml
│   └── app/
│       ├── main.py             # app factory, CORS, router wiring, report endpoints
│       ├── core/
│       │   ├── config.py       # pydantic-settings (reports_bucket, aws_region)
│       │   └── logging.py      # structlog JSON logging
│       ├── db/
│       │   ├── base.py         # SQLAlchemy engine + session (pool_size=3)
│       │   └── migrations/versions/0001_initial.py
│       ├── models/             # order_date, order_detail, order_combined
│       ├── schemas/orders.py   # Pydantic DTOs — strict DTO/ORM separation
│       ├── services/
│       │   ├── sort.py         # generic sort_by(items, key_fn, reverse)
│       │   └── orders.py       # combine + CRUD
│       ├── api/rest/
│       │   ├── health.py       # /healthz  /readyz
│       │   └── orders.py       # CRUD + /combine + /export.csv
│       └── reporting/presign.py  # S3 presigned URL (prod) or local path (dev)
│   └── tests/
│       ├── conftest.py         # testcontainers Postgres fixtures
│       ├── unit/               # test_sort, test_schemas, test_services
│       └── integration/        # test_orders_api
│
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── src/
│   │   ├── router.tsx          # 5 lazy-loaded routes
│   │   ├── api/client.ts       # axios instance
│   │   ├── api/orders.ts       # typed API helpers + latestReportUrl
│   │   ├── components/         # Layout, Button
│   │   └── features/
│   │       ├── orders-list/    # table + card view toggle
│   │       ├── orders-edit/    # create + edit forms
│   │       ├── combine/        # filter form → combine → CSV export
│   │       └── reports/        # fetches presigned URL → iframe
│   └── tests/                  # Vitest + React Testing Library
│
├── report-runner/
│   ├── Dockerfile              # eclipse-temurin:17-jre-alpine + jasperstarter + PostgreSQL JDBC
│   ├── runner.py               # connects via DATABASE_URL, runs jasperstarter, uploads to S3
│   └── reports/orders_by_month.jrxml
│
├── db/seed.sql                 # 30 rows spanning Jan–Dec 2025
│
├── infra/
│   ├── backend.tf              # partial S3 backend (bucket from backend.hcl)
│   ├── backend.hcl             # account-scoped bucket name — committed after make tf-bootstrap
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf                 # wires all modules + S3 reports bucket + EventBridge cron
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── network/            # VPC, 2 public + 2 private subnets, NAT
│       ├── rds/                # Postgres 16, db_client_sg for access control
│       ├── ecs-cluster/        # Fargate cluster
│       ├── ecs-service/        # task def + service (reused for backend + frontend)
│       ├── alb/                # ALB, HTTP listener; HTTPS if cert ARN set
│       └── ecr/                # backend, frontend, report-runner repos
│
├── ansible/
│   ├── requirements.yml        # community.aws collection
│   ├── inventories/dev/hosts.yml
│   └── playbooks/deploy.yml    # migrate → force-deploy backend+frontend → healthcheck
│
├── docs/architecture.svg
├── .github/
│   ├── actions/build-push/     # composite action: ECR auth + docker build+push
│   └── workflows/
│       ├── ci.yml              # lint + test + tf fmt/validate
│       └── cd.yml              # 3 parallel builds → plan → gate → apply → ansible
```

## Known Limitations

- No authentication (Tier 3 scope cut — see HANDOFF.md).
- Single AWS region (`us-east-1`), single environment.
- RDS SSL disabled (VPC-internal; re-enable with `sslmode=require` + cert bundle for stricter environments).
- Report generation is on-demand or daily cron; no real-time streaming.

## AI Assistance

This project was developed with AI coding assistance. Every line is owned by the candidate and is explainable on demand.
