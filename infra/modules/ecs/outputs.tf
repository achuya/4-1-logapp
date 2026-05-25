output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.backend.name
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}