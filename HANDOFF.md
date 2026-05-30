# HANDOFF.md — Order Management (Tier 3: Mid-Level)

## Scope

This repo delivers **Tier 3** of the Excalibur assignment. Tier 4 features (GraphQL, Cognito auth, Terragrunt/multi-env, KMS CMK, OpenTelemetry/tracing, Playwright e2e, blue-green rollback, CODEOWNERS) have been **deliberately removed**. The API is open (no authentication) — this is a documented scope cut at Tier 3.

---

## What works

| Feature | Where |
|---|---|
| 3-table schema (order_date, order_detail, order_combined) + Alembic migration + seed | `backend/app/db/migrations/` + `db/seed.sql` |
| REST CRUD + `/orders/combine` + `/orders/export.csv` | `backend/app/api/rest/orders.py` |
| OpenAPI at `/docs`, `/redoc`, `/openapi.json` | FastAPI auto-generated |
| Strict DTO layer (Pydantic, never expose ORM models) | `backend/app/schemas/orders.py` |
| React Router with ≥3 lazy routes (list/create/edit/combine/reports) | `frontend/src/router.tsx` |
| Tab-Card toggle on orders list | `frontend/src/features/orders-list/OrdersList.tsx` |
| JasperReport — daily cron + on-demand, PDF stored in S3, embedded via presigned URL | `report-runner/` + `infra/main.tf` + `frontend/src/features/reports/Reports.tsx` |
| Docker Compose local stack | `docker-compose.yml` |
| Terraform (single env, plain `terraform`, S3+DynamoDB remote state) | `infra/` |
| Ansible single playbook (migrate → deploy backend+frontend → healthcheck) | `ansible/playbooks/deploy.yml` |
| CI: lint + test + coverage + tf validate | `.github/workflows/ci.yml` |
| CD: 3 parallel builds → tf plan → manual gate → tf apply → ansible | `.github/workflows/cd.yml` |
| Structured JSON logging + `/healthz` + `/readyz` | `backend/app/core/logging.py` + `backend/app/api/rest/health.py` |
| Unit + integration tests ≥60% backend coverage | `backend/tests/` (87% actual) |
| Frontend Vitest tests | `frontend/tests/` |
| Architecture diagram | `docs/architecture.svg` |

### Deliberate scope cut — no authentication

At Tier 3 the API is open. Any user can read and mutate orders. The Combine and export buttons are always visible.

---

## Report embedding

**Local dev:**
```bash
make report    # runs report-runner container, writes PDF to ./out/
# Visit: http://localhost:8000/api/reports/latest
```
The backend mounts `./out` at `/reports` and streams the latest PDF. `GET /api/reports/latest-url` returns `{ url: "/api/reports/latest" }` when no S3 bucket is configured.

**Production (ECS):**
- EventBridge rule runs `report-runner` as a one-shot Fargate task daily at 06:00 UTC
- Report-runner queries `order_combined`, runs JasperStarter, uploads PDF to `s3://orders-reports-<account>/YYYY-MM-DD.pdf`
- `GET /api/reports/latest-url` generates a 1-hour S3 presigned URL
- Frontend fetches the URL via React Query and embeds it in an `<iframe>`
- To trigger on-demand: run the report-runner ECS task manually (ARN in `report_runner_task_def_arn` output)

---

## Local quickstart

```bash
cp .env.example .env           # no edits needed for local dev

docker compose up -d --build   # postgres + backend (port 8000) + frontend (port 5173)
make seed                      # runs migrations then loads 30 seed rows

# Verify
curl http://localhost:8000/healthz
curl -s -X POST http://localhost:8000/orders/combine \
  -H 'Content-Type: application/json' \
  -d '{"amountOp":"GT","amountValue":100}' | python3 -m json.tool

make test-backend              # requires: uv
make test-frontend             # requires: node/npm

make report                    # generate report → open http://localhost:8000/api/reports/latest
```

---

## Deploying to AWS — single environment

### Step 1: Bootstrap Terraform state (once only)

The S3 bucket name is account-scoped for global uniqueness. `infra/backend.hcl` is **committed** to the repo — no account-ID secret needed in GitHub Actions.

```bash
make tf-bootstrap
# → creates  s3://orders-tf-state-<account-id>  (versioned)
# → creates  dynamodb/orders-tf-locks
# → writes   infra/backend.hcl   ← commit this file
git add infra/backend.hcl && git commit -m "chore: add terraform backend config"
```

### Step 2: Configure and apply Terraform

```bash
make tf-init   # terraform init -backend-config=backend.hcl

cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit: set acm_certificate_arn if you have a cert (leave "" for HTTP-only)

make tf-plan
make tf-apply
```

Key outputs: `alb_url`, `ecs_cluster_name`, `db_client_sg_id`, `private_subnet_ids`, `backend_task_def_family`, `frontend_task_def_family`, `backend_service_name`, `frontend_service_name`, `ecr_backend_url`, `ecr_frontend_url`, `ecr_report_runner_url`, `reports_bucket`.

