variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets."
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets."
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "glue_database_names" {
  description = "Map of database logical names."
  type        = map(string)
  default = {
    raw    = "claim_raw_db"
    silver = "claim_silver_db"
    gold   = "claim_gold_db"
  }
}

variable "key_admin_arns" {
  description = "List of IAM principals that can administer KMS keys and Lake Formation."
  type        = list(string)
  default     = []
}

variable "ingestion_trusted_principals" {
  type        = list(string)
  description = "Principals allowed to assume ingestion role."
  default     = []
}

variable "etl_trusted_principals" {
  type        = list(string)
  description = "Principals allowed to assume ETL role."
  default     = []
}

variable "analyst_trusted_principals" {
  type        = list(string)
  description = "Principals allowed to assume analyst role."
  default     = []
}

variable "redshift_cluster_identifier" {
  description = "Optional Redshift cluster identifier for ETL role to write data. Leave empty if using Redshift Serverless."
  type        = string
  default     = ""
}

variable "redshift_namespace_arn" {
  description = "Optional Redshift Serverless namespace ARN for ETL role to write data. Leave empty if using provisioned Redshift."
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "Extra tags for resources."
  type        = map(string)
  default     = {}
}

