variable "env" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "deletion_window_in_days" {
  type    = number
  default = 30
}
