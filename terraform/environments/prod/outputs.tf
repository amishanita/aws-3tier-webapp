output "alb_dns_name" {
  value = module.three_tier.alb_dns_name
}

output "ecr_repository_url" {
  value = module.three_tier.ecr_repository_url
}

output "codedeploy_app_name" {
  value = module.three_tier.codedeploy_app_name
}

output "codedeploy_deployment_group_name" {
  value = module.three_tier.codedeploy_deployment_group_name
}

output "codedeploy_artifacts_bucket" {
  value = module.three_tier.codedeploy_artifacts_bucket
}

output "ssm_image_uri_parameter_name" {
  value = module.three_tier.ssm_image_uri_parameter_name
}

