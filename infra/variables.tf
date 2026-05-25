variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "DB subnet CIDR blocks"
  type        = list(string)
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "task_cpu" {
  description = "ECS task CPU"
  type        = number
}

variable "task_memory" {
  description = "ECS task memory"
  type        = number
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL for CloudWatch alerts"
  type        = string
  sensitive   = true
}