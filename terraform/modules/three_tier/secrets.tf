resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "random_password" "redis_password" {
  length  = 24
  special = false
}

resource "random_string" "db_username" {
  length  = 12
  special = false
  upper   = false
}

resource "aws_secretsmanager_secret" "app" {
  name = "${local.name}/app-creds"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    db_username     = random_string.db_username.result
    db_password     = random_password.db_password.result
    db_port         = 3306
    db_name         = var.rds_db_name
    db_host         = aws_db_instance.primary.address
    redis_password  = random_password.redis_password.result
  })
}

resource "aws_secretsmanager_secret_rotation" "app" {
  count = var.secrets_rotation_lambda_arn != "" ? 1 : 0

  secret_id           = aws_secretsmanager_secret.app.id
  rotation_lambda_arn = var.secrets_rotation_lambda_arn

  rotation_rules {
    automatically_after_days = 30
  }
}

