variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty to run HTTP-only (dev/demo without a cert)."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
