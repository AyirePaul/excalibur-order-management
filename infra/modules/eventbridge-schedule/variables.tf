variable "env" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "image_uri" {
  description = "report-runner ECR image URI"
  type        = string
}

variable "db_url_secret_arn" {
  description = "Secrets Manager ARN for DATABASE_URL plain-string secret"
  type        = string
}

variable "kms_key_arn" {
  type = string
}

variable "reports_bucket" {
  description = "S3 bucket name for PDF output"
  type        = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "tags" {
  type    = map(string)
  default = {}
}
