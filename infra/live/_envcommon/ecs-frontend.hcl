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
    alb_sg_id                 = "sg-mock"
    frontend_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/mock-fe/abc"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  vpc_id             = dependency.network.outputs.vpc_id
  cluster_arn        = dependency.cluster.outputs.cluster_arn
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  alb_sg_id          = dependency.alb.outputs.alb_sg_id
  target_group_arn   = dependency.alb.outputs.frontend_target_group_arn
  # Frontend has no DB — omit db_secret_arn and kms_key_arn so the module
  # skips those IAM statements and does not inject a DB_SECRET_ARN env var
  service_name   = "frontend"
  container_port = 80
}
