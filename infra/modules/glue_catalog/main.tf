resource "aws_glue_catalog_database" "this" {
  for_each = var.database_names

  name = each.value
  tags = merge(var.tags, { Name = each.value, Layer = each.key })
}

resource "aws_glue_data_catalog_encryption_settings" "this" {
  data_catalog_encryption_settings {
    encryption_at_rest {
      catalog_encryption_mode = "SSE-KMS"
    }
    connection_password_encryption {
      return_connection_password_encrypted = true
    }
  }
}

resource "aws_lakeformation_data_lake_settings" "this" {
  admins = [for admin in var.lakeformation_admins : admin]
}

