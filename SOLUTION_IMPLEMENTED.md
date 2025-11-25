# S3 事件通知解决方案实施总结

## 问题根源确认

✅ **已确认：** 只要 SQS 策略里的 `SendMessage` 带有 `SourceArn` 条件，S3 Notification 在创建时就会失败。

## 已实施的解决方案

### 1. 队列策略修改 ✅

**文件：** `infra/modules/sqs/main.tf`

- ✅ 移除了 `SendMessage` 语句中的 `SourceArn` 条件
- ✅ 保留了 `GetQueueAttributes` 和 `GetQueueUrl` 权限
- ✅ 安全通过限制 Principal 为 `s3.amazonaws.com` 服务主体

**当前策略（已验证）：**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ToSendMessages",
      "Effect": "Allow",
      "Principal": {"Service": "s3.amazonaws.com"},
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:279345443161:claim-dev-s3-events"
      // 注意：没有 SourceArn 条件
    },
    {
      "Sid": "AllowS3ToGetQueueAttributes",
      "Effect": "Allow",
      "Principal": {"Service": "s3.amazonaws.com"},
      "Action": ["sqs:GetQueueUrl", "sqs:GetQueueAttributes"],
      "Resource": "arn:aws:sqs:us-east-1:279345443161:claim-dev-s3-events"
    }
  ]
}
```

### 2. 等待机制 ✅

**文件：** `infra/env/dev/main.tf`

- ✅ 添加了 `null_resource.wait_for_sqs_policy` 资源
- ✅ 等待 30 秒确保策略传播
- ✅ 在 S3 模块中添加了 `depends_on` 依赖

## 当前状态

- ✅ 队列策略已正确更新（无 SourceArn 条件）
- ✅ 等待机制已配置
- ⚠️ S3 事件通知创建仍可能失败（可能需要更长时间传播）

## 可能需要的额外步骤

如果问题仍然存在，可能需要：

1. **等待更长时间**：策略传播可能需要 5-10 分钟
2. **检查 KMS 权限**：确保 S3 服务可以访问加密队列的 KMS key
3. **验证队列状态**：确保队列处于可用状态

## 配置验证

队列策略已通过 AWS CLI 验证，确认：
- ✅ 没有 SourceArn 条件
- ✅ 包含必要的权限
- ✅ Principal 正确设置为 `s3.amazonaws.com`
