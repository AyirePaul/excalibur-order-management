# HANDOFF.md — Order Management (Tier 3: Mid-Level)

## Scope

This repo delivers **Tier 3** of the Excalibur assignment. Tier 4 features (GraphQL, Cognito auth, Terragrunt/multi-env, KMS CMK, OpenTelemetry/tracing, Playwright e2e, blue-green rollback, CODEOWNERS) have been **deliberately removed**. The API is open (no authentication) — this is a documented scope cut at Tier 3.

---

## What works

| Feature | Where |
|---|---|
| 3-table schema + Alembic migration + seed data | `backend/app/db/migrations/` + `db/seed.sql` |
| REST CRUD + `/orders/combine` + `/orders/export.csv` | `backend/app/api/rest/orders.py` |
| OpenAPI at `/docs`, `/redoc`, `/openapi.json` | FastAPI auto-generated |
| Strict DTO layer (Pydantic, never expose ORM models) | `backend/app/schemas/orders.py` |
| React Router with ≥3 lazy routes (list/create/edit/combine/reports) | `frontend/src/router.tsx` |
| Tab-Card toggle on orders list | `frontend/src/features/orders-list/OrdersList.tsx` |
| JasperReport — daily cron + on-demand, S3 storage, presigned URL iframe | `report-runner/` + `infra/main.tf` + `frontend/src/features/reports/` |
| Docker Compose local stack | `docker-compose.yml` |
| Terraform (single env, S3+DynamoDB remote state) | `infra/` |
| Ansible single playbook (migrate → deploy → healthcheck) | `ansible/playbooks/deploy.yml` |
| CI: lint + test + coverage + tf validate | `.github/workflows/ci.yml` |
| CD: 3 parallel builds → tf plan → manual gate → tf apply → ansible | `.github/workflows/cd.yml` |
| Structured JSON logging + `/healthz` + `/readyz` | `backend/app/core/logging.py` + `backend/app/api/rest/health.py` |
| Backend unit + integration tests ≥60% coverage | `backend/tests/` (87% actual) |
| Frontend Vitest tests | `frontend/tests/` |
| Architecture diagram | `docs/architecture.svg` |

### Deliberate scope cut — no authentication

At Tier 3 the API is open. Any user can read and mutate orders. The Combine and export buttons are always visible.

---

## Report pipeline

```
report-runner (Fargate one-shot)
  → JasperStarter queries order_combined
  → PDF → s3://orders-reports-<account>/YYYY-MM-DD.pdf

Frontend /reports
  → GET /api/reports/latest-url
        production: S3 presigned GET URL (1h TTL)
        local dev:  /api/reports/latest (served from ./out/ volume mount)
  → <iframe src={url} />
```

**Trigger options:**

| Where | Command |
|---|---|
| Local dev | `make report` — runs report-runner container, writes to `./out/` |
| AWS on-demand | `make report-aws` — runs ECS RunTask, uploads to S3 |
| AWS scheduled | EventBridge rule fires daily at 06:00 UTC automatically |

---

## Local quickstart

```bash
cp .env.example .env           # no edits needed

docker compose up -d --build   # postgres + backend (8000) + frontend (5173)
make seed                      # migrations + 30 seed rows

curl http://localhost:8000/healthz
curl -s -X POST http://localhost:8000/orders/combine \
  -H 'Content-Type: application/json' \
  -d '{"amountOp":"GT","amountValue":100}' | python3 -m json.tool

make test-backend              # requires: uv
make test-frontend             # requires: node/npm

make report                    # generate report → http://localhost:8000/api/reports/latest
```

---

## Deploying to AWS — single environment

### Step 1: Bootstrap Terraform state (once only)

The state bucket name is account-scoped. `infra/backend.hcl` is **committed** to the repo so CI reads it directly.

```bash
make tf-bootstrap
# → creates  s3://orders-tf-state-<account-id>  (versioned)
# → creates  dynamodb/orders-tf-locks
# → writes   infra/backend.hcl
git add infra/backend.hcl && git commit -m "chore: add terraform backend config"
```

### Step 2: Configure and apply Terraform

```bash
make tf-init   # terraform init -backend-config=backend.hcl

cp infra/terraform.tfvars.example infra/terraform.tfvars
# Set acm_certificate_arn if you have a cert (leave "" for HTTP-only)

make tf-plan
make tf-apply
```

