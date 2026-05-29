variable "env" {
  type = string
}

variable "github_repo" {
  description = "owner/repo"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
