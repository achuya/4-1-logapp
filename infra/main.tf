provider "aws" {
  region = var.aws_region
}

module "network" {
  source               = "./modules/network"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

module "rds" {
  source        = "./modules/rds"
  db_subnet_ids = module.network.db_subnet_ids
  rds_sg_id     = module.security.rds_sg_id
  db_name       = var.db_name
  db_username   = var.db_username
  db_password   = var.db_password
}

module "ecr" {
  source = "./modules/ecr"
}

module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}

module "cloudfront" {
  source       = "./modules/cloudfront"
  alb_dns_name = module.alb.alb_dns_name
}

module "cloudwatch" {
  source            = "./modules/cloudwatch"
  ecs_cluster_name  = "logapp-cluster"
  ecs_service_name  = "logapp-backend-service"
  slack_webhook_url = var.slack_webhook_url
  aws_region        = var.aws_region
}

module "ecs" {
  source                   = "./modules/ecs"
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnet_ids
  ecs_sg_id                = module.security.ecs_sg_id
  bastion_sg_id            = module.security.bastion_sg_id
  backend_target_group_arn = module.alb.backend_target_group_arn
  http_listener_arn        = module.alb.http_listener_arn
  repository_url           = module.ecr.repository_url
  task_cpu                 = var.task_cpu
  task_memory              = var.task_memory
  database_url             = "mysql+pymysql://${var.db_username}:${var.db_password}@${module.rds.endpoint}:3306/${var.db_name}"
  aws_region               = var.aws_region
  log_group_name           = module.cloudwatch.log_group_name
}