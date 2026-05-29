data "aws_caller_identity" "current" {}

locals {
  tags    = { Project = "orders", ManagedBy = "terraform" }
  alb_url = var.acm_certificate_arn != "" ? "https://${module.alb.alb_dns_name}" : "http://${module.alb.alb_dns_name}"
}

module "network" {
  source             = "./modules/network"
  env                = var.name_prefix
  availability_zones = var.availability_zones
  tags               = local.tags
}

module "ecr" {
  source     = "./modules/ecr"
  env        = var.name_prefix
  project    = "orders"
  repo_names = ["backend", "frontend", "report-runner"]
  tags       = local.tags
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"
  env    = var.name_prefix
  tags   = local.tags
}

module "alb" {
  source              = "./modules/alb"
  env                 = var.name_prefix
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  acm_certificate_arn = var.acm_certificate_arn
  tags                = local.tags
}

module "rds" {
  source             = "./modules/rds"
  env                = var.name_prefix
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  db_username        = var.db_username
  db_name            = var.db_name
  tags               = local.tags
}

module "backend" {
  source             = "./modules/ecs-service"
  env                = var.name_prefix
  service_name       = "backend"
  vpc_id             = module.network.vpc_id
  cluster_arn        = module.ecs_cluster.cluster_arn
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.backend_target_group_arn
  image_uri          = var.backend_image
  container_port     = 8000
  additional_sg_ids  = [module.rds.db_client_sg_id]
  secrets = [{
    name      = "DATABASE_URL"
    valueFrom = module.rds.db_url_secret_arn
  }]
  secret_arns = [module.rds.db_url_secret_arn]
  environment_vars = [
    { name = "APP_ENV", value = var.name_prefix },
    { name = "ENABLE_DOCS", value = "true" },
    { name = "CORS_ORIGINS", value = local.alb_url },
    { name = "REPORTS_BUCKET", value = aws_s3_bucket.reports.bucket },
    { name = "AWS_REGION", value = "us-east-1" },
  ]
  tags = local.tags
}

# Allow backend task role to read from the reports bucket (for presigned URL signing)
resource "aws_iam_role_policy" "backend_s3_reports" {
  name = "${var.name_prefix}-backend-s3-reports"
  role = module.backend.task_role_arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.reports.arn, "${aws_s3_bucket.reports.arn}/*"]
    }]
  })
}

module "frontend" {
  source             = "./modules/ecs-service"
  env                = var.name_prefix
  service_name       = "frontend"
  vpc_id             = module.network.vpc_id
  cluster_arn        = module.ecs_cluster.cluster_arn
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.frontend_target_group_arn
  image_uri          = var.frontend_image
  container_port     = 80
  tags               = local.tags
}

# ── S3 reports bucket ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "reports" {
  bucket        = "${var.name_prefix}-reports-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_cors_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = [local.alb_url]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    id     = "expire-old-reports"
    status = "Enabled"
    expiration { days = 30 }
  }
}

# ── Report-runner ECS task (one-shot, invoked by cron or manually) ────────────

resource "aws_iam_role" "report_runner_exec" {
  name = "${var.name_prefix}-report-runner-exec"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "report_runner_exec_managed" {
  role       = aws_iam_role.report_runner_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "report_runner_exec_secret" {
  name = "${var.name_prefix}-report-runner-exec-secret"
  role = aws_iam_role.report_runner_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [module.rds.db_url_secret_arn]
    }]
  })
}

resource "aws_iam_role" "report_runner_task" {
  name = "${var.name_prefix}-report-runner-task"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "report_runner_s3" {
  name = "${var.name_prefix}-report-runner-s3"
  role = aws_iam_role.report_runner_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.reports.arn}/*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "report_runner" {
  name              = "/ecs/${var.name_prefix}-report-runner"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_ecs_task_definition" "report_runner" {
  family                   = "${var.name_prefix}-report-runner"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.report_runner_exec.arn
  task_role_arn            = aws_iam_role.report_runner_task.arn

  container_definitions = jsonencode([{
    name      = "report-runner"
    image     = var.report_runner_image
    essential = true
    environment = [
      { name = "REPORTS_BUCKET", value = aws_s3_bucket.reports.bucket },
      { name = "AWS_REGION", value = "us-east-1" },
    ]
    secrets = [{
      name      = "DATABASE_URL"
      valueFrom = module.rds.db_url_secret_arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.report_runner.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  tags = local.tags
}

# ── EventBridge — daily report at 06:00 UTC ───────────────────────────────────

resource "aws_iam_role" "report_scheduler" {
  name = "${var.name_prefix}-report-scheduler"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "report_scheduler_ecs" {
  name = "${var.name_prefix}-report-scheduler-ecs"
  role = aws_iam_role.report_scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = [aws_ecs_task_definition.report_runner.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.report_runner_exec.arn, aws_iam_role.report_runner_task.arn]
      },
    ]
  })
}

resource "aws_cloudwatch_event_rule" "report_daily" {
  name                = "${var.name_prefix}-report-daily"
  description         = "Generate orders report daily at 06:00 UTC"
  schedule_expression = "cron(0 6 * * ? *)"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "report_task" {
  rule     = aws_cloudwatch_event_rule.report_daily.name
  arn      = module.ecs_cluster.cluster_arn
  role_arn = aws_iam_role.report_scheduler.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.report_runner.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = module.network.private_subnet_ids
      security_groups  = [module.rds.db_client_sg_id]
      assign_public_ip = false
    }
  }
}