Key outputs: `alb_url`, `ecs_cluster_name`, `db_client_sg_id`, `private_subnet_ids`, `ecr_backend_url`, `ecr_frontend_url`, `ecr_report_runner_url`, `reports_bucket`, `report_runner_task_def_arn`.

### Step 3: Build and push images

```bash
ECR=$(terraform -chdir=infra output -raw ecr_backend_url | cut -d'/' -f1)
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR

docker build -t $(terraform -chdir=infra output -raw ecr_backend_url):latest backend
docker push $(terraform -chdir=infra output -raw ecr_backend_url):latest

docker build -t $(terraform -chdir=infra output -raw ecr_frontend_url):latest frontend
docker push $(terraform -chdir=infra output -raw ecr_frontend_url):latest

docker build -t $(terraform -chdir=infra output -raw ecr_report_runner_url):latest report-runner
docker push $(terraform -chdir=infra output -raw ecr_report_runner_url):latest
```

### Step 4: Run Ansible deploy

Service names and task definition families are derived from `ecs_cluster` inside the playbook — only four values needed:

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
| `AWS_ACCESS_KEY_ID` | IAM user access key (ECR + ECS + Terraform + S3 + Secrets Manager) |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret |
| `ECR_REGISTRY` | `<account>.dkr.ecr.us-east-1.amazonaws.com` |

Push to `main` triggers: 3 parallel Docker builds (composite action at `.github/actions/build-push/`) → `terraform plan` → manual reviewer gate → `terraform apply` → Ansible deploy.

---

## Verification results

All checks run on 2026-05-30.

| Check | Result |
|---|---|
| `terraform fmt -recursive -check infra/` | ✅ PASS |
| `terraform init -backend=false && terraform validate` | ✅ PASS (clean) |
| `uv run --extra dev ruff check .` (backend) | ✅ PASS |
| `uv run --extra dev pytest -q --cov=app` (backend) | ✅ PASS — 38 passed, 87% coverage |
| `npm ci && npm run lint && npm run build && npm run test` (frontend) | ✅ PASS — 13 passed |
| `docker compose config --quiet` | ✅ PASS |
| Live `terraform plan/apply` | Requires AWS credentials |
| Ansible deploy | Requires deployed ECS cluster |

---

## Infrastructure notes

**RDS:** SSL disabled (`sslmode=disable`, `rds.force_ssl=0`) — all traffic stays within the VPC private subnet. Connection pool: `pool_size=3, max_overflow=2, pool_recycle=1800` (safe for `db.t4g.micro` ~22 `max_connections` during rolling deploy).

**Security groups:** Migration RunTask and report-runner attach `db_client_sg_id`. Backend attaches both its own SG and `db_client_sg_id` via `additional_sg_ids`. RDS SG allows port 5432 ingress only from `db_client_sg`. `db_client_sg` has explicit egress: 5432 (RDS) + 443 (S3 via NAT).

**Report S3 bucket:** `orders-reports-<account-id>`, CORS allows the ALB origin, 30-day lifecycle expiry.

**CD builds:** Composite action at `.github/actions/build-push/action.yml` — ECR auth + buildx + push, cache scoped per service. Three builds run in parallel, converge at `terraform plan`.

---

## What was removed from Tier 4

- **GraphQL** (`backend/app/api/graphql/`, Strawberry, `python-jose`, `/graphql` route)
- **Cognito auth** (`backend/app/core/security.py`, all `Depends(require_*)` on routes, `frontend/src/auth/`)
- **OpenTelemetry** (`backend/app/core/telemetry.py`, ADOT sidecar, all `opentelemetry-*` deps)
- **Terragrunt + multi-env** (`infra/live/` tree, `_envcommon/`, dev/qa/prod configs)
- **KMS CMK** (replaced with default AWS-managed encryption)
- **Observability module** + CloudWatch dashboards + alarms
- **Playwright e2e** (`frontend/e2e/`, `playwright.config.ts`, `@playwright/test` dep)
- **Blue-green rollback** (`ansible/playbooks/rollback.yml`, rollback CI job)
- **Ansible roles + Vault** (`ansible/roles/`, per-env vault files)
- **Multi-env CI/CD** (tags→qa promotion, rollback job, e2e job)
- **CODEOWNERS**, `docs/runbooks/`
- **KMS, Cognito, GitHub OIDC Terraform modules**

---

*Built with Claude Sonnet 4.6 (1M context). Every line is explainable by the candidate.*
