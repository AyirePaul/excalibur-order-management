# Order Management — Excalibur Assignment (Tier 3: Mid-Level)

A cloud-native order management system. This repo covers Tier 1 through Tier 3 of the Excalibur Full Stack Cloud & Web Application Developer assignment. The API is open (no authentication at Tier 3).

## Architecture

- **Frontend** — React 18 + Vite + TypeScript + Tailwind, served by nginx in Docker and as an ECS Fargate service in AWS.
- **Backend** — FastAPI on Python 3.12, SQLAlchemy 2.x + Alembic migrations. Runs on ECS Fargate behind an ALB.
- **Database** — PostgreSQL 16 on RDS, credentials in AWS Secrets Manager.
- **Reporting** — JasperReports `.jrxml` rendered by a containerised `report-runner`; PDF served directly from the backend at `/api/reports/latest`.
- **IaC** — Terraform modules under `infra/modules/`, single-environment root at `infra/`.
- **Config management** — Single Ansible playbook (`ansible/playbooks/deploy.yml`).
- **CI/CD** — GitHub Actions: `ci.yml` (lint + test + tf validate), `cd.yml` (build → push → plan → manual gate → apply → deploy).

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

## API

| Surface | Path | Notes |
|---|---|---|
| REST | `/orders` (CRUD), `/orders/combine`, `/orders/export.csv` | OpenAPI at `/openapi.json` |
| Health | `/healthz`, `/readyz` | Liveness + DB ping |
| Report | `/api/reports/latest` | Streams latest PDF |
| Docs | `/docs`, `/redoc` | Swagger + Redoc |

## Tech Choices

- **Python/FastAPI** — async-first, first-class OpenAPI generation, lightweight container.
- **PostgreSQL on RDS** — `NUMERIC(12,2)` native, straightforward Secrets Manager integration.
- **ECS Fargate** — no control-plane to operate; right-sized for this scope.
- **Plain Terraform** — single environment; Terragrunt would add layering overhead without benefit here.
- **JasperReports** — assignment names it explicitly; the `.jrxml` is portable and runs in a one-shot container.

## Repo Layout

```
order-management/
├── .env.example
├── docker-compose.yml          # postgres + backend + frontend (+ report-runner profile)
├── Makefile                    # up / seed / test / report / tf-bootstrap / tf-plan / tf-apply
│
├── backend/
│   ├── Dockerfile
│   ├── pyproject.toml
│   └── app/
│       ├── main.py             # app factory, CORS, router wiring, report endpoint
│       ├── core/
│       │   ├── config.py       # pydantic-settings
│       │   └── logging.py      # structlog JSON logging
│       ├── db/
│       │   ├── base.py         # SQLAlchemy engine + session
│       │   └── migrations/versions/0001_initial.py
│       ├── models/             # order_date, order_detail, order_combined
│       ├── schemas/orders.py   # Pydantic DTOs — strict DTO/ORM separation
│       ├── services/
│       │   ├── sort.py         # generic sort_by(items, key_fn, reverse)
│       │   └── orders.py       # combine + CRUD
│       ├── api/rest/
│       │   ├── health.py       # /healthz  /readyz
│       │   └── orders.py       # CRUD + /combine + /export.csv
│       └── reporting/presign.py
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
│   │   ├── api/orders.ts       # typed API helpers
│   │   ├── components/         # Layout, Button
│   │   └── features/
│   │       ├── orders-list/    # table + card view toggle
│   │       ├── orders-edit/    # create + edit forms
│   │       ├── combine/        # filter form → combine → CSV export
│   │       └── reports/        # iframe of /api/reports/latest
│   └── tests/                  # Vitest + React Testing Library
│
├── report-runner/
│   ├── Dockerfile
│   ├── runner.py               # connects to Postgres, runs jasperstarter, writes PDF
│   └── reports/orders_by_month.jrxml
│
├── db/seed.sql                 # 30 rows spanning Jan–Dec 2025
│
├── infra/
│   ├── backend.tf              # partial S3 backend (bucket from backend.hcl)
│   ├── backend.hcl             # account-scoped bucket name — generated by make tf-bootstrap
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf                 # wires all modules
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── network/            # VPC, 2 public + 2 private subnets, NAT
│       ├── rds/                # Postgres 16, default-key encryption, DATABASE_URL secret
│       ├── ecs-cluster/        # Fargate cluster
│       ├── ecs-service/        # task def + service (reused for backend + frontend)
│       ├── alb/                # ALB, HTTP listener; HTTPS if cert ARN set
│       └── ecr/                # backend + frontend repos
│
├── ansible/
│   ├── requirements.yml        # amazon.aws collection
│   ├── inventories/dev/hosts.yml
│   └── playbooks/deploy.yml    # migrate → force-deploy → healthcheck
│
├── docs/architecture.svg
└── .github/workflows/
    ├── ci.yml                  # lint + test + tf fmt/validate
    └── cd.yml                  # build → push → plan → gate → apply → ansible
```

## Known Limitations

- No authentication (Tier 3 scope cut — see HANDOFF.md).
- Single AWS region (`us-east-1`), single environment.
- Report generation is on-demand (`make report` locally; trigger manually in cloud).

## AI Assistance

This project was developed with AI coding assistance. Every line is owned by the candidate and is explainable on demand.
