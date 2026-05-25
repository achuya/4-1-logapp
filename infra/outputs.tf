output "cloudfront_url" {
  value = "https://${module.cloudfront.cloudfront_domain_name}"
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecr_url" {
  value = module.ecr.repository_url
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "bastion_instance_id" {
  value = module.ecs.bastion_instance_id
}

output "cloudwatch_log_group" {
  value = module.cloudwatch.log_group_name
}