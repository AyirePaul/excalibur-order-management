include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${get_repo_root()}/infra/live/_envcommon/rds.hcl"
}

terraform {
  source = "${get_repo_root()}/infra/modules/rds"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  instance_class      = local.env_vars.locals.rds_instance_class
  multi_az            = local.env_vars.locals.rds_multi_az
  deletion_protection = local.env_vars.locals.rds_deletion_protect
}
