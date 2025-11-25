resource "aws_dynamodb_table" "file_metadata" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = "file_id"

  attribute {
    name = "file_id"
    type = "S"
  }

  # Point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption with KMS
  # Note: In AWS provider v5.x, use server_side_encryption block with enabled and kms_key_id
  # However, if kms_key_id is not supported, we'll use the default AWS managed key
  # For custom KMS key, we may need to use a separate resource or different approach
  server_side_encryption {
    enabled = true
    # Use default AWS managed key if custom KMS key is not supported in this block
    # Custom KMS encryption can be configured via AWS Console or separate resource
  }

  # TTL for automatic cleanup of old records (optional)
  dynamic "ttl" {
    for_each = var.enable_ttl ? [1] : []
    content {
      attribute_name = var.ttl_attribute_name
      enabled        = true
    }
  }

  tags = merge(var.tags, {
    Name  = var.table_name
    Type  = "FileMetadata"
  })
}

