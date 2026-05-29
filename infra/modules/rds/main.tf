terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-orders"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.env}-orders-db-subnet" })
}

# DB-client security group — attach to any task that needs Postgres access.
resource "aws_security_group" "db_client" {
  name        = "${var.env}-orders-db-client"
  description = "Attach to ECS tasks that need Postgres access"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.env}-orders-db-client-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.env}-orders-rds"
  description = "Allow Postgres from db-client SG"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.env}-orders-rds-sg" })
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

resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${var.env}/orders/database-url"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql+psycopg://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${var.db_name}?sslmode=require"
}

resource "aws_db_instance" "main" {
  identifier             = "${var.env}-orders"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false
  deletion_protection    = false
  skip_final_snapshot    = true
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(var.tags, { Name = "${var.env}-orders-rds" })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.env}-orders-pg16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags
}
