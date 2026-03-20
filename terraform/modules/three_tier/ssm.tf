resource "aws_ssm_parameter" "image_uri" {
  name  = local.ssm_image_param
  type  = "String"
  value = "${aws_ecr_repository.this.repository_url}:${var.initial_image_tag}"

  overwrite = true
  tags       = local.tags
}

