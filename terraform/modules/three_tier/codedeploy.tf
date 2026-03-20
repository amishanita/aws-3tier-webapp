resource "aws_codedeploy_app" "this" {
  name             = "${local.name}-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name              = aws_codedeploy_app.this.name
  deployment_group_name = "${local.name}-dg"
  service_role_arn     = aws_iam_role.codedeploy_service_role.arn
  autoscaling_groups   = [aws_autoscaling_group.this.name]

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  # CodeDeploy will call lifecycle hooks on the instances.
  # AppSpec is provided by the GitHub Actions pipeline as a revision artifact.

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  depends_on = [aws_autoscaling_group.this]
}

