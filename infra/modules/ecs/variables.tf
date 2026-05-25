variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "backend_target_group_arn" {
  type = string
}

variable "http_listener_arn" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "bastion_sg_id" {
  type = string
}