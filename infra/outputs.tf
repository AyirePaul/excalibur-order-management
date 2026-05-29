output "alb_dns_name" {
  description = "Raw ALB DNS name (no scheme)."
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Full ALB URL with the correct scheme — https:// when a cert is configured, http:// otherwise."
  value       = local.alb_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name (passed to Ansible deploy playbook)."
  value       = module.ecs_cluster.cluster_name
}

output "private_subnet_ids" {
  description = "Private subnet IDs (passed to Ansible for migration task)."
  value       = module.network.private_subnet_ids
}

output "ecs_backend_sg_id" {
  description = "ECS backend task security group ID (passed to Ansible for migration task)."
  value       = module.backend.ecs_sg_id
}

output "backend_task_def_arn" {
  description = "Backend ECS task definition ARN (passed to Ansible for the migration RunTask)."
  value       = module.backend.task_def_arn
}

output "ecr_backend_url" {
  description = "ECR repository URL for the backend image."
  value       = module.ecr.repository_urls["backend"]
}

output "ecr_frontend_url" {
  description = "ECR repository URL for the frontend image."
  value       = module.ecr.repository_urls["frontend"]
}

output "ecr_report_runner_url" {
  description = "ECR repository URL for the report-runner image."
  value       = module.ecr.repository_urls["report-runner"]
}

output "reports_bucket" {
  description = "S3 bucket name for generated report PDFs."
  value       = aws_s3_bucket.reports.bucket
}

output "report_runner_task_def_arn" {
  description = "ARN of the report-runner ECS task definition (for manual RunTask calls)."
  value       = aws_ecs_task_definition.report_runner.arn
}
