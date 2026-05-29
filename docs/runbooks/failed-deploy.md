# Runbook: Failed Deploy

## Symptoms
- CI/CD pipeline fails at the `ansible-deploy` or `e2e` step.
- ECS service shows `RUNNING < DESIRED` after deployment.

## Immediate response

1. **Check GitHub Actions logs** — identify the failing step.

2. **Check ECS events** for the service:
   ```bash
   aws ecs describe-services \
     --cluster orders-dev \
     --services orders-backend-dev \
     --query 'services[0].events[:5]'
   ```

3. **Check CloudWatch logs** for the container:
   ```bash
   aws logs tail /ecs/orders-backend-dev --follow
   ```

4. **Trigger rollback** (automated on e2e failure, or manual):
   ```bash
   make ansible-rollback ENV=dev
   # or in CI: re-run the rollback-on-failure job
   ```

## Root cause investigation

| Symptom | Likely cause |
|---|---|
| Container exits immediately | Missing env vars or bad image |
| DB connection refused | Security group or RDS parameter issue |
| `/healthz` returns 500 | App startup failure — check logs |
| ECS placement failure | Insufficient capacity or CPU/memory misconfiguration |

## Recovery

After identifying root cause, push a fix to `main`. The CD pipeline auto-deploys and runs e2e.
If the fix must be hotfixed in prod, use `workflow_dispatch` on `cd-prod.yml`.
