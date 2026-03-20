data "aws_ssm_parameter" "al2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

locals {
  ecr_registry_host = split("/", aws_ecr_repository.this.repository_url)[0]
}

resource "aws_launch_template" "this" {
  name_prefix   = "${local.name}-lt-"
  instance_type = var.instance_type

  image_id = data.aws_ssm_parameter.al2_ami.value

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(
    templatefile("${path.module}/user_data.sh.tpl", {
      aws_region        = var.aws_region
      app_port          = local.app_port
      health_path       = var.docker_health_path
      ssm_image_param   = local.ssm_image_param
      ecr_registry      = local.ecr_registry_host
      log_group_name    = aws_cloudwatch_log_group.app.name
      db_secret_arn     = aws_secretsmanager_secret.app.arn
      redis_endpoint    = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:${var.redis_port}"
      metric_namespace  = var.metric_namespace
      cache_ttl_seconds = var.cache_ttl_seconds
    })
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, { Name = "${local.name}-app" })
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${local.name}-asg"
  vpc_zone_identifier       = aws_subnet.private[*].id
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 180

  target_group_arns = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.name_prefix
    propagate_at_launch = true
  }

  termination_policies = ["OldestInstance"]
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${local.name}-cpu-target"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.this.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value       = 60
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_autoscaling_policy" "response_time_target" {
  name                   = "${local.name}-response-time-target"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.this.name

  target_tracking_configuration {
    customized_metric_specification {
      metric_name = "ApiResponseTimeMsAvg"
      namespace   = var.metric_namespace
      statistic   = "Average"
      unit        = "Milliseconds"
    }

    target_value       = 600
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

