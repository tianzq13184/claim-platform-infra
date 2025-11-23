# 🚀 快速开始指南

## 5 分钟快速上手

### 1️⃣ 初始化后端（只需一次）

```bash
cd infra/backend
terraform init
terraform apply \
  -var="state_bucket_name=claim-terraform-state" \
  -var="lock_table_name=claim-terraform-locks" \
  -var="region=us-east-1"
```

### 2️⃣ 运行测试

```bash
# 进入测试目录
cd tests/terratest

# 安装依赖
go mod tidy

# 运行测试（会自动创建和清理资源）
go test -v -timeout 30m
```

### 3️⃣ 部署开发环境

```bash
cd infra/env/dev
terraform init
terraform plan    # 查看将要创建的资源
terraform apply   # 创建资源
```

### 4️⃣ 验证部署

```bash
# 快速验证脚本
./scripts/validate_env.sh dev

# 或查看 Terraform 输出
cd infra/env/dev
terraform output
```

---

## 📋 常用命令速查

### 测试相关

```bash
# 运行所有测试
cd tests/terratest && go test -v -timeout 30m

# 运行特定测试
go test -v -run TestInfrastructure/PlanCheck
go test -v -run TestInfrastructure/VerifyAWSResources

# 查看测试日志
go test -v 2>&1 | tee test.log
```

### 部署相关

```bash
# Dev 环境
cd infra/env/dev
terraform init && terraform plan && terraform apply

# Stage 环境（需要先创建配置）
cd infra/env/stage
terraform init && terraform plan && terraform apply

# Prod 环境（需要先创建配置）
cd infra/env/prod
terraform init && terraform plan && terraform apply
```

### 查看状态

```bash
terraform show          # 显示当前状态
terraform state list    # 列出所有资源
terraform output        # 查看输出值
```

### 检查变更

```bash
terraform plan                    # 查看计划变更
terraform plan -detailed-exitcode # 检查 drift（退出码 0=无变更，2=有变更）
```

### 清理资源

```bash
terraform destroy                 # 删除所有资源
terraform destroy -target=xxx    # 删除特定资源
```

---

## 🎯 环境选择指南

| 环境 | 用途 | 何时使用 | 审批要求 |
|------|------|----------|----------|
| **Dev** | 开发和测试 | 日常开发、功能测试 | 无需审批 |
| **Stage** | 预发布验证 | 发布前测试、UAT | 需要审批 |
| **Prod** | 生产环境 | 服务真实用户 | 严格审批 |

### 选择环境的原则

- ✅ **开发新功能** → 使用 Dev
- ✅ **测试配置变更** → 使用 Dev
- ✅ **发布前验证** → 使用 Stage
- ✅ **性能测试** → 使用 Stage
- ✅ **服务用户** → 使用 Prod（仅限已验证的配置）

---

## ⚠️ 重要提示

1. **测试会产生费用**: Terratest 会创建真实 AWS 资源
2. **自动清理**: 测试完成后会自动销毁资源
3. **状态管理**: 不要手动编辑 `.tfstate` 文件
4. **环境隔离**: 不同环境使用不同的 CIDR 和资源名称
5. **生产谨慎**: 生产环境变更需要仔细审查

---

## 📚 更多信息

- **详细指南**: 查看 [USAGE_GUIDE.md](./USAGE_GUIDE.md)
- **测试文档**: 查看 [tests/terratest/README.md](./tests/terratest/README.md)
- **项目说明**: 查看 [README.md](./README.md)

---

## 🆘 遇到问题？

1. **检查 AWS 凭证**: `aws sts get-caller-identity`
2. **检查后端**: 确保 S3 存储桶和 DynamoDB 表已创建
3. **查看日志**: 使用 `-v` 参数查看详细输出
4. **查看文档**: 参考 USAGE_GUIDE.md 的常见问题部分

