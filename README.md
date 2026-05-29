# Order Management — Excalibur Assignment (Tier 4: Senior Associate)

A cloud-native replacement for a legacy order management system. Cumulative scope covers Tier 1 (Junior) through Tier 4 (Senior Associate) of the Excalibur Full Stack Cloud & Web Application Developer assignment.

## Architecture at a Glance

- **Frontend** — React 18 + Vite + TypeScript + Tailwind, served from S3+CloudFront in cloud envs and from nginx in Docker for local dev. OIDC via AWS Cognito.
- **Backend** — FastAPI on Python 3.12, SQLAlchemy 2.x + Alembic, Strawberry GraphQL alongside REST. Runs on ECS Fargate behind an ALB with ACM TLS.
- **Database** — PostgreSQL 16 on RDS, Multi-AZ in `qa` and `prod`, KMS-encrypted, credentials in AWS Secrets Manager.
- **Reporting** — JasperReports `.jrxml`, rendered by a containerized `report-runner` Fargate task on a daily EventBridge schedule, PDFs to S3, embedded in the UI via presigned URL.
- **IaC** — Terraform modules under `infra/modules/`, Terragrunt-layered live envs (`dev`, `qa`, `prod`) under `infra/live/`.
- **Config management** — Ansible roles + Ansible Vault, env-scoped under `ansible/`.
- **CI/CD** — GitHub Actions with OIDC into AWS. `main` → dev (auto), `v*.*.*` tag → qa (auto), `prod` via manual approval.

See `docs/architecture.png` for the full diagram.

## Quick Start — Local

```bash
cp .env.example .env
make up           # docker compose: postgres + adminer + backend + frontend
make seed         # load db/seed.sql
make test         # backend + frontend unit/integration
make e2e          # Playwright against the local stack
```

UI at <http://localhost:5173>, API at <http://localhost:8000>, Swagger at <http://localhost:8000/docs>, GraphiQL at <http://localhost:8000/graphql>.

### Sample curl requests

```bash
# 1. Health check
curl http://localhost:8000/healthz

# 2. Combine orders: amounts > $100 in Q1 2025
curl -s -X POST http://localhost:8000/orders/combine \
  -H "Content-Type: application/json" \
  -d '{"amountOp":"GT","amountValue":100,"dateFrom":"2025-01-01","dateTo":"2025-03-31"}' \
  | python3 -m json.tool

# 3. Create a new order (editor role — local dev bypasses auth)
curl -s -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"order_date":"2025-06-01","order_amount":"299.99","order_description":"Widget bundle"}' \
  | python3 -m json.tool
```

## Quick Start — Cloud (dev)

Prereqs: AWS account, AWS CLI configured, Terraform ≥1.6, Terragrunt ≥0.55, GitHub repo with OIDC role.

```bash
cd infra/live/dev
terragrunt run-all apply
```

After the first apply, populate the GitHub Environment secrets (`AWS_DEPLOY_ROLE_ARN`, `ALB_URL`, Cognito vars) and push to `main` — the `cd.yml` workflow deploys automatically to dev.

## API Summary

| Surface | Path | Notes |
|---|---|---|
| REST | `/orders` (CRUD), `/orders/combine`, `/orders/export.csv` | OpenAPI at `/openapi.json` |
| GraphQL | `/graphql` | Query `joinedOrders`, mutation `upsertOrder`, subscription `orderCombinedRegenerated` |
| Health | `/healthz`, `/readyz` | Liveness + DB ping |
| Docs | `/docs`, `/redoc` | Disabled in `prod` |

## Tech Choices & Why

- **Python/FastAPI over Spring Boot** — faster scaffold, async-first, first-class OpenAPI generation, lighter container.
- **PostgreSQL on RDS Multi-AZ** — `NUMERIC(12,2)` first-class, broad ecosystem, simplest Multi-AZ story.
- **ECS Fargate over EKS** — no control-plane to operate; fits the scope without Kubernetes overhead.
- **Cognito over Auth0/Keycloak** — native to AWS, no third-party dependency, free tier covers the demo.
- **JasperReports over Metabase** — assignment explicitly names it for full rubric credit; the `.jrxml` is portable and the scheduled Fargate runner pattern matches the Tier 4 "scheduled PDF to S3" requirement.
- **Terragrunt over plain Terraform** — assignment requires DRY backend/provider blocks across envs.

