variable "table_name" {
  description = "Name of the DynamoDB table for file metadata"
  type        = string
}

variable "billing_mode" {
  description = "Billing mode for DynamoDB table (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting the table"
  type        = string
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for the table"
  type        = bool
  default     = true
}

variable "enable_ttl" {
  description = "Enable TTL (Time To Live) for automatic cleanup"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "Attribute name to use for TTL (required if enable_ttl is true)"
  type        = string
  default     = "ttl"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

