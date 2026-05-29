# Contributing

## Branching
- `main` is always deployable. Auto-deploys to `dev`.
- Feature branches: `feat/<short-name>`, `fix/<short-name>`, `chore/<short-name>`.
- Tag `vMAJOR.MINOR.PATCH` to promote a build to `qa`.
- `prod` deploys via manual `workflow_dispatch` against the `prod` GitHub Environment with required reviewers.

## Commits
Conventional Commits (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`, `infra`).

## Pull Requests
- At least one self-review checkpoint before requesting review.
- CI must be green (lint, unit, integration, terraform validate).
- E2E against `dev` must be green before promotion to `qa`.

## Local Setup
```bash
cp .env.example .env
make up
make test
pre-commit install
```

## Pre-commit
Hooks run on every commit:
- `ruff`, `black` for Python
- `prettier`, `eslint` for TS/TSX
- `terraform fmt`, `tflint`
- `detect-secrets`

Run manually: `pre-commit run --all-files`.

## Secrets
Never commit `.env`, `*.tfvars` with values, or any populated secret. Use `.env.example` templates. Cloud envs read from AWS Secrets Manager. Ansible secrets live in `ansible/group_vars/<env>/vault.yml` (Ansible Vault encrypted).

## Tests
- Backend: `pytest` under `backend/tests/`. Target ≥60% coverage.
- Frontend: `vitest` under `frontend/tests/`. Target ≥60% coverage.
- E2E: `playwright` under `frontend/e2e/`.
