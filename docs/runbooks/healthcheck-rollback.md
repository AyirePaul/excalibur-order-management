# Runbook: Healthcheck Failure & Rollback

## Triggers
- `/healthz` returns non-200 after a deployment.
- CloudWatch alarm `orders-unhealthy-hosts-{env}` fires.
- Automated rollback in CI (`rollback-on-failure` job) has already run.

## Manual rollback steps

### Option A — Ansible (preferred)

```bash
make ansible-rollback ENV=dev
# Rolls ECS service back to the previous task definition revision
```

### Option B — AWS CLI

```bash
# 1. Find the last good task definition revision
aws ecs list-task-definitions \
  --family-prefix orders-backend-dev \
  --sort DESC \
  --query 'taskDefinitionArns[:5]'

# 2. Roll back the service
PREV_ARN="arn:aws:ecs:us-east-1:ACCOUNT:task-definition/orders-backend-dev:N-1"

aws ecs update-service \
  --cluster orders-dev \
  --service orders-backend-dev \
  --task-definition "${PREV_ARN}" \
  --force-new-deployment

# 3. Watch for stability
aws ecs wait services-stable \
  --cluster orders-dev \
  --services orders-backend-dev
```

### Option C — GitHub Actions

Re-run the `rollback-on-failure` job from the failed CD workflow run.

## Verification

```bash
curl https://dev.orders.example.com/healthz
# Expected: {"status":"ok"}

curl https://dev.orders.example.com/readyz
# Expected: {"status":"ready"}
```

## Post-mortem

After service is restored:
1. Identify root cause from ECS logs.
2. Write a fix and push to a feature branch.
3. CI must pass before merging to `main`.
