include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/cognito"
}

inputs = {
  callback_urls = ["https://qa.orders.example.com/auth/callback"]
  logout_urls   = ["https://qa.orders.example.com"]
}
