output "vpc_id" {
  value = aws_vpc.this.id
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "app_asg_name" {
  value = aws_autoscaling_group.this.name
}

output "rds_endpoint" {
  value = aws_db_instance.primary.address
}

output "redis_endpoint_address" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "ssm_image_uri_parameter_name" {
  value = aws_ssm_parameter.image_uri.name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.this.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "codedeploy_artifacts_bucket" {
  value = aws_s3_bucket.codedeploy_artifacts.bucket
}

output "alb_https_listener_port" {
  value = 443
}

