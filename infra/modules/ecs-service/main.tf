data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "task_exec" {
  name = "orders-${var.service_name}-exec-${var.env}"
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
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Execution role: reads secrets from Secrets Manager at container launch.
# Guarded so services with no secrets (e.g. frontend) still validate.
resource "aws_iam_role_policy" "exec_secrets" {
  count = length(var.secret_arns) > 0 || length(var.kms_key_arns) > 0 ? 1 : 0
  name  = "exec-secrets-policy"
  role  = aws_iam_role.task_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(var.secret_arns) > 0 ? [{
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.secret_arns
      }] : [],
      length(var.kms_key_arns) > 0 ? [{
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.kms_key_arns
      }] : []
    )
  })
}

resource "aws_iam_role" "task" {
  name = "orders-${var.service_name}-task-${var.env}"
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

# Task role: runtime permissions the app uses via SDK (S3, X-Ray).
# Secrets access belongs to the execution role above, not here.
resource "aws_iam_role_policy" "task_runtime" {
  name = "task-runtime-policy"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      var.reports_bucket != "" ? [{
        Sid      = "S3Reports"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.reports_bucket}", "arn:aws:s3:::${var.reports_bucket}/*"]
      }] : [],
      [{
        Sid      = "XRay"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = ["*"]
      }]
    )
  })
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/orders-${var.service_name}-${var.env}"
  retention_in_days = 30
  tags              = var.tags
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "ecs" {
  name        = "orders-ecs-${var.service_name}-${var.env}"
  description = "ECS tasks for ${var.service_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  tags = merge(var.tags, { Name = "orders-ecs-${var.service_name}-sg-${var.env}" })
}

# ── Task Definition ───────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "main" {
  family                   = "orders-${var.service_name}-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.image_uri
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = var.environment_vars
      secrets     = var.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    # ADOT collector sidecar
    {
      name      = "adot-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = false
      command   = ["--config=/etc/ecs/ecs-default-config.yaml"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "adot"
        }
      }
    }
  ])

  tags = var.tags
}

# ── ECS Service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "main" {
  name            = "orders-${var.service_name}-${var.env}"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = concat([aws_security_group.ecs.id], var.additional_sg_ids)
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}

# ── Autoscaling ───────────────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "main" {
  max_capacity       = 4
  min_capacity       = var.desired_count
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "orders-${var.service_name}-cpu-${var.env}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
