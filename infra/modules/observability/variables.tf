variable "env" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "alarm_actions" {
  type    = list(string)
  default = []
}

variable "dashboard_body" {
  description = "CloudWatch dashboard JSON body. Read via file() in the Terragrunt unit so the path resolves correctly outside .terragrunt-cache."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
