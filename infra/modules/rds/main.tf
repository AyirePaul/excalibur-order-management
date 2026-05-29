terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "orders-${var.env}"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "orders-db-subnet-${var.env}" })
}

# DB-client security group — attach to any task/instance that needs Postgres access.
# RDS allows ingress from this SG via the standalone rule below (breaks the circular
# dependency that would occur if ecs-service SG IDs were passed here directly).
resource "aws_security_group" "db_client" {
  name        = "orders-db-client-${var.env}"
  description = "Attach to ECS tasks (or other clients) that need Postgres access"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "orders-db-client-sg-${var.env}" })
}

resource "aws_security_group" "rds" {
  name        = "orders-rds-${var.env}"
  description = "Allow Postgres from db-client SG"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "orders-rds-sg-${var.env}" })
}

resource "aws_security_group_rule" "rds_ingress_from_db_client" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.db_client.id
  description              = "Allow Postgres from db-client SG"
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db_creds" {
  name                    = "orders/${var.env}/db-credentials"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = 5432
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
  })
}

# Separate secret that stores only the connection URL as a plain string.
# ECS tasks inject this directly as DATABASE_URL — no JSON parsing required.
resource "aws_secretsmanager_secret" "db_url" {
  name                    = "orders/${var.env}/database-url"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql+psycopg://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${var.db_name}?sslmode=require"
}

resource "aws_db_instance" "main" {
  identifier             = "orders-${var.env}"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_encrypted      = true
  kms_key_id             = var.kms_key_id
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = var.multi_az
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = !var.deletion_protection
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(var.tags, { Name = "orders-rds-${var.env}" })
}

resource "aws_db_parameter_group" "main" {
  name   = "orders-pg16-${var.env}"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags
}
