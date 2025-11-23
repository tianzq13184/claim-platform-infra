output "database_arns" {
  description = "Map of logical layer to Glue database ARN."
  value       = { for k, db in aws_glue_catalog_database.this : k => db.arn }
}

