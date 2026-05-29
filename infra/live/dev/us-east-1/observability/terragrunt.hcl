include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/observability"
}

dependency "alb" {
  config_path = "../alb"
  mock_outputs = { alb_arn = "arn:aws:elasticloadbalancing:us-east-1:000000000000:loadbalancer/app/mock/abc" }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "apply", "run"]
}

inputs = {
  alb_arn_suffix = split("loadbalancer/", dependency.alb.outputs.alb_arn)[1]
  alarm_actions  = []
  # P1.9: Read dashboard JSON here so the path resolves in the repo root,
  # not inside .terragrunt-cache/ where relative paths would break.
  dashboard_body = file("${get_repo_root()}/observability/dashboards/orders-overview.json")
}
