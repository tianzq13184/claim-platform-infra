output "sns_topic_arn" {
  value       = aws_sns_topic.drift.arn
  description = "SNS topic ARN used for alerts and drift reminders."
}

