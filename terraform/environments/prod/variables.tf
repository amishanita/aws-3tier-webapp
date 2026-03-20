variable "environment" {
  type    = string
  default = "prod"
}

variable "name_prefix" {
  type    = string
  default = "tier-ha-web"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN."
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 8
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "sns_alarm_email" {
  type    = string
  default = ""
}

variable "secrets_rotation_lambda_arn" {
  description = "Optional rotation lambda ARN for Secrets Manager."
  type        = string
  default     = ""
}

variable "rds_max_connections" {
  description = "Approximate max_connections for alarm percentage calculations."
  type        = number
  default     = 300
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS primary instance (higher cost)."
  type        = bool
  default     = false
}

variable "rds_create_read_replica" {
  description = "Create a MySQL read replica (higher cost)."
  type        = bool
  default     = false
}

variable "redis_automatic_failover_enabled" {
  description = "Enable Redis automatic failover (higher cost)."
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable ALB WAFv2 Web ACL."
  type        = bool
  default     = false
}

