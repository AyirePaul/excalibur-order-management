data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── IAM — task execution role (ECR pull + CloudWatch logs + secret fetch) ───

resource "aws_iam_role" "exec" {
  name = "orders-report-runner-exec-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "exec_managed" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "exec_secrets" {
  name = "pull-db-url-secret"
  role = aws_iam_role.exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SecretsManager"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_url_secret_arn]
      }, {
      Sid      = "KMSDecrypt"
      Effect   = "Allow"
      Action   = ["kms:Decrypt"]
      Resource = [var.kms_key_arn]
    }]
  })
}

# ── IAM — task role (S3 write for PDF + KMS) ─────────────────────────────────

resource "aws_iam_role" "task" {
  name = "orders-report-runner-task-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "task" {
  name = "report-runner-policy"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3ReportWrite"
      Effect = "Allow"
      Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.reports_bucket}",
        "arn:aws:s3:::${var.reports_bucket}/*",
      ]
      }, {
      Sid      = "KMSDecrypt"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = [var.kms_key_arn]
    }]
  })
}

# ── CloudWatch log group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "runner" {
  name              = "/ecs/orders-report-runner-${var.env}"
  retention_in_days = 30
  tags              = var.tags
}

# ── ECS task definition for the report-runner (one-shot Fargate task) ────────

resource "aws_ecs_task_definition" "runner" {
  family                   = "orders-report-runner-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "report-runner"
    image     = var.image_uri
    essential = true
    environment = [
      { name = "REPORTS_BUCKET", value = var.reports_bucket },
      { name = "AWS_REGION", value = data.aws_region.current.name },
    ]
    secrets = [{
      name      = "DATABASE_URL"
      valueFrom = var.db_url_secret_arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.runner.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  tags = var.tags
}

# ── IAM — EventBridge Scheduler role (RunTask + PassRole) ────────────────────

resource "aws_iam_role" "scheduler" {
  name = "orders-report-scheduler-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "scheduler" {
  name = "run-report-task"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RunTask"
      Effect = "Allow"
      Action = ["ecs:RunTask"]
      Resource = [
        aws_ecs_task_definition.runner.arn,
        "${aws_ecs_task_definition.runner.arn_without_revision}:*",
      ]
      }, {
      Sid      = "PassRole"
      Effect   = "Allow"
      Action   = ["iam:PassRole"]
      Resource = [aws_iam_role.exec.arn, aws_iam_role.task.arn]
    }]
  })
}

# ── EventBridge Scheduler — daily 06:00 UTC ───────────────────────────────────

resource "aws_scheduler_schedule" "daily_report" {
  name = "orders-daily-report-${var.env}"

  flexible_time_window { mode = "OFF" }

  schedule_expression          = "cron(0 6 * * ? *)"
  schedule_expression_timezone = "UTC"

  target {
    arn      = var.cluster_arn
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.runner.arn
      launch_type         = "FARGATE"
      network_configuration {
        subnets          = var.private_subnet_ids
        security_groups  = var.security_group_ids
        assign_public_ip = false
      }
    }
  }
}
