terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

module "three_tier" {
  source = "../../modules/three_tier"

  environment         = var.environment
  aws_region          = var.aws_region
  name_prefix         = var.name_prefix
  acm_certificate_arn = var.acm_certificate_arn

  instance_type        = var.instance_type
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity

  sns_alarm_email = var.sns_alarm_email
  secrets_rotation_lambda_arn = var.secrets_rotation_lambda_arn

  rds_max_connections = var.rds_max_connections
  rds_multi_az = var.rds_multi_az
  rds_create_read_replica = var.rds_create_read_replica
  redis_automatic_failover_enabled = var.redis_automatic_failover_enabled
  enable_waf = var.enable_waf
}

