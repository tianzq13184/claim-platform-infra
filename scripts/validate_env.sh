#!/usr/bin/env bash
set -euo pipefail

# Simple AWS CLI validation to ensure core Phase 0 resources exist.
ENVIRONMENT="${1:-dev}"
PREFIX="claim-${ENVIRONMENT}"

echo "Validating VPC endpoints..."
aws ec2 describe-vpc-endpoints \
  --filters "Name=tag:Name,Values=${PREFIX}-s3-endpoint" \
  --query "VpcEndpoints[].VpcEndpointId" \
  --output text

echo "Validating S3 buckets..."
for bucket in "${PREFIX}-raw" "${PREFIX}-lake" "${PREFIX}-audit"; do
  aws s3api get-bucket-versioning --bucket "${bucket}"
  aws s3api get-bucket-encryption --bucket "${bucket}"
done

echo "Validating Glue databases..."
for db in claim_raw_db claim_silver_db claim_gold_db; do
  aws glue get-database --name "${db}" >/dev/null
done

echo "Validation complete."

