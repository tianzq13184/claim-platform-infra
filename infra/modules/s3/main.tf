locals {
  log_prefix = "access-logs/"
}

resource "aws_s3_bucket" "raw" {
  bucket = var.raw_bucket_name

  tags = merge(var.tags, {
    Name = var.raw_bucket_name
    Layer = "raw"
  })
}

resource "aws_s3_bucket" "lake" {
  bucket = var.lake_bucket_name

  tags = merge(var.tags, {
    Name = var.lake_bucket_name
    Layer = "lake"
  })
}

resource "aws_s3_bucket" "audit" {
  bucket = var.audit_bucket_name

  force_destroy = false

  tags = merge(var.tags, {
    Name = var.audit_bucket_name
    Layer = "audit"
  })
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.raw_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.lake_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.audit_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_logging" "raw" {
  bucket        = aws_s3_bucket.raw.id
  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "${local.log_prefix}raw/"
}

resource "aws_s3_bucket_logging" "lake" {
  bucket        = aws_s3_bucket.lake.id
  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "${local.log_prefix}lake/"
}

resource "aws_s3_bucket_logging" "audit" {
  bucket        = aws_s3_bucket.audit.id
  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "${local.log_prefix}audit/"
}

data "aws_iam_policy_document" "bucket_common" {
  statement {
    sid    = "AllowClaimRoles"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.raw.arn}",
      "${aws_s3_bucket.raw.arn}/*",
      "${aws_s3_bucket.lake.arn}",
      "${aws_s3_bucket.lake.arn}/*",
      "${aws_s3_bucket.audit.arn}",
      "${aws_s3_bucket.audit.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:aws:iam::${var.account_id}:role/role-claim-*",
        "arn:aws:iam::${var.account_id}:role/Admin*"
      ]
    }
  }

  statement {
    sid    = "RestrictToVpcEndpoints"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.raw.arn}",
      "${aws_s3_bucket.raw.arn}/*",
      "${aws_s3_bucket.lake.arn}",
      "${aws_s3_bucket.lake.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = var.allowed_vpc_endpoint_ids
    }
  }
}

resource "aws_s3_bucket_policy" "raw" {
  bucket = aws_s3_bucket.raw.id
  policy = data.aws_iam_policy_document.bucket_common.json
}

resource "aws_s3_bucket_policy" "lake" {
  bucket = aws_s3_bucket.lake.id
  policy = data.aws_iam_policy_document.bucket_common.json
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.bucket_common.json
}

