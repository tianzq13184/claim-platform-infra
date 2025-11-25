output "key_arns" {
  description = "Map of data layer to KMS key ARNs."
  value       = { for k, res in aws_kms_key.this : k => res.arn }
}

output "key_aliases" {
  description = "Map of data layer to KMS alias names."
  value       = { for k, res in aws_kms_alias.this : k => res.name }
}

output "key_policy_json" {
  description = "The JSON policy document for the KMS keys (for merging with additional policies)"
  value       = data.aws_iam_policy_document.base.json
}

