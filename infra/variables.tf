variable "name_prefix" {
  description = "Name prefix for all resources (single environment, no dev/qa/prod suffix)."
  type        = string
  default     = "orders"
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "orders"
}

variable "db_name" {
  description = "RDS database name."
  type        = string
  default     = "orders"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty to run HTTP-only."
  type        = string
  default     = ""
}

variable "backend_image" {
  description = "Full ECR image URI for the backend (repo:tag)."
  type        = string
  default     = "orders-backend:latest"
}

variable "frontend_image" {
  description = "Full ECR image URI for the frontend (repo:tag)."
  type        = string
  default     = "orders-frontend:latest"
}

variable "availability_zones" {
  description = "Two AZs to spread subnets across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "report_runner_image" {
  description = "Full ECR image URI for the report-runner (repo:tag)."
  type        = string
  default     = "orders-report-runner:latest"
}
