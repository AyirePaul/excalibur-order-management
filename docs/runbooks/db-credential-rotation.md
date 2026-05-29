# Runbook: DB Credential Rotation

## When to use
- Periodic security rotation (recommended: 90 days).
- Suspected credential leak.

## Process

RDS credentials are stored **only** in AWS Secrets Manager (`orders/{env}/db-credentials`).
The ECS task reads them at startup via the `secrets` block — no credential is in any env var,
tfvars, or code file.

### 1. Rotate the secret

```bash
aws secretsmanager rotate-secret \
  --secret-id orders/dev/db-credentials \
  --rotation-rules AutomaticallyAfterDays=90
```

If auto-rotation is not configured, update manually:

```bash
NEW_PW=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

aws secretsmanager put-secret-value \
  --secret-id orders/dev/db-credentials \
  --secret-string "{\"host\":\"...\",\"port\":5432,\"username\":\"orders\",\"password\":\"${NEW_PW}\",\"dbname\":\"orders\"}"

# Update the RDS instance password to match
aws rds modify-db-instance \
  --db-instance-identifier orders-dev \
  --master-user-password "${NEW_PW}" \
  --apply-immediately
```

### 2. Force new ECS task (picks up the new secret)

```bash
aws ecs update-service \
  --cluster orders-dev \
  --service orders-backend-dev \
  --force-new-deployment
```

### 3. Verify health

```bash
curl https://dev.orders.example.com/readyz
# Expected: {"status":"ready"}
```

## Rollback

If rotation fails and the old password is still known, revert the Secrets Manager value and force a new deployment.
