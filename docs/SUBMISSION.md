# Order Management — Candidate Submission

**Role targeted:** Mid-Level Full Stack Cloud & Web Application Developer (Tier 3)
**Stack:** Python · FastAPI · React 18 · PostgreSQL · AWS ECS Fargate · Terraform · Ansible · GitHub Actions
**Scope cut:** API is open (no authentication) — deliberate at Tier 3. GraphQL, Cognito, Terragrunt, and blue-green rollback are Tier 4 and above.

---

## Architecture

The application is a single-environment AWS deployment. The frontend (React SPA) and backend (FastAPI) each run as Fargate services behind a shared Application Load Balancer. PostgreSQL lives on RDS in private subnets. A one-shot Fargate task generates the JasperReport on a daily schedule and writes it to S3. GitHub Actions drives the full CI/CD pipeline from build through deployment.

```mermaid
graph TD
    subgraph Internet
        User([Browser])
        GHA([GitHub Actions])
    end

    subgraph AWS VPC
        subgraph Public Subnets
            ALB[Application Load Balancer]
        end

        subgraph Private Subnets
            FE[Frontend Service\nFargate]
            BE[Backend Service\nFargate]
            RR[Report Runner\nFargate — one-shot]
            RDS[(PostgreSQL\nRDS)]
        end

        subgraph Storage
            SM[Secrets Manager\nDATABASE_URL]
            S3[S3 Bucket\nReport PDFs]
            ECR[ECR\nContainer Images]
        end
    end

    User -->|HTTPS| ALB
    ALB -->|/| FE
    ALB -->|/api| BE
    BE -->|psycopg3 SSL| RDS
    BE -->|presign URL| S3
    RR -->|query + upload| RDS
    RR --> S3
    BE -.->|reads at startup| SM
    GHA -->|push images| ECR
    GHA -->|terraform apply| ALB
    GHA -->|ansible deploy| BE
    GHA -->|ansible deploy| FE
```

---

## 1. Local Stack

The entire stack starts with a single command. Docker Compose brings up Postgres, runs Alembic migrations automatically via a one-shot `db-migrate` service, then starts the FastAPI backend and Vite dev server. No local database or runtime installation needed beyond Docker.

![Local stack running — docker compose up, all services healthy](./evidence/screenshots/01-local-stack.png)

![Health check and seed data — curl /healthz + Adminer showing 30 rows in order_date](./evidence/screenshots/02-healthcheck-seed.png)

---

## 2. Front-End

The React SPA has five lazy-loaded routes. The Orders list supports a **Tab/Card toggle** with two visually distinct layouts (table grid vs amber card tiles). Create and Edit forms include client-side validation. The Combine page posts filters to the API and renders results inline.

![Orders list — Table view (left) and Card view (right)](./evidence/screenshots/03-orders-list-toggle.png)

![Create form with client-side validation error visible](./evidence/screenshots/04-create-form-validation.png)

![Combine page — filter form submitted, results table rendered below](./evidence/screenshots/05-combine-results.png)

---

## 3. API

FastAPI auto-generates a full OpenAPI 3.x spec. Swagger UI is available at `/docs` and Redoc at `/redoc` in non-production environments. Every endpoint goes through a Pydantic DTO layer — ORM models are never serialised directly.

![Swagger UI at /docs showing all endpoints (CRUD, /combine, /export.csv, health)](./evidence/screenshots/06-swagger-ui.png)

![POST /orders/combine in Swagger — request body with filters, 200 response with joined collection](./evidence/screenshots/07-combine-api-response.png)

---

## 4. Tests & Code Quality

Backend unit and integration tests run with `pytest` + `testcontainers` (real Postgres, no mocks). Coverage is reported per module. Frontend components are tested with Vitest + React Testing Library. Ruff enforces style with zero warnings.

![Backend test run — pytest output with coverage table (≥60% line coverage)](./evidence/screenshots/08-backend-tests-coverage.png)

![Frontend test run — vitest output, all tests passing](./evidence/screenshots/09-frontend-tests.png)

