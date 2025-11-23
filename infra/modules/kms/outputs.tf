output "key_arns" {
  description = "Map of data layer to KMS key ARNs."
  value       = { for k, res in aws_kms_key.this : k => res.arn }
}

output "key_aliases" {
  description = "Map of data layer to KMS alias names."
  value       = { for k, res in aws_kms_alias.this : k => res.name }
}

