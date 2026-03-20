resource "aws_cloudwatch_log_group" "app" {
  name              = "/${local.name}/app"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.sns_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_alarm_email
}

locals {
  alb_request_count_dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name}-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  threshold             = 70
  comparison_operator   = "GreaterThanThreshold"
  treat_missing_data    = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_error_rate_high" {
  alarm_name          = "${local.name}-alb-error-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 5
  period              = 60
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  metric_query {
    id = "e"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat         = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.this.arn_suffix
        TargetGroup  = aws_lb_target_group.app.arn_suffix
      }
    }
    return_data = false
  }

  metric_query {
    id = "r"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat         = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.this.arn_suffix
        TargetGroup  = aws_lb_target_group.app.arn_suffix
      }
    }
    return_data = false
  }

  metric_query {
    id          = "rate"
    expression  = "IF(r>0, (e / r) * 100, 0)"
    label       = "ErrorRatePercent"
    return_data = true
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${local.name}-rds-connections-high"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  threshold           = var.rds_max_connections * 0.8
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${local.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.this.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Requests"
        }
      },
      {
        type = "metric"
        x    = 6
        y    = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.this.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Target Response Time (ms)"
        }
      },
      {
        type = "metric"
        x    = 0
        y    = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.this.name]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ASG CPU Utilization (%)"
        }
      },
      {
        type = "metric"
        x    = 6
        y    = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            [var.metric_namespace, "CacheHitRate"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Cache Hit Rate (%)"
        }
      },
      {
        type = "metric"
        x    = 0
        y    = 12
        width  = 6
        height = 6
        properties = {
          metrics = [
            [var.metric_namespace, "ApiResponseTimeMsAvg"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "API Response Time Avg (ms)"
        }
      },
      {
        type = "metric"
        x    = 6
        y    = 12
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.primary.id]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Connections"
        }
      }
    ]
  })
}

