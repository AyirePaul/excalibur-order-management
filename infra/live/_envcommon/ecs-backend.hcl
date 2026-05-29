dependency "network" {
  config_path = "../network"
  mock_outputs = { vpc_id = "vpc-mock", private_subnet_ids = ["subnet-mock-a"] }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "cluster" {
  config_path = "../ecs-cluster"
  mock_outputs = { cluster_arn = "arn:aws:ecs:us-east-1:000000000000:cluster/mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "alb" {
  config_path = "../alb"
  mock_outputs = {
    alb_sg_id                = "sg-mock"
    backend_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/mock/abc"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    secret_arn        = "arn:aws:secretsmanager:us-east-1:000000000000:secret/orders/mock/db-credentials"
    db_url_secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret/orders/mock/database-url"
    db_client_sg_id   = "sg-mock-db-client"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs = { key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

# P1.10: Cognito wiring — provides COGNITO_* env vars injected in each env's
# ecs-backend/terragrunt.hcl via dependency.cognito.outputs.*
dependency "cognito" {
  config_path = "../cognito"
  mock_outputs = {
    user_pool_id  = "us-east-1_mockPoolId"
    app_client_id = "mock-app-client-id"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  vpc_id             = dependency.network.outputs.vpc_id
  cluster_arn        = dependency.cluster.outputs.cluster_arn
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  alb_sg_id          = dependency.alb.outputs.alb_sg_id
  target_group_arn   = dependency.alb.outputs.backend_target_group_arn

  # P1.7: Generic secret list — execution role fetches these at container launch.
  secrets = [
    { name = "DATABASE_URL", valueFrom = dependency.rds.outputs.db_url_secret_arn },
  ]
  # Execution role IAM: needs GetSecretValue on all secret ARNs + Decrypt on KMS keys.
  secret_arns  = [dependency.rds.outputs.secret_arn, dependency.rds.outputs.db_url_secret_arn]
  kms_key_arns = [dependency.kms.outputs.key_arn]

  # P1.8: Attach the RDS db-client SG so ECS tasks can reach Postgres.
  additional_sg_ids = [dependency.rds.outputs.db_client_sg_id]
}
