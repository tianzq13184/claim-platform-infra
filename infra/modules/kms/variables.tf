variable "key_admin_arns" {
  description = "Principals allowed to administer the CMKs."
  type        = list(string)
}

variable "service_roles" {
  description = "Map of service role ARNs that require decrypt access."
  type        = map(string)
  default     = {}
}

variable "sqs_queue_arns" {
  description = "List of SQS queue ARNs that need to use this KMS key for encryption. Required when SQS queues use CMK."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

