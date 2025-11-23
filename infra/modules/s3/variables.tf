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

