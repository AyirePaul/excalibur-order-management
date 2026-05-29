# HANDOFF.md — Order Management (Tier 3: Mid-Level)

## Scope

This repo delivers **Tier 3** of the Excalibur assignment. Tier 4 features (GraphQL, Cognito auth, Terragrunt/multi-env, KMS CMK, OpenTelemetry/tracing, EventBridge/scheduled reports, Playwright e2e, blue-green rollback, CODEOWNERS) have been **deliberately removed**. The API is open (no authentication) — this is a documented scope cut at Tier 3.

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
| JasperReport embedded via same-origin iframe | `report-runner/` + `frontend/src/features/reports/Reports.tsx` |
| Docker Compose local stack | `docker-compose.yml` |
| Terraform (single env, plain `terraform`, S3+DynamoDB remote state) | `infra/` |
| Ansible single playbook (migrate → deploy → healthcheck) | `ansible/playbooks/deploy.yml` |
| CI: lint + test + coverage + tf validate | `.github/workflows/ci.yml` |
| CD: build → push → tf plan → manual gate → tf apply → ansible | `.github/workflows/cd.yml` |
| Structured JSON logging + `/healthz` + `/readyz` | `backend/app/core/logging.py` + `backend/app/api/rest/health.py` |
| Unit + integration tests ≥60% backend coverage | `backend/tests/` (87% actual) |
| Frontend Vitest tests | `frontend/tests/` |
| Architecture diagram | `docs/architecture.svg` |

### Deliberate scope cut — no authentication

At Tier 3 the API is open. Any user can read and mutate orders. The Combine and export buttons are always visible.

---

## Report embedding

The JasperReport runs on demand:

```bash
make report           # runs report-runner container, writes PDF to ./out/
```

The backend mounts `./out` at `/reports` and serves the latest PDF at `GET /api/reports/latest`. The frontend `/reports` route embeds it via `<iframe src="/api/reports/latest" />`. This is a same-origin request — no cross-origin S3 presigned-URL issues.

In production (after deploying to ECS), trigger report generation via the `report` profile container, or run it locally and push the PDF to wherever the backend can reach it.

---

## Local quickstart

```bash
cd order-management
cp .env.example .env           # no edits needed for local dev

docker compose up -d --build   # postgres + backend (port 8000) + frontend (port 5173)
make seed                      # runs migrations then loads 30 seed rows

# Verify
curl http://localhost:8000/healthz
curl -s -X POST http://localhost:8000/orders/combine \
  -H 'Content-Type: application/json' \
  -d '{"amountOp":"GT","amountValue":100}' | python3 -m json.tool

# Run tests
make test-backend              # requires: uv
make test-frontend             # requires: node/npm

# Generate report
make report                    # writes PDF to ./out/
# Then visit: http://localhost:8000/api/reports/latest
```

---

## Deploying to AWS — single environment

### Step 1: Bootstrap Terraform state (once only)

The S3 bucket name is account-scoped (`orders-tf-state-<account-id>`) for global uniqueness. `infra/backend.hcl` is **committed** to the repo so CI reads it directly — no account-ID secret needed in GitHub Actions.

Run once to create the bucket + lock table and generate the committed file:

```bash
make tf-bootstrap
# → creates  s3://orders-tf-state-<account-id>  (versioned)
# → creates  dynamodb/orders-tf-locks
# → writes   infra/backend.hcl   ← commit this file
git add infra/backend.hcl && git commit -m "chore: add terraform backend config"
```

If you prefer to do it manually:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="orders-tf-state-${ACCOUNT_ID}"

aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name orders-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

echo "bucket = \"${BUCKET}\"" > infra/backend.hcl
# commit infra/backend.hcl
```

### Step 2: Configure and apply Terraform

```bash
make tf-init   # terraform init -backend-config=backend.hcl (run from infra/)

cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit terraform.tfvars: set acm_certificate_arn if you have a cert (leave "" for HTTP-only)

