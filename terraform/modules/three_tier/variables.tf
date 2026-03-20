variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
}

variable "name_prefix" {
  description = "Global project name prefix."
  type        = string
  default     = "tier-ha-web"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN to use for ALB HTTPS listener."
  type        = string
}

variable "vpc_cidr" {
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "db_subnet_cidrs" {
  type        = list(string)
  default     = ["10.10.20.0/24", "10.10.21.0/24"]
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach ALB on 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "EC2 instance type for the app tier."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "app_container_port" {
  type    = number
  default = 5000
}

variable "docker_health_path" {
  type    = string
  default = "/health"
}

variable "initial_image_tag" {
  description = "Initial image tag for SSM; pipeline should push at least this tag (e.g., 'latest')."
  type        = string
  default     = "latest"
}

variable "rds_engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0.36"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_backup_retention_days" {
  type    = number
  default = 7
}

variable "rds_db_name" {
  type    = string
  default = "appdb"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "cache_ttl_seconds" {
  description = "Default cache TTL used by the app (seconds)."
  type        = number
  default     = 120
}

variable "metric_namespace" {
  description = "CloudWatch metric namespace emitted by the app."
  type        = string
  default     = "TierHaWeb"
}

variable "sns_alarm_email" {
  description = "Optional email to subscribe to SNS alarms."
  type        = string
  default     = ""
}

variable "rds_max_connections" {
  description = "Approximate MySQL max_connections used to compute connection utilization alarms."
  type        = number
  default     = 300
}

variable "secrets_rotation_lambda_arn" {
  description = "Optional ARN for Secrets Manager rotation lambda for MySQL."
  type        = string
  default     = ""
}

variable "rds_multi_az" {
  description = "Whether to enable Multi-AZ for the primary RDS instance."
  type        = bool
  default     = true
}

variable "rds_create_read_replica" {
  description = "Whether to create a MySQL read replica."
  type        = bool
  default     = true
}

variable "redis_automatic_failover_enabled" {
  description = "Whether Redis automatic failover is enabled."
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Whether to create and attach an ALB WAFv2 Web ACL."
  type        = bool
  default     = true
}

