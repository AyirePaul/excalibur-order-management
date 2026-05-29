# Root Terragrunt configuration.
# Included by every child terragrunt.hcl via `include "root" { path = find_in_parent_folders("root.hcl") }`.
# Owns: AWS provider generation, S3+DynamoDB remote state, common locals/tags.

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  env         = local.env_vars.locals.env
  aws_region  = local.region_vars.locals.aws_region
  account_id  = local.env_vars.locals.account_id

  common_tags = merge(
    local.env_vars.locals.tags,
    {
      ManagedBy   = "terragrunt"
      Environment = local.env
      Region      = local.aws_region
      Project     = "order-management"
    }
  )
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "order-management-tfstate-${local.account_id}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "order-management-tfstate-locks"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"
      allowed_account_ids = ["${local.account_id}"]

      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }

    terraform {
      required_version = ">= 1.6"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.47"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.6"
        }
      }
    }
  EOF
}

inputs = {
  env        = local.env
  aws_region = local.aws_region
  tags       = local.common_tags
}
