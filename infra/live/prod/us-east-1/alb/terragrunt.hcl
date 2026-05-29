include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/alb"
}

dependency "network" {
  config_path = "../network"
  mock_outputs = { vpc_id = "vpc-mock", public_subnet_ids = ["subnet-mock"] }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  vpc_id            = local.vpc_id
  public_subnet_ids = dependency.network.outputs.public_subnet_ids
  # Prod should have a real cert. Uncomment and set once the ACM cert is issued.
  # acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"
}