### Step 3: Build and push images

```bash
ECR=$(terraform -chdir=infra output -raw ecr_backend_url | cut -d'/' -f1)
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR

docker build -t $(terraform -chdir=infra output -raw ecr_backend_url):latest backend && \
  docker push $(terraform -chdir=infra output -raw ecr_backend_url):latest

docker build -t $(terraform -chdir=infra output -raw ecr_frontend_url):latest frontend && \
  docker push $(terraform -chdir=infra output -raw ecr_frontend_url):latest

docker build -t $(terraform -chdir=infra output -raw ecr_report_runner_url):latest report-runner && \
  docker push $(terraform -chdir=infra output -raw ecr_report_runner_url):latest
```

### Step 4: Run Ansible deploy

Service names, task definition families, and migration task are all derived from `ecs_cluster` inside the playbook — only four values need to be passed:

```bash
ALB_URL=$(terraform -chdir=infra output -raw alb_url)
CLUSTER=$(terraform -chdir=infra output -raw ecs_cluster_name)
SUBNETS=$(terraform -chdir=infra output -json private_subnet_ids)
SG=$(terraform -chdir=infra output -raw db_client_sg_id)

cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy.yml \
  --extra-vars "$(jq -nc \
    --arg c "$CLUSTER" \
    --arg a "$ALB_URL" \
    --argjson s "$SUBNETS" \
    --arg sg "$SG" \
    --arg t "latest" \
    '{ecs_cluster:$c, alb_url:$a, migrate_subnets:$s, migrate_security_groups:[$sg], image_tag:$t}')"
```

### Step 5: CI/CD (GitHub Actions)

Set these secrets under the `production` GitHub Environment:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key (ECR push + ECS + Terraform + S3 + Secrets Manager) |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret |
| `ECR_REGISTRY` | `<account>.dkr.ecr.us-east-1.amazonaws.com` |

Push to `main` triggers: parallel builds (backend + frontend + report-runner) → `terraform plan` → manual reviewer gate → `terraform apply` → Ansible deploy.

---

## Verification results

All checks run on 2026-05-30.

| Check | Result |
|---|---|
| `terraform fmt -recursive -check infra/` | ✅ PASS |
| `terraform init -backend=false && terraform validate` (infra/) | ✅ PASS (clean) |
| `uv run --extra dev ruff check .` (backend) | ✅ PASS |
| `uv run --extra dev pytest -q --cov=app` (backend) | ✅ PASS — 38 passed, 87% coverage |
| `npm ci && npm run lint && npm run build && npm run test` (frontend) | ✅ PASS — 13 passed |
| `docker compose config --quiet` | ✅ PASS |
| Live `terraform plan/apply` | Requires AWS credentials |
| Ansible deploy | Requires deployed ECS cluster |

---

## Infrastructure notes

**RDS connection:** SSL disabled (`sslmode=disable`, `rds.force_ssl=0`) — traffic stays within the VPC private subnet. Connection pool: `pool_size=3, max_overflow=2` (safe for `db.t4g.micro` with ~22 `max_connections` during rolling deploy).

**Security groups:** The migration ECS RunTask and report-runner attach `db_client_sg_id`. The backend ECS service attaches both its own SG and `db_client_sg_id` via `additional_sg_ids`. The RDS SG only allows port 5432 ingress from `db_client_sg`.

**Report pipeline:** `report-runner` → S3 bucket `orders-reports-<account>` → backend presigns URL → frontend iframe. S3 CORS allows the ALB origin. Reports expire after 30 days (lifecycle rule). EventBridge triggers daily at 06:00 UTC.

**CD parallelism:** Three Docker builds run in parallel (composite action at `.github/actions/build-push/`), converging at `terraform plan`.

---

## What was removed from Tier 4

- **GraphQL** (`backend/app/api/graphql/`, Strawberry, `python-jose`, `/graphql` route)
- **Cognito auth** (`backend/app/core/security.py`, all `Depends(require_*)` on routes, `frontend/src/auth/`)
- **OpenTelemetry** (`backend/app/core/telemetry.py`, ADOT sidecar in ECS task, all `opentelemetry-*` deps)
- **Terragrunt + multi-env** (`infra/live/` tree with root.hcl, `_envcommon/`, dev/qa/prod configs)
- **KMS CMK** (replaced with default AWS-managed encryption)
- **Observability module** + CloudWatch dashboards + alarms
- **Playwright e2e** (`frontend/e2e/`, `playwright.config.ts`, `@playwright/test` dep)
- **Blue-green rollback** (`ansible/playbooks/rollback.yml`, rollback CI job)
- **Ansible roles + Vault** (`ansible/roles/`, `group_vars/{dev,qa,prod}/vault.yml`)
- **Multi-env CI/CD** (tags→qa promotion, rollback job, e2e job)
- **CODEOWNERS**, `docs/runbooks/`
- **KMS, Cognito, GitHub OIDC Terraform modules**

---

*Built with Claude Sonnet 4.6 (1M context). Every line is explainable by the candidate.*
