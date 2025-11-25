# Dead Letter Queue (DLQ) for failed messages
resource "aws_sqs_queue" "dlq" {
  name                      = var.dlq_name
  message_retention_seconds = var.dlq_message_retention_seconds
  kms_master_key_id         = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.tags, {
    Name  = var.dlq_name
    Type  = "DLQ"
  })
}

# Main SQS queue for S3 event notifications
resource "aws_sqs_queue" "main" {
  name                      = var.queue_name
  message_retention_seconds = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  kms_master_key_id         = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  # Redrive policy to send failed messages to DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, {
    Name  = var.queue_name
    Type  = "MainQueue"
  })
}

# Queue policy to allow S3 to send messages
# Updated to include SourceArn and SourceAccount conditions for least-privilege security
data "aws_iam_policy_document" "queue_policy" {
  # Statement 1: Allow S3 to send messages
  # Includes SourceArn and SourceAccount conditions for security
  statement {
    sid    = "AllowS3ToSendMessages"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

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
  
  # Statement 2: Allow S3 to get queue attributes (needed for validation)
  statement {
    sid    = "AllowS3ToGetQueueAttributes"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]

    resources = [aws_sqs_queue.main.arn]
  }
}

resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id
  policy    = data.aws_iam_policy_document.queue_policy.json
}

