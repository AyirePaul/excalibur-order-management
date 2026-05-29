variable "env" {
  type = string
}

variable "domain_suffix" {
  type    = string
  default = "auth"
}

variable "callback_urls" {
  type = list(string)
}

variable "logout_urls" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
