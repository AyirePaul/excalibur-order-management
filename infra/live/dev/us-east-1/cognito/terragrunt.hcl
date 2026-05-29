include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/cognito"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  callback_urls = ["http://localhost:5173/auth/callback", "https://dev.orders.example.com/auth/callback"]
  logout_urls   = ["http://localhost:5173", "https://dev.orders.example.com"]
}
