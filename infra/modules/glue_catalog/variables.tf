variable "database_names" {
  description = "Map of logical layer to database name."
  type        = map(string)
}

variable "lakeformation_admins" {
  description = "List of admin ARNs for Lake Formation."
  type        = list(string)
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

