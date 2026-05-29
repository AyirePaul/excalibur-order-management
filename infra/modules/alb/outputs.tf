output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend.arn
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

# Returns the HTTPS listener ARN when a cert is configured, the HTTP listener ARN otherwise.
output "https_listener_arn" {
  value = local.has_cert ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}
