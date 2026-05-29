locals {
  env        = "qa"
  account_id = "908875502705"

  rds_instance_class    = "db.t4g.small"
  rds_multi_az          = true
  rds_deletion_protect  = false
  ecs_cpu               = 512
  ecs_memory            = 1024
  ecs_desired_count     = 2
  enable_swagger        = true

  tags = {
    CostCenter = "engineering-qa"
    Owner      = "platform"
  }
}
