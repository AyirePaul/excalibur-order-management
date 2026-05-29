output "endpoint" {
  value = aws_db_instance.main.endpoint
}

output "address" {
  value = aws_db_instance.main.address
}

output "db_url_secret_arn" {
  value = aws_secretsmanager_secret.db_url.arn
}

output "db_sg_id" {
  value = aws_security_group.rds.id
}

output "db_client_sg_id" {
  description = "Attach this SG to any task that needs Postgres access."
  value       = aws_security_group.db_client.id
}
