variable "key_admin_arns" {
  description = "Principals allowed to administer the CMKs."
  type        = list(string)
}

variable "service_roles" {
  description = "Map of service role ARNs that require decrypt access."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

