data "aws_iam_policy_document" "app_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_instance_role" {
  name               = "${local.name}-app-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "app_ecr_readonly" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "app_inline" {
  name = "${local.name}-app-inline"
  role = aws_iam_role.app_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.app.arn]
      },
      {
        Sid    = "SSMReadForImageUpdates"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [aws_ssm_parameter.image_uri.arn]
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
      },
      {
        Sid    = "CloudWatchLogsForDocker"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app-instance-profile"
  role = aws_iam_role.app_instance_role.name
}

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy_service_role" {
  name               = "${local.name}-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_attach" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRole"
}