make tf-plan
make tf-apply
```

Key outputs: `alb_url`, `ecs_cluster_name`, `ecs_backend_sg_id`, `private_subnet_ids`, `ecr_backend_url`, `ecr_frontend_url`.

### Step 3: Build and push images

```bash
ECR_BACKEND=$(terraform -chdir=infra output -raw ecr_backend_url)
ECR_FRONTEND=$(terraform -chdir=infra output -raw ecr_frontend_url)

aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_BACKEND

docker build -t $ECR_BACKEND:latest backend
docker push $ECR_BACKEND:latest

docker build -t $ECR_FRONTEND:latest frontend
docker push $ECR_FRONTEND:latest
```

### Step 4: Run Ansible deploy

```bash
ALB_URL=$(terraform -chdir=infra output -raw alb_url)
CLUSTER=$(terraform -chdir=infra output -raw ecs_cluster_name)
SUBNETS=$(terraform -chdir=infra output -json private_subnet_ids)
SG=$(terraform -chdir=infra output -raw ecs_backend_sg_id)

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

Set these GitHub repository secrets (under the `production` Environment):

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key for an IAM user with ECR push + ECS + Terraform permissions |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret access key |
| `ECR_REGISTRY` | `<account>.dkr.ecr.us-east-1.amazonaws.com` |

Push to `main` triggers the full CD pipeline: build → push → `terraform plan` → manual gate (required reviewer on `production` environment) → `terraform apply` → Ansible deploy.

---

## Verification results (post-descope)

All checks run on 2026-05-29.

| Check | Result |
|---|---|
| `terraform fmt -recursive -check infra/` | ✅ PASS |
| `terraform init -backend=false && terraform validate` (infra/) | ✅ PASS (clean, no warnings) |
| `uv run ruff check .` (backend) | ✅ PASS |
| `uv run pytest -q --cov=app` (backend) | ✅ PASS — 38 passed, 87% coverage |
| `npm ci` (frontend) | ✅ PASS |
| `npm run lint` (frontend) | ✅ PASS (0 errors) |
| `npm run build` (frontend) | ✅ PASS |
| `npm run test` (frontend) | ✅ PASS — 13 passed |
| `docker compose config --quiet` | ✅ PASS |
| Live `terraform plan/apply` | Not run — requires AWS credentials |
| Ansible deploy | Not run — requires deployed ECS cluster |

---

## What was removed from Tier 4

- **GraphQL** (`backend/app/api/graphql/`, Strawberry, `python-jose`, `/graphql` route)
- **Cognito auth** (`backend/app/core/security.py`, all `Depends(require_*)` on routes, `frontend/src/auth/`)
- **OpenTelemetry** (`backend/app/core/telemetry.py`, ADOT sidecar in ECS task, all `opentelemetry-*` deps)
- **Terragrunt + multi-env** (`infra/live/` tree with root.hcl, `_envcommon/`, dev/qa/prod configs)
- **KMS CMK** (replaced with default AWS-managed encryption on RDS and ECR)
- **Observability module** + CloudWatch dashboards + alarms (`observability/` dir, `infra/modules/observability/`)
- **EventBridge scheduled reports** (`infra/modules/eventbridge-schedule/`, S3 presigned-URL report delivery)
- **Playwright e2e** (`frontend/e2e/`, `playwright.config.ts`, `@playwright/test` dep)
- **Blue-green rollback** (`ansible/playbooks/rollback.yml`, rollback CI job)
- **Ansible roles + Vault** (`ansible/roles/`, `group_vars/{dev,qa,prod}/vault.yml`)
- **Multi-env CI/CD** (tags→qa promotion, rollback job, Playwright e2e job)
- **CODEOWNERS**, `docs/runbooks/`
- **KMS, Cognito, GitHub OIDC Terraform modules** (`infra/modules/{kms,cognito,github-oidc}`)

---

*Built by Claude Sonnet 4.6 (1M context). Every line is explainable by the candidate.*
