.PHONY: help up down restart logs migrate seed test test-backend test-frontend lint fmt build clean report tf-bootstrap tf-init tf-plan tf-apply tf-destroy ansible-deploy

help:
	@echo "Local dev:"
	@echo "  make up               # start postgres + backend + frontend"
	@echo "  make down             # stop everything"
	@echo "  make logs             # tail compose logs"
	@echo "  make migrate          # run alembic upgrade head inside backend container"
	@echo "  make seed             # run migrations then load db/seed.sql"
	@echo "  make test             # unit + integration (backend + frontend)"
	@echo "  make lint             # pre-commit run --all-files"
	@echo "  make fmt              # ruff/black/prettier/terraform fmt"
	@echo "  make report           # run JasperReport runner (writes PDF to ./out/)"
	@echo ""
	@echo "Infra (single environment, plain Terraform):"
	@echo "  make tf-bootstrap     # one-time: create state bucket + lock table, generate infra/backend.hcl"
	@echo "  make tf-init          # terraform init -backend-config=infra/backend.hcl"
	@echo "  make tf-plan          # terraform plan in infra/"
	@echo "  make tf-apply         # terraform apply in infra/"
	@echo "  make tf-destroy       # terraform destroy in infra/"
	@echo ""
	@echo "Deploy:"
	@echo "  make ansible-deploy   # run Ansible deploy playbook"

up:
	docker compose up -d --build

down:
	docker compose down -v

restart:
	docker compose restart

logs:
	docker compose logs -f

migrate:
	docker compose run --rm db-migrate

seed: migrate
	docker compose exec -T db psql -U $${POSTGRES_USER:-orders} -d $${POSTGRES_DB:-orders} < db/seed.sql

test: test-backend test-frontend

test-backend:
	cd backend && uv run pytest -v --cov=app --cov-report=term-missing --cov-report=html

test-frontend:
	cd frontend && npm run test -- --coverage

lint:
	pre-commit run --all-files

fmt:
	cd backend && uv run ruff format .
	cd backend && uv run black .
	cd frontend && npx prettier --write .
	cd infra && terraform fmt -recursive

build:
	docker compose build

report:
	@mkdir -p out
	docker compose run --rm \
	  -e POSTGRES_HOST=db \
	  -e POSTGRES_PORT=5432 \
	  -e POSTGRES_USER=$${POSTGRES_USER:-orders} \
	  -e POSTGRES_PASSWORD=$${POSTGRES_PASSWORD:-orders} \
	  -e POSTGRES_DB=$${POSTGRES_DB:-orders} \
	  -e OUTPUT_DIR=/out \
	  -v $$(pwd)/out:/out \
	  report-runner
	@echo "PDF written to ./out/ — visit http://localhost:8000/api/reports/latest to view"

clean:
	docker compose down -v --rmi local
	rm -rf backend/.pytest_cache backend/htmlcov backend/.coverage
	rm -rf frontend/dist frontend/coverage frontend/.vite
	find . -name __pycache__ -exec rm -rf {} +

# ── Terraform ──────────────────────────────────────────────────────────────────

# Bootstrap: create the account-scoped S3 state bucket + DynamoDB lock table,
# then write infra/backend.hcl so subsequent `terraform init` picks it up.
tf-bootstrap:
	@ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text) && \
	BUCKET="orders-tf-state-$${ACCOUNT_ID}" && \
	echo "→ account: $${ACCOUNT_ID}" && \
	echo "→ bucket:  $${BUCKET}" && \
	aws s3api head-bucket --bucket "$${BUCKET}" 2>/dev/null && \
	  echo "bucket already exists, skipping create" || \
	  (aws s3api create-bucket --bucket "$${BUCKET}" --region us-east-1 && \
	   aws s3api put-bucket-versioning \
	     --bucket "$${BUCKET}" \
	     --versioning-configuration Status=Enabled) && \
	aws dynamodb describe-table --table-name orders-tf-locks --region us-east-1 \
	  --query "Table.TableName" --output text 2>/dev/null && \
	  echo "lock table already exists, skipping create" || \
	  aws dynamodb create-table \
	    --table-name orders-tf-locks \
	    --attribute-definitions AttributeName=LockID,AttributeType=S \
	    --key-schema AttributeName=LockID,KeyType=HASH \
	    --billing-mode PAY_PER_REQUEST \
	    --region us-east-1 && \
	echo "bucket = \"$${BUCKET}\"" > infra/backend.hcl && \
	echo "→ wrote infra/backend.hcl" && \
	echo "→ run: make tf-init"

tf-init:
	terraform -chdir=infra init -backend-config=backend.hcl

tf-plan:
	terraform -chdir=infra plan

tf-apply:
	terraform -chdir=infra apply

tf-destroy:
	terraform -chdir=infra destroy

ansible-deploy:
	cd ansible && ansible-playbook -i inventories/dev/hosts.yml playbooks/deploy.yml
