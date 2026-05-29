include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/s3-reports"
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs = { key_id = "mock", key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  kms_key_id = dependency.kms.outputs.key_arn
}