---

## 5. Infrastructure (Terraform)

A single Terraform root (`infra/`) provisions the entire environment: VPC with two public and two private subnets across two AZs, NAT gateway, ALB with target groups, ECS cluster, two Fargate services (backend + frontend), RDS Postgres with SSL enforced, Secrets Manager for the database URL, ECR repos, and an S3 bucket for reports. State is stored in S3 with DynamoDB locking.

![terraform validate — clean output ("The configuration is valid")](./evidence/screenshots/10-terraform-validate.png)

![terraform plan — resource list showing VPC, subnets, ALB, ECS, RDS, Secrets Manager](./evidence/screenshots/11-terraform-plan.png)

---

## 6. CI Pipeline

On every push and pull request, GitHub Actions runs backend lint (`ruff`), backend tests with a coverage artifact, frontend lint + build + tests, and `terraform fmt/validate`. All jobs must be green before a PR can merge.

![CI workflow — all jobs green (backend-test, frontend-build, tf-validate)](./evidence/screenshots/12-ci-green.png)

![Backend coverage artifact in CI run artifacts panel](./evidence/screenshots/13-ci-coverage-artifact.png)

---

## 7. CD Pipeline

Pushing to `main` triggers a deployment pipeline: three Docker images built in parallel → pushed to ECR → `terraform plan` → `terraform apply` → Ansible deploys (migrations → ECS service update → healthcheck).

![CD workflow — full run complete, all jobs green including ansible-deploy](./evidence/screenshots/14-cd-full-green.png)

![Ansible deploy job logs — migration exit 0, service stabilised, /healthz returned 200](./evidence/screenshots/15-ansible-deploy-logs.png)

---

## 8. Reporting

`report-runner` is a containerised JasperReports task. It connects to PostgreSQL, runs the parameterised `orders_by_month.jrxml` template (filterable by date range and amount threshold), and writes the PDF to S3. The backend generates a presigned URL; the frontend embeds it in an iframe on the `/reports` route.

![make report terminal output — runner completes, PDF written](./evidence/screenshots/16-report-runner-output.png)

![Reports page in the browser — PDF rendered in iframe (Orders by Month with totals)](./evidence/screenshots/17-report-embedded.png)

---

## 9. Deployed Stack

After `terraform apply` and the Ansible deploy, the application is live on the ALB DNS. Structured JSON logs flow to CloudWatch.

![Live ALB endpoint — curl /healthz returning {"status":"ok"} from the deployed ECS service](./evidence/screenshots/18-live-healthz.png)

![CloudWatch log group /ecs/orders-backend — JSON structured log entries](./evidence/screenshots/19-cloudwatch-logs.png)

---

## Screenshot index

| File | Section |
|---|---|
| `01-local-stack.png` | Docker Compose — all services healthy |
| `02-healthcheck-seed.png` | `/healthz` response + Adminer row count |
| `03-orders-list-toggle.png` | Table view vs Card view |
| `04-create-form-validation.png` | Client-side validation error |
| `05-combine-results.png` | Combine filter form + results |
| `06-swagger-ui.png` | Full endpoint list in Swagger |
| `07-combine-api-response.png` | POST /combine response body |
| `08-backend-tests-coverage.png` | pytest coverage report |
| `09-frontend-tests.png` | Vitest all passing |
| `10-terraform-validate.png` | `terraform validate` clean |
| `11-terraform-plan.png` | `terraform plan` resource list |
| `12-ci-green.png` | CI all jobs green |
| `13-ci-coverage-artifact.png` | Coverage artifact in CI |
| `14-cd-full-green.png` | CD all jobs green |
| `15-ansible-deploy-logs.png` | Ansible task output |
| `16-report-runner-output.png` | `make report` terminal |
| `17-report-embedded.png` | PDF in `/reports` UI |
| `18-live-healthz.png` | Live ALB health response |
| `19-cloudwatch-logs.png` | CloudWatch JSON logs |

Drop screenshots into `docs/evidence/screenshots/` using the filenames above and they will render inline in this document.
