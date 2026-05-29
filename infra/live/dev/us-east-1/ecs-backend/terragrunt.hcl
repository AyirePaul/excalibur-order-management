include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${get_repo_root()}/infra/live/_envcommon/ecs-backend.hcl"
}

terraform {
  source = "${get_repo_root()}/infra/modules/ecs-service"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "ecr" {
  config_path = "../ecr"
  mock_outputs = { repository_urls = { backend = "000000000000.dkr.ecr.us-east-1.amazonaws.com/orders-backend-dev:latest" } }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "s3_reports" {
  config_path = "../s3-reports"
  mock_outputs = { bucket_name = "mock-reports-bucket" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  service_name   = "backend"
  image_uri      = "${dependency.ecr.outputs.repository_urls["backend"]}:latest"
  container_port = 8000
  cpu            = local.env_vars.locals.ecs_cpu
  memory         = local.env_vars.locals.ecs_memory
  desired_count  = local.env_vars.locals.ecs_desired_count
  reports_bucket = dependency.s3_reports.outputs.bucket_name
  environment_vars = [
    { name = "APP_ENV",              value = "dev" },
    { name = "ENABLE_DOCS",          value = "true" },
    { name = "COGNITO_USER_POOL_ID", value = dependency.cognito.outputs.user_pool_id },
    { name = "COGNITO_APP_CLIENT_ID", value = dependency.cognito.outputs.app_client_id },
    { name = "COGNITO_REGION",       value = "us-east-1" },
  ]
}
