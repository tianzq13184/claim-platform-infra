terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "claim-dev"
  tags = merge(
    {
      Environment = "dev"
      Project     = "claim-management-system"
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
  role_arns = {
    ingestion = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-claim-ingestion"
    etl       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-claim-etl"
    analyst   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role-claim-analyst"
  }
}

module "network" {
  source                = "../../modules/network"
  name                  = local.name_prefix
  cidr_block            = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  enable_nat_gateway    = true
  tags                  = local.tags
}

module "kms" {
  source          = "../../modules/kms"
  key_admin_arns  = var.key_admin_arns
  # Don't pass service_roles here - they don't exist yet
  # We'll grant permissions after IAM roles are created
  service_roles   = {}
  tags            = local.tags
}

module "glue_catalog" {
  source               = "../../modules/glue_catalog"
  database_names       = var.glue_database_names
  lakeformation_admins = var.key_admin_arns
  tags                 = local.tags
}

# Create SQS queue and DLQ for S3 event notifications
# Note: S3 bucket ARN is constructed from bucket name, so we can use it directly
module "sqs" {
  source              = "../../modules/sqs"
  queue_name          = "${local.name_prefix}-s3-events"
  dlq_name            = "${local.name_prefix}-s3-events-dlq"
  kms_key_id          = module.kms.key_arns.raw
  s3_bucket_arn       = "arn:aws:s3:::${local.name_prefix}-raw"
  message_retention_seconds = 345600  # 4 days
  max_receive_count   = 3
  tags                = local.tags
}

# Create DynamoDB table for file metadata
module "dynamodb" {
  source                        = "../../modules/dynamodb"
  table_name                    = "${local.name_prefix}-file-metadata"
  kms_key_arn                   = module.kms.key_arns.raw
  enable_point_in_time_recovery = true
  tags                          = local.tags
}

# Wait for SQS queue policy to propagate before creating S3 event notification
# AWS requires some time for queue policies to propagate across regions
# Extended to 30 seconds to ensure policy is fully propagated before S3 validation
resource "null_resource" "wait_for_sqs_policy" {
  depends_on = [module.sqs.queue_policy_id]

  triggers = {
    queue_policy_id = module.sqs.queue_policy_id
  }

  provisioner "local-exec" {
    command = "sleep 30"  # Wait 30 seconds for policy to propagate
  }
}

module "s3" {
  source                = "../../modules/s3"
  raw_bucket_name       = "${local.name_prefix}-raw"
  lake_bucket_name      = "${local.name_prefix}-lake"
  audit_bucket_name     = "${local.name_prefix}-audit"
  raw_kms_key_arn       = module.kms.key_arns.raw
  lake_kms_key_arn      = module.kms.key_arns.lake
  audit_kms_key_arn     = module.kms.key_arns.audit
  allowed_vpc_endpoint_ids = [
    module.network.vpc_endpoint_ids.s3
  ]
  account_id            = data.aws_caller_identity.current.account_id
  raw_bucket_sqs_queue_arn = module.sqs.queue_arn
  raw_bucket_sqs_queue_policy_id = module.sqs.queue_policy_id
  force_destroy         = true  # Allow cleanup in dev/test environments
  tags                  = local.tags
  
  # Ensure SQS queue and its policy are created and propagated before configuring notifications
  # The queue policy must be fully propagated in AWS before S3 can validate the destination
  depends_on = [
    module.sqs,
    module.sqs.queue_policy_id,  # Explicitly wait for queue policy to be created
    null_resource.wait_for_sqs_policy  # Wait for policy to propagate
  ]
}

module "cloudtrail" {
  source                     = "../../modules/cloudtrail"
  trail_name                 = "${local.name_prefix}-org-trail"
  s3_bucket_name             = module.s3.audit_bucket_name
  cloudwatch_log_group_name  = "/aws/claim/${local.name_prefix}/cloudtrail"
  sns_topic_name             = "${local.name_prefix}-alerts"
  tags                       = local.tags
}

module "iam" {
  source                     = "../../modules/iam"
  raw_bucket_arn             = module.s3.raw_bucket_arn
  lake_bucket_arn            = module.s3.lake_bucket_arn
  kms_key_arns               = module.kms.key_arns
  glue_catalog_arns = {
    raw_db    = module.glue_catalog.database_arns.raw
    silver_db = module.glue_catalog.database_arns.silver
    gold_db   = module.glue_catalog.database_arns.gold
  }
  ingestion_trusted_principals = var.ingestion_trusted_principals
  etl_trusted_principals       = var.etl_trusted_principals
  analyst_trusted_principals   = var.analyst_trusted_principals
  redshift_cluster_identifier   = var.redshift_cluster_identifier
  redshift_namespace_arn        = var.redshift_namespace_arn
  tags                         = local.tags
}

# Grant KMS key permissions to IAM roles after they are created
resource "aws_kms_grant" "ingestion_raw" {
  key_id            = module.kms.key_arns.raw
  grantee_principal = module.iam.role_arns.ingestion
  operations        = ["Decrypt", "Encrypt", "GenerateDataKey", "GenerateDataKeyWithoutPlaintext"]
}

resource "aws_kms_grant" "etl_keys" {
  for_each          = module.kms.key_arns
  key_id            = each.value
  grantee_principal = module.iam.role_arns.etl
  operations         = ["Decrypt", "Encrypt", "ReEncryptFrom", "ReEncryptTo", "GenerateDataKey", "GenerateDataKeyWithoutPlaintext"]
}

resource "aws_kms_grant" "analyst_lake" {
  key_id            = module.kms.key_arns.lake
  grantee_principal = module.iam.role_arns.analyst
  operations        = ["Decrypt", "DescribeKey"]
}