## Repo Layout

```
order-management/
├── .env.example                        # copy to .env for local dev
├── .gitignore
├── .pre-commit-config.yaml             # ruff, black, prettier, tflint, detect-secrets
├── .secrets.baseline
├── docker-compose.yml                  # api + db + adminer + web (+ report-runner profile)
├── Makefile                            # up, down, seed, test, lint, e2e, tf-plan, report
├── CODEOWNERS
├── CONTRIBUTING.md
│
├── backend/                            # FastAPI service
│   ├── Dockerfile                      # multi-stage: dev (hot-reload) + runtime (slim)
│   ├── alembic.ini
│   ├── pyproject.toml
│   └── app/
│       ├── main.py                     # app factory, CORS, router wiring, OTel init
│       ├── core/
│       │   ├── config.py               # pydantic-settings — reads env vars
│       │   ├── logging.py              # structlog JSON logging
│       │   ├── security.py             # Cognito JWT verify, viewer/editor deps
│       │   └── telemetry.py            # OTel tracer + metrics setup
│       ├── db/
│       │   ├── base.py                 # SQLAlchemy engine + session + Base
│       │   └── migrations/
│       │       ├── env.py
│       │       └── versions/
│       │           └── 0001_initial.py # order_date, order_detail, order_combined
│       ├── models/                     # SQLAlchemy ORM (order_date, order_detail, order_combined)
│       ├── schemas/
│       │   └── orders.py               # Pydantic DTOs — strict DTO/ORM separation
│       ├── services/
│       │   ├── sort.py                 # generic sort_by(items, key_fn, reverse)
│       │   └── orders.py               # combine logic, CRUD, order_to_read helper
│       ├── api/
│       │   ├── rest/
│       │   │   ├── health.py           # GET /healthz  GET /readyz
│       │   │   └── orders.py           # CRUD + /combine + /export.csv
│       │   └── graphql/
│       │       └── schema.py           # Strawberry: Query, Mutation, Subscription
│       └── reporting/
│           └── presign.py              # S3 presigned URL for latest report PDF
│   └── tests/
│       ├── conftest.py                 # testcontainers Postgres fixtures
│       ├── unit/                       # test_sort, test_schemas, test_services
│       └── integration/                # test_orders_api, test_graphql
│
├── frontend/                           # React 18 + Vite + TypeScript + Tailwind
│   ├── Dockerfile                      # multi-stage: dev (Vite) + runtime (nginx)
│   ├── nginx.conf
│   ├── package.json
│   ├── vite.config.ts
│   ├── tailwind.config.ts
│   ├── playwright.config.ts
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── router.tsx                  # 5 lazy-loaded routes
│   │   ├── auth/
│   │   │   ├── AuthProvider.tsx        # OidcBridge + local-dev mock context
│   │   │   ├── AuthCallback.tsx
│   │   │   ├── ProtectedRoute.tsx      # viewer / editor guards
│   │   │   └── useAuth.ts              # re-exports useAuthContext
│   │   ├── api/
│   │   │   ├── client.ts               # axios instance + token injection
│   │   │   └── orders.ts               # typed API helpers
│   │   ├── components/
│   │   │   ├── Layout.tsx              # nav bar + footer
│   │   │   └── Button.tsx
│   │   └── features/
│   │       ├── orders-list/            # table view + card view toggle
│   │       ├── orders-edit/            # create + edit forms with validation
│   │       ├── combine/                # filter form → combine → CSV export
│   │       └── reports/                # iframe of presigned Jasper PDF
│   ├── tests/                          # Vitest + React Testing Library
│   └── e2e/                            # Playwright: auth setup + orders flow
│
├── report-runner/                      # JasperReports scheduled Fargate task
│   ├── Dockerfile                      # eclipse-temurin:17-jre + jasperstarter
│   ├── runner.py                       # connects to RDS, runs report, uploads to S3
│   └── reports/
│       └── orders_by_month.jrxml       # params: P_DATE_FROM, P_DATE_TO, P_AMOUNT_MIN
│
├── db/
│   └── seed.sql                        # 30 rows spanning Jan–Dec 2025
│
├── infra/
│   ├── modules/                        # reusable Terraform modules
│   │   ├── network/                    # VPC, 2 public + 2 private subnets, NAT, IGW
│   │   ├── kms/                        # CMK with auto-rotation
│   │   ├── rds/                        # Multi-AZ Postgres, KMS-encrypted, two secrets
│   │   ├── ecs-cluster/                # ECS cluster + Fargate capacity providers
│   │   ├── ecs-service/                # task def + service + autoscaling (backend & frontend)
│   │   ├── alb/                        # ALB + ACM TLS + HTTP→HTTPS redirect
│   │   ├── cognito/                    # User Pool, hosted UI, viewer + editor groups
│   │   ├── ecr/                        # repos: backend, frontend, report-runner
│   │   ├── s3-reports/                 # versioned + KMS-encrypted PDF bucket
│   │   ├── eventbridge-schedule/       # report-runner task def + daily 06:00 UTC schedule
│   │   ├── observability/              # CloudWatch dashboard + 3 alarms
│   │   └── github-oidc/               # OIDC provider + deploy role
│   └── live/                           # Terragrunt — env × region × module
│       ├── root.hcl                    # provider + S3/DDB remote backend (DRY)
│       ├── _envcommon/                 # per-module shared inputs (network, rds, ecs-backend, …)
│       ├── dev/
│       │   ├── env.hcl                 # db.t4g.micro, single-AZ, Swagger on
│       │   └── us-east-1/              # alb, cognito, ecr, ecs-backend, ecs-frontend,
│       │                               # eventbridge-schedule, github-oidc, kms, network,
│       │                               # observability, rds, s3-reports
│       ├── qa/
│       │   ├── env.hcl                 # db.t4g.small, Multi-AZ
│       │   └── us-east-1/              # (same module set as dev)
│       └── prod/
│           ├── env.hcl                 # db.t4g.medium, Multi-AZ, deletion protection
│           └── us-east-1/              # (same module set as dev)
│
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml                # amazon.aws collection
│   ├── inventories/{dev,qa,prod}/hosts.yml
│   ├── group_vars/
│   │   ├── all/vars.yml
│   │   └── {dev,qa,prod}/vars.yml + vault.yml   # encrypted with ansible-vault
│   ├── roles/
│   │   ├── app-deploy/                 # update ECS service image tag, wait stable
│   │   ├── db-migrate/                 # one-shot Fargate task: alembic upgrade head
│   │   └── healthcheck/                # verify /healthz post-deploy
│   └── playbooks/
│       ├── deploy.yml                  # db-migrate → app-deploy → healthcheck
│       └── rollback.yml                # revert to previous task definition revision
│
├── observability/
│   ├── dashboards/orders-overview.json # CloudWatch: req rate, p95, 5xx, CPU/mem
│   └── alerts/README.md               # alarm definitions (live in infra/modules/observability)
│
├── docs/
│   ├── architecture.png               # VPC / ALB / ECS / RDS / Cognito / CI-CD
│   └── runbooks/
│       ├── failed-deploy.md
│       ├── db-credential-rotation.md
│       └── healthcheck-rollback.md
│
└── .github/
    └── workflows/
        ├── ci.yml                      # PR: lint + unit + integration + tf validate
        └── cd.yml                      # push main→dev, tag v*.*.*→qa, dispatch→prod
```

## Known Limitations / Deferred

- Tier 5 work is intentionally out of scope: no cross-region replica, no multi-account landing zone, no micro-frontend split, no CQRS decomposition, no Ansible Tower/AWX, no STRIDE PDF, no ADRs.
- GraphQL subscription uses polling fallback rather than WebSockets to keep the ALB path simple.
- Single AWS region (`us-east-1`).
- Dev RDS may run single-AZ to control cost; `qa` and `prod` are Multi-AZ.

## AI Assistance

This project was developed with AI coding assistance. Every line is owned by the candidate and is explainable on demand.
