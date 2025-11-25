locals {
  log_prefix = "access-logs/"
}

resource "aws_s3_bucket" "raw" {
  bucket = var.raw_bucket_name

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.raw_bucket_name
    Layer = "raw"
  })
}

resource "aws_s3_bucket" "lake" {
  bucket = var.lake_bucket_name

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.lake_bucket_name
    Layer = "lake"
  })
}

resource "aws_s3_bucket" "audit" {
  bucket = var.audit_bucket_name

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.audit_bucket_name
    Layer = "audit"
  })
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
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

# Create separate policy documents for each bucket
# Each bucket policy can only reference its own ARN

data "aws_iam_policy_document" "raw" {
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
      "${aws_s3_bucket.raw.arn}/*"
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
      "${aws_s3_bucket.raw.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = var.allowed_vpc_endpoint_ids
    }
  }
}

data "aws_iam_policy_document" "lake" {
  statement {
    sid    = "AllowClaimRoles"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.lake.arn}",
      "${aws_s3_bucket.lake.arn}/*"
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

data "aws_iam_policy_document" "audit" {
  # Allow CloudTrail to write logs
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.audit.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AllowClaimRoles"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }

    actions = ["s3:*"]
    resources = [
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
}

resource "aws_s3_bucket_policy" "raw" {
  bucket = aws_s3_bucket.raw.id
  policy = data.aws_iam_policy_document.raw.json
}

resource "aws_s3_bucket_policy" "lake" {
  bucket = aws_s3_bucket.lake.id
  policy = data.aws_iam_policy_document.lake.json
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.audit.json
}

# S3 Event Notification for Raw Bucket -> SQS
# Create notification only if queue ARN is provided (not null)
# Note: SQS queue policy must allow S3 to send messages before this can be created
# The queue policy is created in the SQS module and must exist before this notification
# AWS requires the queue policy to be fully propagated before S3 can validate the destination
resource "aws_s3_bucket_notification" "raw" {
  bucket = aws_s3_bucket.raw.id

  dynamic "queue" {
    for_each = var.raw_bucket_sqs_queue_arn != null ? [1] : []
    content {
      queue_arn = var.raw_bucket_sqs_queue_arn
      events    = ["s3:ObjectCreated:*"]
    }
  }

  # Ensure queue policy exists and is propagated before creating notification
  # This helps avoid "Unable to validate destination configurations" errors
  # Note: The queue policy must be fully propagated in AWS before S3 can validate the destination
  # The parent module should use null_resource to wait for policy propagation
  # depends_on is handled at the module level in the parent configuration
}

