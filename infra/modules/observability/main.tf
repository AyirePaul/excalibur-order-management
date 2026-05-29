locals {
  alb_arn_suffix = var.alb_arn_suffix
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
# dashboard_body is passed from the Terragrunt unit via file() so the path
# resolves correctly in the repo root rather than inside .terragrunt-cache/.

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "orders-overview-${var.env}"
  dashboard_body = var.dashboard_body
}

# ── Alarms ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "error_5xx_rate" {
  alarm_name          = "orders-5xx-rate-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 2
  alarm_description   = "5xx error rate >2% for 5 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "5xx Rate %"
    return_data = true
  }
  metric_query {
    id = "m1"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
    }
  }
  metric_query {
    id = "m2"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "p95_latency" {
  alarm_name          = "orders-p95-latency-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 1000
  alarm_description   = "p95 latency >1s for 5 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  metric_name        = "TargetResponseTime"
  namespace          = "AWS/ApplicationELB"
  period             = 300
  extended_statistic = "p95"
  dimensions         = { LoadBalancer = local.alb_arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "orders-unhealthy-hosts-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Unhealthy host count >0 for 2 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = local.alb_arn_suffix }
}

# ── Log Groups ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/orders-${var.env}"
  retention_in_days = 30
  tags              = var.tags
}
