locals {
  tags    = { Project = "orders", ManagedBy = "terraform" }
  alb_url = var.acm_certificate_arn != "" ? "https://${module.alb.alb_dns_name}" : "http://${module.alb.alb_dns_name}"
}

module "network" {
  source             = "./modules/network"
  env                = var.name_prefix
  availability_zones = var.availability_zones
  tags               = local.tags
}

module "ecr" {
  source     = "./modules/ecr"
  env        = var.name_prefix
  project    = "orders"
  repo_names = ["backend", "frontend"]
  tags       = local.tags
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"
  env    = var.name_prefix
  tags   = local.tags
}

module "alb" {
  source              = "./modules/alb"
  env                 = var.name_prefix
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  acm_certificate_arn = var.acm_certificate_arn
  tags                = local.tags
}

module "rds" {
  source             = "./modules/rds"
  env                = var.name_prefix
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  db_username        = var.db_username
  db_name            = var.db_name
  tags               = local.tags
}

module "backend" {
  source             = "./modules/ecs-service"
  env                = var.name_prefix
  service_name       = "backend"
  vpc_id             = module.network.vpc_id
  cluster_arn        = module.ecs_cluster.cluster_arn
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.backend_target_group_arn
  image_uri          = var.backend_image
  container_port     = 8000
  additional_sg_ids  = [module.rds.db_client_sg_id]
  secrets = [{
    name      = "DATABASE_URL"
    valueFrom = module.rds.db_url_secret_arn
  }]
  secret_arns = [module.rds.db_url_secret_arn]
  environment_vars = [
    { name = "APP_ENV", value = var.name_prefix },
    { name = "ENABLE_DOCS", value = "true" },
    { name = "CORS_ORIGINS", value = local.alb_url },
  ]
  tags = local.tags
}

module "frontend" {
  source             = "./modules/ecs-service"
  env                = var.name_prefix
  service_name       = "frontend"
  vpc_id             = module.network.vpc_id
  cluster_arn        = module.ecs_cluster.cluster_arn
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.frontend_target_group_arn
  image_uri          = var.frontend_image
  container_port     = 80
  tags               = local.tags
}
