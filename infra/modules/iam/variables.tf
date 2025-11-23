variable "raw_bucket_arn" {
  type        = string
  description = "ARN of the raw bucket."
}

variable "lake_bucket_arn" {
  type        = string
  description = "ARN of the lake bucket."
}

variable "kms_key_arns" {
  type        = map(string)
  description = "Map of layer name to KMS key ARN."
}

variable "glue_catalog_arns" {
  type = object({
    raw_db   = string
    silver_db = string
    gold_db   = string
  })
  description = "Glue database ARNs."
}

variable "ingestion_trusted_principals" {
  description = "Principals allowed to assume the ingestion role."
  type        = list(string)
}

variable "etl_trusted_principals" {
  description = "Principals allowed to assume the ETL role."
  type        = list(string)
}

variable "analyst_trusted_principals" {
  description = "Principals allowed to assume the analyst role."
  type        = list(string)
}

variable "redshift_cluster_identifier" {
  description = "Optional Redshift cluster identifier for ETL role to write data."
  type        = string
  default     = ""
}

variable "redshift_namespace_arn" {
  description = "Optional Redshift Serverless namespace ARN for ETL role to write data."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

