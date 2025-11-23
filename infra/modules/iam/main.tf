locals {
  # Base ETL policies (always included)
  etl_base_policies = [
    {
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        var.raw_bucket_arn,
        "${var.raw_bucket_arn}/*",
        var.lake_bucket_arn,
        "${var.lake_bucket_arn}/*"
      ]
    },
    {
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = values(var.kms_key_arns)
    },
    {
      actions = [
        "glue:GetDatabase",
        "glue:GetTables",
        "glue:GetTable",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:DeleteTable",
        "glue:GetPartitions",
        "glue:BatchCreatePartition",
        "glue:BatchDeletePartition"
      ]
      resources = [
        var.glue_catalog_arns.raw_db,
        "${var.glue_catalog_arns.raw_db}/*",
        var.glue_catalog_arns.silver_db,
        "${var.glue_catalog_arns.silver_db}/*",
        var.glue_catalog_arns.gold_db,
        "${var.glue_catalog_arns.gold_db}/*"
      ]
    },
    {
      actions = [
        "glue:GetJob",
        "glue:GetJobRun",
        "glue:StartJobRun",
        "glue:GetJobRuns",
        "glue:BatchStopJobRun"
      ]
      resources = ["*"]
    }
  ]

  # Redshift policies (conditionally added)
  etl_redshift_policies = concat(
    length(var.redshift_cluster_identifier) > 0 ? [
      {
        actions = [
          "redshift:DescribeClusters",
          "redshift:DescribeClusterDbRevisions",
          "redshift:DescribeClusterSnapshots",
          "redshift:DescribeLoggingStatus",
          "redshift:GetClusterCredentials",
          "redshift-data:ExecuteStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:GetStatementResult",
          "redshift-data:ListStatements",
          "redshift-data:CancelStatement"
        ]
        resources = [
          "arn:aws:redshift:*:*:cluster:${var.redshift_cluster_identifier}",
          "arn:aws:redshift:*:*:dbgroup:${var.redshift_cluster_identifier}/*"
        ]
      }
    ] : [],
    length(var.redshift_namespace_arn) > 0 ? [
      {
        actions = [
          "redshift-serverless:GetWorkgroup",
          "redshift-serverless:GetNamespace",
          "redshift-data:ExecuteStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:GetStatementResult",
          "redshift-data:ListStatements",
          "redshift-data:CancelStatement"
        ]
        resources = [var.redshift_namespace_arn, "${var.redshift_namespace_arn}/*"]
      }
    ] : []
  )

  role_definitions = {
    ingestion = {
      name        = "role-claim-ingestion"
      description = "Allows ingestion workflows to deposit files securely."
      trusted     = var.ingestion_trusted_principals
      policy = [{
        actions   = ["s3:PutObject", "s3:PutObjectAcl"]
        resources = ["${var.raw_bucket_arn}/*"]
      }]
    }
    etl = {
      name        = "role-claim-etl"
      description = "Allows Glue/Lambda ETL jobs to read/write raw and lake data, and write to Redshift."
      trusted     = var.etl_trusted_principals
      policy      = concat(local.etl_base_policies, local.etl_redshift_policies)
    }
    analyst = {
      name        = "role-claim-analyst"
      description = "Read-only access to curated data."
      trusted     = var.analyst_trusted_principals
      policy = [
        {
          actions = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          resources = [
            var.lake_bucket_arn,
            "${var.lake_bucket_arn}/*"
          ]
        },
        {
          actions = [
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          resources = [var.kms_key_arns.lake]
        },
        {
          actions = [
            "glue:GetDatabase",
            "glue:GetTables",
            "glue:GetTable",
            "glue:GetPartitions"
          ]
          resources = [
            var.glue_catalog_arns.silver_db,
            "${var.glue_catalog_arns.silver_db}/*",
            var.glue_catalog_arns.gold_db,
            "${var.glue_catalog_arns.gold_db}/*"
          ]
        }
      ]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "this" {
  for_each = local.role_definitions

  name                 = each.value.name
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.assume_role[each.key].json
  max_session_duration = 3600

  tags = merge(var.tags, { Name = each.value.name })
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.role_definitions

  # Allow trusted AWS principals (roles/users from variables)
  dynamic "statement" {
    for_each = length(each.value.trusted) > 0 ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      effect  = "Allow"

      principals {
        type        = "AWS"
        identifiers = each.value.trusted
      }
    }
  }

  # Allow AWS Glue service to assume ETL role
  dynamic "statement" {
    for_each = each.key == "etl" ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      effect  = "Allow"

      principals {
        type        = "Service"
        identifiers = ["glue.amazonaws.com"]
      }
    }
  }

  # Allow AWS Lambda service to assume ingestion and ETL roles
  dynamic "statement" {
    for_each = contains(["ingestion", "etl"], each.key) ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      effect  = "Allow"

      principals {
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }
    }
  }

  # For analyst role, if no trusted principals are provided, allow the account root
  # This ensures the policy always has at least one statement
  dynamic "statement" {
    for_each = each.key == "analyst" && length(each.value.trusted) == 0 ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      effect  = "Allow"

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
      condition {
        test     = "StringLike"
        variable = "aws:PrincipalArn"
        values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-claim-*"]
      }
    }
  }
}

resource "aws_iam_policy" "inline" {
  for_each = local.role_definitions

  name        = "${each.value.name}-policy"
  description = "Least privilege policy for ${each.value.name}"
  policy      = data.aws_iam_policy_document.inline[each.key].json
}

data "aws_iam_policy_document" "inline" {
  for_each = local.role_definitions

  dynamic "statement" {
    for_each = each.value.policy
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = "Allow"
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each = local.role_definitions

  role       = aws_iam_role.this[each.key].name
  policy_arn = aws_iam_policy.inline[each.key].arn
}

