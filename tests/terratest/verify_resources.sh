#!/bin/bash
# Quick verification script for SQS, DynamoDB, and S3 event notification
# This script directly queries AWS to verify resources exist and are configured correctly

set -e

REGION=${AWS_DEFAULT_REGION:-us-east-1}
PREFIX="claim-dev"

echo "=== Verifying SQS Resources ==="
echo "Checking SQS queue: ${PREFIX}-s3-events"
aws sqs get-queue-attributes \
  --queue-url "https://sqs.${REGION}.amazonaws.com/$(aws sts get-caller-identity --query Account --output text)/${PREFIX}-s3-events" \
  --attribute-names All \
  --region ${REGION} 2>/dev/null && echo "✓ SQS queue exists" || echo "✗ SQS queue not found"

echo ""
echo "Checking SQS DLQ: ${PREFIX}-s3-events-dlq"
aws sqs get-queue-attributes \
  --queue-url "https://sqs.${REGION}.amazonaws.com/$(aws sts get-caller-identity --query Account --output text)/${PREFIX}-s3-events-dlq" \
  --attribute-names All \
  --region ${REGION} 2>/dev/null && echo "✓ SQS DLQ exists" || echo "✗ SQS DLQ not found"

echo ""
echo "=== Verifying DynamoDB Table ==="
echo "Checking DynamoDB table: ${PREFIX}-file-metadata"
aws dynamodb describe-table \
  --table-name "${PREFIX}-file-metadata" \
  --region ${REGION} 2>/dev/null && echo "✓ DynamoDB table exists" || echo "✗ DynamoDB table not found"

echo ""
echo "=== Verifying S3 Event Notification ==="
echo "Checking S3 bucket: ${PREFIX}-raw"
aws s3api get-bucket-notification-configuration \
  --bucket "${PREFIX}-raw" \
  --region ${REGION} 2>/dev/null | grep -q "QueueConfigurations" && echo "✓ S3 event notification configured" || echo "✗ S3 event notification not configured"

echo ""
echo "=== Summary ==="
echo "All checks completed. Review output above for any missing resources."

