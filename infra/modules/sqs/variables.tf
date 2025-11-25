variable "queue_name" {
  description = "Name of the main SQS queue"
  type        = string
}

variable "dlq_name" {
  description = "Name of the dead letter queue"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID or ARN for encrypting queue messages"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket that will send events to this queue"
  type        = string
}

variable "account_id" {
  description = "AWS account ID for SourceAccount condition in queue policy"
  type        = string
}

variable "message_retention_seconds" {
  description = "The number of seconds to retain messages in the main queue"
  type        = number
  default     = 345600 # 4 days
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue"
  type        = number
  default     = 30
}

variable "max_receive_count" {
  description = "Maximum number of times a message can be received before being sent to DLQ"
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "The number of seconds to retain messages in the DLQ"
  type        = number
  default     = 1209600 # 14 days
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

