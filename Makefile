.PHONY: help up down restart logs migrate seed test test-backend test-frontend e2e lint fmt build clean report tf-plan tf-apply tf-destroy ansible-deploy ansible-rollback

help:
	@echo "Local dev:"
	@echo "  make up               # start postgres + backend + frontend"
	@echo "  make down             # stop everything"
	@echo "  make logs             # tail compose logs"
	@echo "  make migrate          # run alembic upgrade head inside backend container"
	@echo "  make seed             # run migrations then load db/seed.sql"
	@echo "  make test             # unit + integration (backend + frontend)"
	@echo "  make e2e              # Playwright e2e"
	@echo "  make lint             # pre-commit run --all-files"
	@echo "  make fmt              # ruff/black/prettier/terraform fmt"
	@echo ""
	@echo "Infra (pass ENV=dev|qa|prod):"
	@echo "  make tf-apply-foundation ENV=dev  # step 1 (first time): apply kms/network/cognito/ecr/ecs-cluster/github-oidc"
	@echo "  make tf-apply ENV=dev             # step 2: apply remaining modules (run --all apply)"
	@echo "  make tf-plan  ENV=dev             # plan changes — works once state exists"
	@echo "  make tf-destroy ENV=dev"
	@echo ""
	@echo "Deploy:"
	@echo "  make ansible-deploy ENV=dev"
	@echo "  make ansible-rollback ENV=dev"

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

e2e:
	cd frontend && npx playwright test

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
	docker compose exec db psql -U $${POSTGRES_USER:-orders} -d $${POSTGRES_DB:-orders} \
	  -c "SELECT COUNT(*) FROM order_combined;" 2>/dev/null || true
	docker compose run --rm \
	  -e POSTGRES_HOST=db \
	  -e POSTGRES_PORT=5432 \
	  -e POSTGRES_USER=$${POSTGRES_USER:-orders} \
	  -e POSTGRES_PASSWORD=$${POSTGRES_PASSWORD:-orders} \
	  -e POSTGRES_DB=$${POSTGRES_DB:-orders} \
	  -e OUTPUT_DIR=/out \
	  -v $$(pwd)/out:/out \
	  report-runner
	@echo "PDF written to ./out/"

clean:
	docker compose down -v --rmi local
	rm -rf backend/.pytest_cache backend/htmlcov backend/.coverage
	rm -rf frontend/dist frontend/coverage frontend/.vite
	find . -name __pycache__ -exec rm -rf {} +

ENV ?= dev

# Terragrunt >=1.0 uses 'run --all'; older versions used 'run-all'

# First-time bootstrap: apply foundation modules (no upstream deps) so
# run --all plan/apply can resolve their outputs on subsequent runs.
FOUNDATION := kms network cognito ecr github-oidc ecs-cluster
tf-apply-foundation:
	@for unit in $(FOUNDATION); do \
		echo "==> applying $$unit"; \
		(cd infra/live/$(ENV)/us-east-1/$$unit && terragrunt apply --auto-approve --terragrunt-non-interactive) || exit 1; \
	done

tf-plan:
	cd infra/live/$(ENV)/us-east-1 && terragrunt run --all plan

tf-apply:
	cd infra/live/$(ENV)/us-east-1 && terragrunt run --all apply

tf-destroy:
	cd infra/live/$(ENV)/us-east-1 && terragrunt run --all destroy

ansible-deploy:
	cd ansible && ansible-playbook -i inventories/$(ENV)/hosts.yml playbooks/deploy.yml

ansible-rollback:
	cd ansible && ansible-playbook -i inventories/$(ENV)/hosts.yml playbooks/rollback.yml
