dependency "cluster" {
  config_path = "../ecs-cluster"
  mock_outputs = { cluster_arn = "arn:aws:ecs:us-east-1:000000000000:cluster/mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "network" {
  config_path = "../network"
  mock_outputs = { private_subnet_ids = ["subnet-mock-a", "subnet-mock-b"] }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs = { key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    db_url_secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret/orders/mock/database-url"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "s3_reports" {
  config_path = "../s3-reports"
  mock_outputs = { bucket_name = "mock-reports-bucket" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

# Reuse the backend ECS security group so the runner can reach RDS
dependency "ecs_backend" {
  config_path = "../ecs-backend"
  mock_outputs = { ecs_sg_id = "sg-mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  cluster_arn        = dependency.cluster.outputs.cluster_arn
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  security_group_ids = [dependency.ecs_backend.outputs.ecs_sg_id]
  db_url_secret_arn  = dependency.rds.outputs.db_url_secret_arn
  kms_key_arn        = dependency.kms.outputs.key_arn
  reports_bucket     = dependency.s3_reports.outputs.bucket_name
}
