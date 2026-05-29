# Contributing

## Branching
- `main` is always deployable. Pushes trigger the CD pipeline (manual gate before apply).
- Feature branches: `feat/<short-name>`, `fix/<short-name>`, `chore/<short-name>`.

## Commits
Conventional Commits (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`, `infra`).

## Pull Requests
- CI must be green (lint, unit, integration, terraform fmt + validate).
- Self-review before merging.

## Local Setup
```bash
cp .env.example .env
make up
make test
pre-commit install
```

## Pre-commit
Hooks run on every commit:
- `ruff`, `black` — Python formatting and lint
- `prettier` — TS/TSX/JSON/CSS/Markdown formatting
- `terraform fmt` — HCL formatting
- `detect-secrets` — blocks accidental credential commits

Run manually: `pre-commit run --all-files`.

## Secrets
Never commit `.env` or `*.tfvars` with real values. Use `.env.example` templates. Cloud environments read secrets from AWS Secrets Manager (the `DATABASE_URL` secret is managed by the `rds` Terraform module).
