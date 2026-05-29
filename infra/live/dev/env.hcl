locals {
  env        = "dev"
  account_id = "908875502705"

  # Cost-conscious sizing for dev
  rds_instance_class    = "db.t4g.micro"
  rds_multi_az          = false
  rds_deletion_protect  = false
  ecs_cpu               = 256   # 0.25 vCPU
  ecs_memory            = 512   # 0.5 GB
  ecs_desired_count     = 1
  enable_swagger        = true

  tags = {
    CostCenter = "engineering-sandbox"
    Owner      = "platform"
  }
}
