# 🚀 GitHub 提交指南

## 第一步：创建 GitHub 仓库

### 方法 1: 在 GitHub 网站创建（推荐）

1. 登录 [GitHub](https://github.com)
2. 点击右上角 **"+"** → **"New repository"**
3. 填写仓库信息：
   - **Repository name**: `claim-management-system`
   - **Description**: `AWS Infrastructure as Code for Claim Management System - Phase 0`
   - **Visibility**: 选择 Public 或 Private
   - **不要**勾选 "Initialize with README"（我们已经有了）
4. 点击 **"Create repository"**

### 方法 2: 使用 GitHub CLI（如果已安装）

```bash
gh repo create claim-management-system --public --description "AWS Infrastructure as Code for Claim Management System"
```

---

## 第二步：初始化 Git 仓库

在项目根目录执行：

```bash
cd /Users/kurttian/Desktop/claim-management-system

# 1. 初始化 Git 仓库
git init

# 2. 添加所有文件（.gitignore 会自动排除敏感文件）
git add .

# 3. 检查将要提交的文件（确保没有敏感信息）
git status

# 4. 创建首次提交
git commit -m "Initial commit: Phase 0 infrastructure setup

- Add Terraform modules (network, s3, kms, iam, glue_catalog, cloudtrail)
- Add dev environment configuration
- Add Terratest integration tests
- Add documentation (README, USAGE_GUIDE, QUICK_START)
- Add validation scripts"
```

---

## 第三步：连接到 GitHub 仓库

### 如果使用 HTTPS（推荐新手）

```bash
# 替换 YOUR_USERNAME 为你的 GitHub 用户名
git remote add origin https://github.com/YOUR_USERNAME/claim-management-system.git

# 验证远程仓库
git remote -v
```

### 如果使用 SSH

```bash
# 替换 YOUR_USERNAME 为你的 GitHub 用户名
git remote add origin git@github.com:YOUR_USERNAME/claim-management-system.git

# 验证远程仓库
git remote -v
```

---

## 第四步：推送到 GitHub

```bash
# 推送代码到 GitHub（首次推送）
git branch -M main
git push -u origin main
```

如果遇到认证问题：

**HTTPS 方式**:
- GitHub 已不再支持密码认证
- 需要使用 [Personal Access Token](https://github.com/settings/tokens)
- 或在推送时使用 GitHub CLI: `gh auth login`

**SSH 方式**:
- 确保已配置 SSH 密钥: `ssh -T git@github.com`
- 如果未配置，参考: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

---

## 第五步：验证提交

1. 访问你的 GitHub 仓库页面
2. 确认所有文件都已上传
3. 检查 `.gitignore` 是否正确排除了敏感文件
4. **重要**: 确认没有提交以下敏感文件：
   - `*.tfvars` 文件
   - `*.tfstate` 文件
   - `.terraform/` 目录
   - 包含 AWS 凭证的文件

---

## 后续提交工作流

### 日常提交流程

```bash
# 1. 查看更改
git status

# 2. 添加更改的文件
git add <file1> <file2>
# 或添加所有更改
git add .

# 3. 提交更改（使用有意义的提交信息）
git commit -m "描述你的更改"

# 4. 推送到 GitHub
git push
```

### 提交信息规范

使用清晰的提交信息：

```bash
# 好的提交信息示例
git commit -m "Add Redshift support to IAM module"
git commit -m "Fix S3 bucket policy for VPC endpoint access"
git commit -m "Update test coverage for infrastructure validation"
git commit -m "Add documentation for environment setup"

# 避免的提交信息
git commit -m "fix"           # 太模糊
git commit -m "update"        # 不清楚更新了什么
git commit -m "changes"       # 没有描述性
```

### 使用分支工作流（推荐）

```bash
# 1. 创建功能分支
git checkout -b feature/add-redshift-support

# 2. 进行更改并提交
git add .
git commit -m "Add Redshift support"

# 3. 推送到 GitHub
git push -u origin feature/add-redshift-support

# 4. 在 GitHub 创建 Pull Request
# 5. 代码审查后合并到 main 分支
```

---

## 安全检查清单

在推送前，确保：

- [ ] 没有提交 `*.tfvars` 文件（可能包含敏感配置）
- [ ] 没有提交 `*.tfstate` 文件（包含状态信息）
- [ ] 没有提交 AWS 凭证或密钥
- [ ] 没有提交 `.terraform/` 目录
- [ ] `.gitignore` 文件已正确配置
- [ ] README 文件已更新
- [ ] 代码已通过测试（如果可能）

### 检查敏感信息

```bash
# 搜索可能的敏感信息
grep -r "AKIA" . --exclude-dir=.git  # AWS Access Key
grep -r "arn:aws:iam::" . --exclude-dir=.git  # IAM ARNs (检查是否包含真实账户ID)
grep -r "password" . --exclude-dir=.git  # 密码
grep -r "secret" . --exclude-dir=.git  # 密钥
```

---

## 常见问题

### Q: 推送时提示 "Permission denied"

**A**: 
- HTTPS: 使用 Personal Access Token 而不是密码
- SSH: 确保 SSH 密钥已添加到 GitHub 账户

### Q: 如何更新远程仓库 URL？

```bash
# 查看当前远程仓库
git remote -v

# 更新 URL
git remote set-url origin https://github.com/YOUR_USERNAME/claim-management-system.git
```

### Q: 如何撤销最后一次提交？

```bash
# 撤销提交但保留更改
git reset --soft HEAD~1

# 完全撤销提交和更改（谨慎使用）
git reset --hard HEAD~1
```

### Q: 如何忽略已跟踪的文件？

```bash
# 从 Git 中移除但保留本地文件
git rm --cached <file>

# 添加到 .gitignore
echo "<file>" >> .gitignore

# 提交更改
git add .gitignore
git commit -m "Add file to .gitignore"
```

---

## 推荐的 GitHub 设置

### 1. 添加仓库描述和主题

在 GitHub 仓库页面：
- 点击 **Settings** → 添加描述
- 添加主题标签: `terraform`, `aws`, `infrastructure-as-code`, `hipaa`, `devops`

### 2. 保护 main 分支

在 GitHub 仓库页面：
- **Settings** → **Branches**
- 添加分支保护规则
- 要求 Pull Request 审查
- 要求状态检查通过

### 3. 配置 GitHub Actions Secrets

如果使用 CI/CD：
- **Settings** → **Secrets and variables** → **Actions**
- 添加必要的 AWS 凭证和 Terraform 配置

---

## 快速命令参考

```bash
# 初始化并首次提交
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/claim-management-system.git
git push -u origin main

# 日常更新
git add .
git commit -m "描述更改"
git push

# 查看状态
git status
git log --oneline
```

---

**完成！** 🎉 你的代码现在应该在 GitHub 上了。

