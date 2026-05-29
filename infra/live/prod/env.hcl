locals {
  env        = "prod"
  account_id = "908875502705"

  rds_instance_class    = "db.t4g.medium"
  rds_multi_az          = true
  rds_deletion_protect  = true
  ecs_cpu               = 1024
  ecs_memory            = 2048
  ecs_desired_count     = 3
  enable_swagger        = false

  tags = {
    CostCenter = "production"
    Owner      = "platform"
    Compliance = "required"
  }
}
