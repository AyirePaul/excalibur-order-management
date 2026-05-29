variable "env" {
  type = string
}

variable "project" {
  type    = string
  default = "orders"
}

variable "repo_names" {
  type    = list(string)
  default = ["backend", "frontend"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
