terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
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
  service_roles   = local.role_arns
  tags            = local.tags
}

module "glue_catalog" {
  source               = "../../modules/glue_catalog"
  database_names       = var.glue_database_names
  lakeformation_admins = var.key_admin_arns
  tags                 = local.tags
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
  account_id = data.aws_caller_identity.current.account_id
  tags       = local.tags
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

