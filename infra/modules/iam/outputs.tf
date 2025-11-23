output "role_arns" {
  description = "Map of IAM role ARNs."
  value       = { for k, role in aws_iam_role.this : k => role.arn }
}

