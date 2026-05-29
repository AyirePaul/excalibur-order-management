variable "env" {
  type = string
}

variable "project" {
  type    = string
  default = "orders"
}

variable "repo_names" {
  type    = list(string)
  default = ["backend", "frontend", "report-runner"]
}

variable "kms_key_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
