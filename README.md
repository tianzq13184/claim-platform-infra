# Claim Management System – Phase 0 Terraform

## Purpose

Implements the AWS landing zone required by Phase 0 of the Claim Management System roadmap:

- Opinionated VPC with public/private subnets, NAT, and interface/gateway endpoints.
- HIPAA-ready S3 buckets (raw, lake, audit) encrypted with dedicated KMS CMKs.
- IAM roles for ingestion, ETL, and analyst personas with least-privilege policies.
- Glue Catalog databases (`claim_raw_db`, `claim_silver_db`, `claim_gold_db`) and Lake Formation skeleton.
- Organization CloudTrail, CloudWatch metrics/alarms, SNS alerts, and weekly drift reminder.
- Terraform remote state backend (S3 + DynamoDB) plus CI/CD/testing automation.

## Repository Layout

```
infra/
  backend/           # bootstrap remote state bucket + lock table
  modules/           # reusable terraform modules (network, s3, kms, iam, cloudtrail, glue_catalog)
  env/
    dev/             # fully wired example environment (others inherit the pattern)
    stage/, prod/    # placeholders ready for parameterization
.github/workflows/   # terraform-ci.yml pipeline
tests/terratest/     # Go Terratest skeleton
scripts/             # AWS CLI integration validation
```

## Usage

1. **Bootstrap backend**
   ```bash
   terraform -chdir=infra/backend init
   terraform -chdir=infra/backend apply \
     -var="state_bucket_name=claim-terraform-state" \
     -var="lock_table_name=claim-terraform-locks"
   ```

2. **Configure environment variables**
   - Provide admin/trusted principal ARNs via `infra/env/dev/terraform.tfvars` (example):
     ```hcl
     key_admin_arns = ["arn:aws:iam::123456789012:role/SecurityAdmin"]
     ingestion_trusted_principals = ["arn:aws:iam::123456789012:role/claim-ingestion-lambda"]
     etl_trusted_principals       = ["arn:aws:iam::123456789012:role/AWSGlueServiceRole-default"]
     analyst_trusted_principals   = ["arn:aws:iam::123456789012:role/BIReadOnly"]
     ```

3. **Deploy Dev**
   ```bash
   terraform -chdir=infra/env/dev init
   terraform -chdir=infra/env/dev plan
   terraform -chdir=infra/env/dev apply
   ```

4. **Validate**
   ```bash
   ./scripts/validate_env.sh dev
   go test ./tests/terratest/...
   ```

## CI/CD Pipeline

`.github/workflows/terraform-ci.yml` runs on PRs/pushes:

- `terraform fmt`, `terraform validate`, `tflint`
- `terraform plan` (per environment matrix) with plan artifacts uploaded
- Gated `terraform apply` on `main` after artifact reuse

Configure GitHub secrets:

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- `TF_STATE_BUCKET`, `TF_LOCK_TABLE`

## Testing & Drift Detection

- `tests/terratest/network_test.go` – Terratest scaffold ensuring configs init/validate cleanly.
- `scripts/validate_env.sh` – AWS CLI-based smoke tests (buckets, endpoints, Glue DBs).
- CloudWatch Event rule (in CloudTrail module) sends weekly SNS reminder to run `terraform plan -detailed-exitcode` for drift detection.

## Environments

- Dev wiring is provided; Stage/Prod folders reserve the structure and require different backend keys, CIDRs, and approval steps. Duplicate `infra/env/dev`, adjust `local.tags.Environment`, and update `backend.tf` keys.

## 📖 详细使用指南

查看 [USAGE_GUIDE.md](./USAGE_GUIDE.md) 获取完整的使用说明，包括：
- 如何运行测试
- 如何选择不同环境
- 环境选择的目的和最佳实践
- 日常操作指南
- 常见问题解答

