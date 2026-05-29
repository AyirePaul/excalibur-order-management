dependency "network" {
  config_path = "../network"
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-a", "subnet-mock-b"]
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs = { key_id = "mock-key-id", key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  vpc_id             = dependency.network.outputs.vpc_id
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  kms_key_id         = dependency.kms.outputs.key_arn
}
