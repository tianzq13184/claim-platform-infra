resource "aws_glue_catalog_database" "this" {
  for_each = var.database_names

  name = each.value
  tags = merge(var.tags, { Name = each.value, Layer = each.key })
}

resource "aws_glue_data_catalog_encryption_settings" "this" {
  data_catalog_encryption_settings {
    encryption_at_rest {
      catalog_encryption_mode = "SSE-KMS"
      # AWS will use default KMS key (alias/aws/glue) if not specified
    }
    connection_password_encryption {
      return_connection_password_encrypted = true
      # AWS will use default KMS key (alias/aws/glue) if not specified
    }
  }

  # Ignore changes to KMS key IDs as AWS sets defaults automatically
  lifecycle {
    ignore_changes = [
      data_catalog_encryption_settings[0].encryption_at_rest[0].sse_aws_kms_key_id,
      data_catalog_encryption_settings[0].connection_password_encryption[0].aws_kms_key_id
    ]
  }
}

resource "aws_lakeformation_data_lake_settings" "this" {
  admins = [for admin in var.lakeformation_admins : admin]
}

