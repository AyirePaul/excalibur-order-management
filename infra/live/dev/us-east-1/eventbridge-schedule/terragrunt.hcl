include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${get_repo_root()}/infra/live/_envcommon/eventbridge-schedule.hcl"
}

terraform {
  source = "${get_repo_root()}/infra/modules/eventbridge-schedule"
}

dependency "ecr" {
  config_path = "../ecr"
  mock_outputs = { repository_urls = { "report-runner" = "000000000000.dkr.ecr.us-east-1.amazonaws.com/mock:latest" } }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  image_uri = "${dependency.ecr.outputs.repository_urls["report-runner"]}:latest"
}
