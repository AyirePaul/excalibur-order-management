locals {
  has_cert = var.acm_certificate_arn != ""
  # Route API traffic on whichever listener is active
  active_listener_arn = local.has_cert ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

resource "aws_security_group" "alb" {
  name        = "orders-alb-${var.env}"
  description = "ALB inbound HTTP/HTTPS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = local.has_cert ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "orders-alb-sg-${var.env}" })
}

resource "aws_lb" "main" {
  name               = "orders-alb-${var.env}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "backend" {
  name        = "orders-backend-${var.env}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
  tags = var.tags
}

resource "aws_lb_target_group" "frontend" {
  name        = "orders-frontend-${var.env}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path              = "/healthz"
    healthy_threshold = 2
    interval          = 30
  }
  tags = var.tags
}

# HTTP listener: redirects to HTTPS when a cert is provided, forwards directly otherwise.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.has_cert ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = local.has_cert ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = local.has_cert ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.frontend.arn
        }
      }
    }
  }
}

# HTTPS listener — only created when acm_certificate_arn is set.
resource "aws_lb_listener" "https" {
  count             = local.has_cert ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# API + health routing rule.
resource "aws_lb_listener_rule" "api" {
  listener_arn = local.active_listener_arn
  priority     = 10

  condition {
    path_pattern { values = ["/orders*", "/api/*", "/healthz", "/readyz", "/docs*"] }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Docs routing rule (split out to stay within the 5-value path condition limit).
resource "aws_lb_listener_rule" "docs" {
  listener_arn = local.active_listener_arn
  priority     = 11

  condition {
    path_pattern { values = ["/redoc*", "/openapi.json"] }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
