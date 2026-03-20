data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = local.alb_log_bucket
  force_destroy = true

  tags = merge(local.tags, { Name = local.alb_log_bucket })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSALBLogs"
        Effect    = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.alb_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "codedeploy_artifacts" {
  bucket        = local.codedeploy_bucket
  force_destroy = true

  tags = merge(local.tags, { Name = local.codedeploy_bucket })
}

resource "aws_s3_bucket_public_access_block" "codedeploy_artifacts" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

