output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs"
  value       = module.network.vpc_endpoint_ids
}

output "s3_bucket_names" {
  description = "S3 bucket names"
  value = {
    raw    = module.s3.raw_bucket_name
    lake   = module.s3.lake_bucket_name
    audit  = module.s3.audit_bucket_name
  }
}

output "s3_bucket_arns" {
  description = "S3 bucket ARNs"
  value = {
    raw   = module.s3.raw_bucket_arn
    lake  = module.s3.lake_bucket_arn
    audit = module.s3.audit_bucket_arn
  }
}

output "kms_key_arns" {
  description = "KMS key ARNs"
  value       = module.kms.key_arns
}

output "kms_key_aliases" {
  description = "KMS key aliases"
  value       = module.kms.key_aliases
}

output "iam_role_arns" {
  description = "IAM role ARNs"
  value       = module.iam.role_arns
}

output "glue_database_arns" {
  description = "Glue database ARNs"
  value       = module.glue_catalog.database_arns
}

output "tags" {
  description = "Common tags applied to resources"
  value       = local.tags
}

