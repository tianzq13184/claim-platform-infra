# KMS Key Policy Fix for S3→SQS Notifications with SSE-KMS

## Problem Summary

The AWS API was returning "Unable to validate the following destination configurations" when attempting to configure S3 bucket notifications to SQS queues using SSE-KMS encryption.

**Root Cause**: The KMS key policy incorrectly included `kms:DescribeKey` in statements that used the condition `kms:EncryptionContext:aws:sqs:arn`. This action does NOT support this condition key, causing AWS to reject the S3 bucket notification configuration during destination validation.

## Changes Made

### 1. Fixed KMS Key Policy (`infra/env/dev/main.tf`)

**File**: `infra/env/dev/main.tf`  
**Lines**: 186-237

**Before**:
```terraform
statement {
  sid    = "AllowSQSToUseKey-MainQueue"
  effect = "Allow"
  principals {
    type        = "Service"
    identifiers = ["sqs.amazonaws.com"]
  }
  actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"  # ❌ REMOVED - Not supported with EncryptionContext condition
  ]
  resources = ["*"]
  
  condition {
    test     = "StringEquals"
    variable = "kms:EncryptionContext:aws:sqs:arn"
    values   = [module.sqs.queue_arn]
  }
}
```

**After**:
```terraform
statement {
  sid    = "AllowSQSToUseKey-MainQueue"
  effect = "Allow"
  principals {
    type        = "Service"
    identifiers = ["sqs.amazonaws.com"]
  }
  actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*"
    # ✅ kms:DescribeKey removed - does not support EncryptionContext condition
  ]
  resources = ["*"]
  
  condition {
    test     = "StringEquals"
    variable = "kms:EncryptionContext:aws:sqs:arn"
    values   = [module.sqs.queue_arn]
  }
}
```

**Same fix applied to DLQ statement** (lines 213-237).

### 2. Updated SQS Queue Policy (`infra/modules/sqs/main.tf`)

**File**: `infra/modules/sqs/main.tf`  
**Lines**: 39-59

**Before**:
```terraform
statement {
  sid    = "AllowS3ToSendMessages"
  effect = "Allow"
  principals {
    type        = "Service"
    identifiers = ["s3.amazonaws.com"]
  }
  actions = ["sqs:SendMessage"]
  resources = [aws_sqs_queue.main.arn]
  # No SourceArn condition
}
```

**After**:
```terraform
statement {
  sid    = "AllowS3ToSendMessages"
  effect = "Allow"
  principals {
    type        = "Service"
    identifiers = ["s3.amazonaws.com"]
  }
  actions = ["sqs:SendMessage"]
  resources = [aws_sqs_queue.main.arn]
  
  condition {
    test     = "ArnEquals"
    variable = "aws:SourceArn"
    values   = [var.s3_bucket_arn]
  }
  
  condition {
    test     = "StringEquals"
    variable = "aws:SourceAccount"
    values   = [var.account_id]
  }
}
```

### 3. Added Account ID Variable (`infra/modules/sqs/variables.tf`)

**File**: `infra/modules/sqs/variables.tf`  
**Lines**: Added after line 19

```terraform
variable "account_id" {
  description = "AWS account ID for SourceAccount condition in queue policy"
  type        = string
}
```

### 4. Updated Module Call (`infra/env/dev/main.tf`)

**File**: `infra/env/dev/main.tf`  
**Lines**: 67-76

**Before**:
```terraform
module "sqs" {
  source              = "../../modules/sqs"
  queue_name          = "${local.name_prefix}-s3-events"
  dlq_name            = "${local.name_prefix}-s3-events-dlq"
  kms_key_id          = module.kms.key_arns.raw
  s3_bucket_arn       = "arn:aws:s3:::${local.name_prefix}-raw"
  message_retention_seconds = 345600
  max_receive_count   = 3
  tags                = local.tags
}
```

**After**:
```terraform
module "sqs" {
  source              = "../../modules/sqs"
  queue_name          = "${local.name_prefix}-s3-events"
  dlq_name            = "${local.name_prefix}-s3-events-dlq"
  kms_key_id          = module.kms.key_arns.raw
  s3_bucket_arn       = "arn:aws:s3:::${local.name_prefix}-raw"
  account_id          = data.aws_caller_identity.current.account_id  # ✅ Added
  message_retention_seconds = 345600
  max_receive_count   = 3
  tags                = local.tags
}
```

## Why This Fixes the Issue

### KMS Key Policy Fix

1. **AWS KMS Action Support**: The `kms:DescribeKey` action does NOT support the `kms:EncryptionContext:aws:sqs:arn` condition key. When AWS validates the S3→SQS notification configuration, it checks all KMS key policy statements that reference the SQS queue ARN. If any statement contains an action that doesn't support the condition, validation fails.

2. **Required Actions for SQS SSE-KMS**: For SQS queues using CMK encryption, AWS only requires:
   - `kms:GenerateDataKey*` - Generate encryption keys
   - `kms:Encrypt` - Encrypt messages
   - `kms:Decrypt` - Decrypt messages
   - `kms:ReEncrypt*` - Re-encrypt with different keys (optional)

3. **EncryptionContext Condition**: The `kms:EncryptionContext:aws:sqs:arn` condition ensures that the KMS key can only be used by SQS for the specific queue ARN, maintaining least-privilege security.

### SQS Queue Policy Enhancement

The addition of `SourceArn` and `SourceAccount` conditions provides:
- **SourceArn**: Ensures only the specific S3 bucket can send messages
- **SourceAccount**: Prevents cross-account access (defense in depth)

These conditions maintain least-privilege while allowing S3 event notifications to work correctly.

## Validation

✅ **Terraform Validate**: Passed  
✅ **Terraform Plan**: Shows expected changes:
- KMS key policy updated (removes `kms:DescribeKey` from EncryptionContext statements)
- SQS queue policy updated (adds SourceArn and SourceAccount conditions)
- No breaking changes to other resources

## Security Impact

- ✅ **No Weakening**: The fix maintains least-privilege principles
- ✅ **Enhanced Security**: Added SourceArn and SourceAccount conditions to SQS queue policy
- ✅ **Compliance**: KMS key policy now matches AWS requirements for SQS SSE-KMS

## Next Steps

1. Review the terraform plan output
2. Apply the changes: `terraform apply`
3. Verify S3→SQS notifications work correctly
4. Test that messages are properly encrypted and delivered

