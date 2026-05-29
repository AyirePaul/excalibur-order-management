# CloudWatch Alarms

Alarm definitions live in `infra/modules/observability/main.tf` and are applied per environment.

| Alarm | Condition | Severity |
|---|---|---|
| `orders-5xx-rate-{env}` | 5xx rate > 2% for 5 min | HIGH |
| `orders-p95-latency-{env}` | p95 latency > 1 s for 5 min | MEDIUM |
| `orders-unhealthy-hosts-{env}` | Unhealthy host count > 0 for 2 min | HIGH |

To receive alerts, set `alarm_actions` in the observability Terragrunt input to an SNS topic ARN.

## Testing alarms locally

```bash
# Force a synthetic 5xx burst
for i in $(seq 1 50); do
  curl -s https://dev.orders.example.com/orders/does-not-exist || true
done
```

Within ~5 minutes the `orders-5xx-rate-dev` alarm transitions to ALARM state.
