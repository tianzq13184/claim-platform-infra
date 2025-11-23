variable "trail_name" {
  type        = string
  description = "Name of the organization trail."
}

variable "s3_bucket_name" {
  type        = string
  description = "Bucket receiving CloudTrail logs."
}

variable "cloudwatch_log_group_name" {
  type        = string
  description = "CloudWatch Log Group for CloudTrail streaming."
}

variable "sns_topic_name" {
  type        = string
  description = "SNS topic for drift detection and alerts."
}

variable "tags" {
  type        = map(string)
  description = "Common resource tags."
  default     = {}
}

variable "prevent_destroy" {
  type        = bool
  description = "Prevent accidental deletion of CloudTrail. Set to true for production."
  default     = false
}

