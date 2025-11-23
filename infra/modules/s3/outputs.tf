output "raw_bucket_arn" {
  value       = aws_s3_bucket.raw.arn
  description = "ARN of raw bucket."
}

output "lake_bucket_arn" {
  value       = aws_s3_bucket.lake.arn
  description = "ARN of lake bucket."
}

output "audit_bucket_arn" {
  value       = aws_s3_bucket.audit.arn
  description = "ARN of audit bucket."
}

output "raw_bucket_name" {
  value       = aws_s3_bucket.raw.bucket
  description = "Name of raw bucket."
}

output "lake_bucket_name" {
  value       = aws_s3_bucket.lake.bucket
  description = "Name of lake bucket."
}

output "audit_bucket_name" {
  value       = aws_s3_bucket.audit.bucket
  description = "Name of audit bucket."
}

