variable "raw_bucket_name" {
  type        = string
  description = "Name for the raw ingestion bucket."
}

variable "lake_bucket_name" {
  type        = string
  description = "Name for the curated lake bucket."
}

variable "audit_bucket_name" {
  type        = string
  description = "Name for the audit/log bucket."
}

variable "raw_kms_key_arn" {
  type        = string
  description = "KMS key ARN for the raw bucket."
}

variable "lake_kms_key_arn" {
  type        = string
  description = "KMS key ARN for the lake bucket."
}

variable "audit_kms_key_arn" {
  type        = string
  description = "KMS key ARN for the audit bucket."
}

variable "allowed_vpc_endpoint_ids" {
  description = "List of VPC endpoint IDs permitted to access the buckets."
  type        = list(string)
  default     = []
}

variable "account_id" {
  description = "AWS account ID used for bucket policy restrictions."
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

variable "force_destroy" {
  type        = bool
  description = "Allow deletion of non-empty buckets. Use with caution in production."
  default     = false
}

variable "raw_bucket_sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS queue to receive S3 event notifications from raw bucket"
  default     = null
}

variable "raw_bucket_sqs_queue_policy_id" {
  type        = string
  description = "ID of the SQS queue policy (for dependency management)"
  default     = null
}

