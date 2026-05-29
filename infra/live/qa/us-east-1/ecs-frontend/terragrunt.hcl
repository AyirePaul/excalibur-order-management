include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${get_repo_root()}/infra/live/_envcommon/ecs-frontend.hcl"
}

terraform {
  source = "${get_repo_root()}/infra/modules/ecs-service"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "ecr" {
  config_path = "../ecr"
  mock_outputs = { repository_urls = { frontend = "000000000000.dkr.ecr.us-east-1.amazonaws.com/orders-frontend-mock:latest" } }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  image_uri     = "${dependency.ecr.outputs.repository_urls["frontend"]}:latest"
  cpu           = local.env_vars.locals.ecs_cpu
  memory        = local.env_vars.locals.ecs_memory
  desired_count = local.env_vars.locals.ecs_desired_count
  environment_vars = [
    { name = "APP_ENV", value = local.env_vars.locals.env },
  ]
}
