locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

inputs = {
  aws_region         = local.region_vars.locals.aws_region
  availability_zones = local.region_vars.locals.availability_zones
}
