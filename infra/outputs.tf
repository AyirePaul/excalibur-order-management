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

output "ecr_backend_url" {
  description = "ECR repository URL for the backend image."
  value       = module.ecr.repository_urls["backend"]
}

output "ecr_frontend_url" {
  description = "ECR repository URL for the frontend image."
  value       = module.ecr.repository_urls["frontend"]
}
