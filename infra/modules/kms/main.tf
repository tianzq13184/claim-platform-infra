locals {
  keys = {
    raw   = "kms-claim-raw"
    lake  = "kms-claim-lake"
    audit = "kms-claim-audit"
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "base" {
  statement {
    sid    = "EnableRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Note: SQS service permissions are NOT added here in the base policy
  # because they require EncryptionContext conditions with specific queue ARNs.
  # SQS permissions should be added in the environment configuration (e.g., dev/main.tf)
  # after SQS queues are created, using aws_kms_key_policy resource to merge
  # the base policy with queue-specific SQS permissions.

  # Only add admin statement if admins are provided
  dynamic "statement" {
    for_each = length(var.key_admin_arns) > 0 ? [1] : []
    content {
      sid    = "AllowAdmins"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.key_admin_arns
      }
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
    }
  }

  # Only add service role statement if roles are provided
  # Note: This uses role ARNs that may not exist yet, but AWS will validate them
  # when the policy is applied. For initial creation, we allow empty service_roles.
  dynamic "statement" {
    for_each = length(var.service_roles) > 0 ? [1] : []
    content {
      sid    = "AllowUseOfKey"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = values(var.service_roles)
      }
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  }
}

resource "aws_kms_key" "this" {
  for_each            = local.keys
  description         = "HIPAA-compliant key for ${each.key} data layer"
  deletion_window_in_days = 30
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.base.json

  tags = merge(var.tags, {
    Name = each.value
    Layer = each.key
  })
}

resource "aws_kms_alias" "this" {
  for_each      = local.keys
  name          = "alias/${each.value}"
  target_key_id = aws_kms_key.this[each.key].id
}

