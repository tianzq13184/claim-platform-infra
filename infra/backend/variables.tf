variable "region" {
  type        = string
  description = "AWS region for backend resources."
  default     = "us-east-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the Terraform state bucket."
}

variable "lock_table_name" {
  type        = string
  description = "Name of the DynamoDB lock table."
}

