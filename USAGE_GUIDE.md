# Claim Management System - 使用指南

## 📚 目录

1. [项目概述](#项目概述)
2. [环境选择的目的](#环境选择的目的)
3. [快速开始](#快速开始)
4. [运行测试](#运行测试)
5. [部署不同环境](#部署不同环境)
6. [日常操作](#日常操作)
7. [最佳实践](#最佳实践)
8. [常见问题](#常见问题)

---

## 项目概述

这是一个用于 Claim Management System 的 AWS 基础设施即代码（IaC）项目，使用 Terraform 管理。

### 项目结构

```
claim-management-system/
├── infra/
│   ├── backend/              # Terraform 状态后端（S3 + DynamoDB）
│   ├── modules/              # 可重用的 Terraform 模块
│   │   ├── network/          # VPC、子网、端点
│   │   ├── s3/               # S3 存储桶
│   │   ├── kms/              # KMS 加密密钥
│   │   ├── iam/              # IAM 角色和策略
│   │   ├── glue_catalog/     # Glue 数据目录
│   │   └── cloudtrail/       # CloudTrail 审计
│   └── env/                  # 环境配置
│       ├── dev/              # 开发环境（完整配置）
│       ├── stage/            # 预发布环境（待配置）
│       └── prod/             # 生产环境（待配置）
├── tests/
│   └── terratest/            # Go Terratest 集成测试
├── scripts/
│   └── validate_env.sh       # 环境验证脚本
└── .github/workflows/        # CI/CD 流水线
```

---

## 环境选择的目的

### 为什么需要多个环境？

在软件开发中，使用多个环境（Dev → Stage → Prod）是标准实践，原因如下：

#### 1. **开发环境 (Dev)**
- **目的**: 开发和测试新功能
- **特点**:
  - 快速迭代，频繁变更
  - 成本较低（可以使用较小的实例）
  - 允许实验性配置
  - 不需要严格的审批流程
- **使用场景**:
  - 开发新功能
  - 测试 Terraform 配置变更
  - 运行集成测试
  - 验证新模块

#### 2. **预发布环境 (Stage)**
- **目的**: 模拟生产环境，进行最终测试
- **特点**:
  - 配置接近生产环境
  - 用于性能测试和压力测试
  - 验证部署流程
  - 需要审批才能变更
- **使用场景**:
  - 发布前的最终验证
  - 用户验收测试（UAT）
  - 灾难恢复演练
  - 性能基准测试

#### 3. **生产环境 (Prod)**
- **目的**: 服务真实用户
- **特点**:
  - 最高安全标准
  - 严格的变更控制
  - 需要多人审批
  - 完整的监控和告警
  - 数据备份和恢复计划
- **使用场景**:
  - 服务真实业务
  - 处理真实数据
  - 必须保证高可用性

### 环境隔离的好处

1. **风险隔离**: 开发错误不会影响生产
2. **数据安全**: 生产数据与测试数据分离
3. **合规性**: 满足 HIPAA 等合规要求
4. **团队协作**: 不同团队可以并行工作
5. **成本控制**: 开发环境可以使用更便宜的配置

---

## 快速开始

### 前置要求

1. **安装工具**:
   ```bash
   # Terraform
   brew install terraform  # macOS
   # 或从 https://www.terraform.io/downloads 下载

   # AWS CLI
   brew install awscli  # macOS
   # 或从 https://aws.amazon.com/cli/ 下载

   # Go (用于测试)
   brew install go  # macOS
   ```

2. **配置 AWS 凭证**:
   ```bash
   aws configure
   # 输入 Access Key ID, Secret Access Key, Region
   ```

3. **验证 AWS 访问**:
   ```bash
   aws sts get-caller-identity
   ```

### 第一步：初始化后端

在部署任何环境之前，需要先创建 Terraform 状态后端：

```bash
cd infra/backend
terraform init
terraform apply \
  -var="state_bucket_name=claim-terraform-state" \
  -var="lock_table_name=claim-terraform-locks" \
  -var="region=us-east-1"
```

**注意**: 这个步骤只需要执行一次，后端会被所有环境共享。

---

## 运行测试

### 1. 运行 Terratest 集成测试

这是最全面的测试，会实际创建和验证 AWS 资源：

```bash
cd tests/terratest

# 安装依赖
go mod tidy

# 运行所有测试
go test -v -timeout 30m

# 运行特定测试
go test -v -timeout 30m -run TestInfrastructure/PlanCheck
go test -v -timeout 30m -run TestInfrastructure/Apply
go test -v -timeout 30m -run TestInfrastructure/VerifyOutputs
go test -v -timeout 30m -run TestInfrastructure/VerifyAWSResources
go test -v -timeout 30m -run TestInfrastructure/CheckDrift
```

**测试会做什么**:
1. ✅ 运行 `terraform plan` 检查破坏性变更
2. ✅ 运行 `terraform apply` 创建资源
3. ✅ 验证所有 Terraform outputs
4. ✅ 通过 AWS API 验证资源存在和配置
5. ✅ 检查 drift（确保配置与基础设施一致）
6. ✅ 自动清理（`terraform destroy`）

**测试时间**: 约 10-20 分钟

### 2. 运行快速验证脚本

这个脚本只验证资源是否存在，不创建新资源：

```bash
# 验证 dev 环境
./scripts/validate_env.sh dev

# 验证其他环境（如果已部署）
./scripts/validate_env.sh stage
./scripts/validate_env.sh prod
```

**验证内容**:
- VPC 端点是否存在
- S3 存储桶是否存在且配置正确
- Glue 数据库是否存在

### 3. Terraform 验证

只检查配置语法，不连接 AWS：

```bash
cd infra/env/dev
terraform init
terraform validate
terraform fmt -check
```

---

## 部署不同环境

### 部署开发环境 (Dev)

开发环境是唯一完全配置好的环境：

```bash
# 1. 进入 dev 目录
cd infra/env/dev

# 2. 初始化 Terraform（连接后端）
terraform init

# 3. 查看将要创建的资源
terraform plan

# 4. 应用配置（创建资源）
terraform apply

# 5. 查看输出
terraform output
```

**配置变量** (可选，创建 `terraform.tfvars`):

```hcl
# infra/env/dev/terraform.tfvars
region = "us-east-1"
vpc_cidr = "10.10.0.0/16"

# IAM 配置（根据实际情况修改）
key_admin_arns = ["arn:aws:iam::123456789012:role/SecurityAdmin"]
ingestion_trusted_principals = ["arn:aws:iam::123456789012:role/claim-ingestion-lambda"]
etl_trusted_principals = ["arn:aws:iam::123456789012:role/AWSGlueServiceRole-default"]
analyst_trusted_principals = ["arn:aws:iam::123456789012:role/BIReadOnly"]

# Redshift 配置（可选）
# redshift_cluster_identifier = "claim-dev-cluster"
# redshift_namespace_arn = "arn:aws:redshift-serverless:us-east-1:123456789012:namespace/xxx"
```

### 创建 Stage 环境

Stage 环境需要从 Dev 复制并修改：

```bash
# 1. 复制 dev 配置
cp -r infra/env/dev infra/env/stage

# 2. 修改 backend.tf
cd infra/env/stage
# 编辑 backend.tf，将 key 改为: "env/stage/terraform.tfstate"

# 3. 修改 main.tf 中的环境标识
# 将 local.name_prefix 改为 "claim-stage"
# 将 tags.Environment 改为 "stage"

# 4. 修改 CIDR（避免与 dev 冲突）
# 在 variables.tf 或 terraform.tfvars 中设置:
# vpc_cidr = "10.20.0.0/16"
# public_subnet_cidrs = ["10.20.0.0/24", "10.20.1.0/24"]
# private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]

# 5. 部署
terraform init
terraform plan
terraform apply
```

### 创建 Prod 环境

生产环境需要更严格的配置：

```bash
# 1. 复制 dev 配置
cp -r infra/env/dev infra/env/prod

# 2. 修改配置（类似 stage，但更严格）
cd infra/env/prod
# - 修改 backend.tf key: "env/prod/terraform.tfstate"
# - 修改 name_prefix: "claim-prod"
# - 修改 Environment tag: "prod"
# - 使用不同的 CIDR: "10.30.0.0/16"

# 3. 添加额外的安全配置
# - 更严格的 IAM 策略
# - 额外的监控和告警
# - 备份配置

# 4. 部署（需要审批）
terraform init
terraform plan  # 仔细审查计划
terraform apply  # 需要确认
```

---

## 日常操作

### 查看当前状态

```bash
cd infra/env/dev
terraform show          # 显示当前状态
terraform state list    # 列出所有资源
terraform output        # 查看输出值
```

### 修改配置

```bash
# 1. 编辑配置文件
vim infra/env/dev/main.tf  # 或 variables.tf

# 2. 查看变更
terraform plan

# 3. 应用变更
terraform apply
```

### 更新模块

如果修改了模块代码：

```bash
cd infra/env/dev
terraform init -upgrade  # 更新模块
terraform plan          # 查看影响
terraform apply         # 应用更新
```

### 删除资源

```bash
# 删除整个环境（谨慎！）
cd infra/env/dev
terraform destroy

# 删除特定资源
terraform destroy -target=module.s3.aws_s3_bucket.raw
```

### 检查 Drift

检测基础设施是否被手动修改：

```bash
cd infra/env/dev
terraform plan -detailed-exitcode

# 退出码:
# 0 = 无变更
# 1 = 错误
# 2 = 有变更（drift 检测到）
```

---

## 最佳实践

### 1. 版本控制

- ✅ 所有 Terraform 代码提交到 Git
- ✅ 使用有意义的提交信息
- ✅ 通过 Pull Request 审查变更
- ✅ 不要提交 `.tfstate` 文件（已在 .gitignore）

### 2. 状态管理

- ✅ 始终使用远程后端（S3 + DynamoDB）
- ✅ 不要手动编辑 `.tfstate` 文件
- ✅ 定期备份状态文件
- ✅ 使用状态锁定（DynamoDB）防止并发修改

### 3. 安全

- ✅ 使用 IAM 角色而非硬编码凭证
- ✅ 定期轮换访问密钥
- ✅ 使用最小权限原则
- ✅ 启用 CloudTrail 审计

### 4. 测试

- ✅ 在 Dev 环境测试所有变更
- ✅ 运行 Terratest 验证配置
- ✅ 在 Stage 环境验证生产配置
- ✅ 生产变更前进行代码审查

### 5. 成本优化

- ✅ Dev 环境使用较小的实例
- ✅ 使用 Spot 实例（如果适用）
- ✅ 定期审查未使用的资源
- ✅ 使用 AWS Cost Explorer 监控

---

## 常见问题

### Q1: 如何选择运行哪个环境的测试？

**A**: 测试默认使用 `infra/env/dev`。要测试其他环境：

```bash
# 修改 tests/terratest/infrastructure_test.go
terraformDir := filepath.Join("..", "..", "infra", "env", "stage")  # 改为 stage 或 prod
```

### Q2: 测试失败，提示 "Backend configuration not found"

**A**: 确保：
1. 后端 S3 存储桶已创建（运行 `infra/backend` 的 terraform apply）
2. DynamoDB 锁表已创建
3. AWS 凭证有访问权限

### Q3: 如何在不同 AWS 账户部署？

**A**: 使用 AWS Profile：

```bash
# 配置多个账户
aws configure --profile dev-account
aws configure --profile prod-account

# 使用特定账户
export AWS_PROFILE=dev-account
terraform apply
```

### Q4: 如何查看测试日志？

**A**: Terratest 使用 Go 的测试框架：

```bash
# 详细输出
go test -v -timeout 30m

# 保存日志到文件
go test -v -timeout 30m 2>&1 | tee test.log
```

### Q5: 测试创建的资源会收费吗？

**A**: 会的。测试会创建真实的 AWS 资源（VPC、S3、KMS 等），会产生费用。测试完成后会自动清理，但：
- VPC 和 NAT Gateway 可能产生少量费用
- S3 存储（如果测试期间有数据）会产生费用
- 建议在测试账户运行，或使用 AWS Free Tier

### Q6: 如何只测试特定模块？

**A**: 使用 Terraform target：

```bash
cd infra/env/dev
terraform plan -target=module.network
terraform apply -target=module.network
```

### Q7: 如何回滚变更？

**A**: Terraform 不直接支持回滚，但可以：

```bash
# 方法1: 使用 Git 回退代码
git checkout <previous-commit>
terraform apply

# 方法2: 手动修改配置回到之前状态
# 然后 terraform apply

# 方法3: 使用 terraform state 命令（高级）
```

### Q8: 多个环境可以共享资源吗？

**A**: 可以，但不推荐。最佳实践：
- ✅ 每个环境完全独立（隔离风险）
- ✅ 共享后端（S3 状态存储）
- ❌ 不共享业务资源（VPC、S3 数据桶等）

---

## 下一步

1. **阅读代码**: 查看 `infra/modules/` 了解模块结构
2. **运行测试**: 在 Dev 环境运行完整测试套件
3. **部署 Dev**: 部署开发环境并验证
4. **配置 Stage**: 创建预发布环境
5. **准备 Prod**: 规划生产环境部署

---

## 获取帮助

- **文档**: 查看 `README.md` 和 `tests/terratest/README.md`
- **代码审查**: 提交 Pull Request 获取团队反馈
- **问题报告**: 在 GitHub Issues 中报告问题

---

**祝使用愉快！** 🚀

