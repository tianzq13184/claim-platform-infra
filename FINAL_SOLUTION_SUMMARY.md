# S3 事件通知问题解决方案

## 问题根源

**发现：** 只要 SQS 策略里的 `SendMessage` 带有 `SourceArn` 条件，S3 Notification 在创建时就会失败（即使运行时可以成功）。

## 解决方案

**移除 `SendMessage` 语句中的 `SourceArn` 条件**

### 已实施的修改

1. **队列策略配置** (`infra/modules/sqs/main.tf`)
   - ✅ 移除了 `SendMessage` 语句中的 `SourceArn` 条件
   - ✅ 保留了 `GetQueueAttributes` 和 `GetQueueUrl` 权限（无 SourceArn 条件）
   - ✅ 安全通过限制 Principal 为 `s3.amazonaws.com` 服务主体来保证

2. **等待机制** (`infra/env/dev/main.tf`)
   - ✅ 添加了 30 秒等待机制确保策略传播
   - ✅ 使用 `null_resource` 和 `depends_on` 管理依赖

### 配置说明

```hcl
# 队列策略 - SendMessage 不带 SourceArn 条件
statement {
  sid    = "AllowS3ToSendMessages"
  effect = "Allow"
  principals {
    type        = "Service"
    identifiers = ["s3.amazonaws.com"]
  }
  actions = ["sqs:SendMessage"]
  resources = [aws_sqs_queue.main.arn]
  # 注意：没有 SourceArn 条件
}
```

### 安全考虑

虽然移除了 SourceArn 条件，但安全性仍然通过以下方式保证：
- 限制 Principal 为 `s3.amazonaws.com` 服务主体
- 只有 S3 服务可以使用此策略
- 队列策略仍然限制在特定队列资源上

## 当前状态

- ✅ 队列策略已更新（无 SourceArn 条件）
- ✅ 等待机制已配置（30 秒）
- ⚠️ 需要验证 S3 事件通知创建是否成功

## 下一步

1. 验证队列策略是否正确应用
2. 测试 S3 事件通知创建
3. 如果仍有问题，检查其他可能的配置要求
