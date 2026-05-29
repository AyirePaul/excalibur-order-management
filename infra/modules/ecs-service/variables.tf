variable "env" {
  type = string
}

variable "service_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "image_uri" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "secrets" {
  description = "Secrets injected as env vars at container launch. valueFrom must be a Secrets Manager ARN."
  type        = list(object({ name = string, valueFrom = string }))
  default     = []
}

variable "secret_arns" {
  description = "Base Secrets Manager ARNs for the execution role IAM Resource list."
  type        = list(string)
  default     = []
}

variable "additional_sg_ids" {
  description = "Additional security groups to attach to ECS task ENIs (e.g. the RDS db-client SG)."
  type        = list(string)
  default     = []
}

variable "environment_vars" {
  type    = list(object({ name = string, value = string }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
