resource "aws_cloudwatch_log_group" "trail" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 90
  tags              = merge(var.tags, { Name = var.cloudwatch_log_group_name })
}

resource "aws_cloudwatch_log_resource_policy" "trail" {
  policy_name = "${var.trail_name}-logs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AWSCloudTrailCreateLogStream"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

resource "aws_sns_topic" "drift" {
  name = var.sns_topic_name
  tags = merge(var.tags, { Name = var.sns_topic_name })
}

resource "aws_cloudtrail" "this" {
  name                          = var.trail_name
  s3_bucket_name                = var.s3_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_logging.arn
  # Note: sns_topic_arn is read-only in AWS provider v5.x
  # SNS notifications are handled via CloudWatch Events and Alarms

  # Note: prevent_destroy cannot use variables in lifecycle blocks
  # For production, manually add: lifecycle { prevent_destroy = true }
  # For test/dev, leave it out to allow cleanup
}

resource "aws_iam_role" "cloudtrail_logging" {
  name = "${var.trail_name}-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "cloudtrail.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.trail_name}-cloudwatch" })
}

resource "aws_iam_role_policy" "cloudtrail_logging" {
  name = "${var.trail_name}-cloudwatch"
  role = aws_iam_role.cloudtrail_logging.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "trail_delivery" {
  alarm_name          = "${var.trail_name}-DeliveryErrors"
  alarm_description   = "Alert if CloudTrail fails to deliver logs."
  namespace           = "AWS/CloudTrail"
  metric_name         = "DeliveryErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.drift.arn]
  ok_actions          = [aws_sns_topic.drift.arn]
  dimensions = {
    TrailName = aws_cloudtrail.this.name
  }
}

resource "aws_cloudwatch_event_rule" "terraform_drift" {
  name                = "${var.trail_name}-terraform-drift-weekly"
  description         = "Weekly reminder to run Terraform drift detection."
  schedule_expression = "cron(0 6 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "terraform_drift" {
  rule      = aws_cloudwatch_event_rule.terraform_drift.name
  target_id = "sns"
  arn       = aws_sns_topic.drift.arn
}

