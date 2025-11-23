# Terratest Infrastructure Tests

This directory contains comprehensive integration tests for the Claim Management System infrastructure using [Terratest](https://terratest.gruntwork.io/).

## Test Coverage

The test suite (`infrastructure_test.go`) performs the following checks:

### 1. Terraform Plan Check
- Validates that Terraform configuration is syntactically correct
- Checks for destructive changes in the plan output
- Warns if plan contains destroy operations or forced replacements

### 2. Terraform Apply
- Applies the infrastructure configuration
- Automatically cleans up resources after tests complete (via `defer terraform.Destroy`)

### 3. Output Verification
- Validates all Terraform outputs are present and correctly formatted:
  - VPC ID and CIDR block
  - Public and private subnet IDs
  - S3 bucket names and ARNs
  - KMS key ARNs and aliases
  - IAM role ARNs
  - Resource tags (Environment, Project, ManagedBy)

### 4. AWS Resource Validation
- **VPC**: Verifies CIDR block, DNS settings
- **Subnets**: Validates subnet count, public/private configuration
- **S3 Buckets**: Checks existence, versioning, and KMS encryption
- **KMS Keys**: Verifies keys exist, are enabled, and configured for encryption/decryption

### 5. Drift Detection
- Runs `terraform plan` after apply
- Verifies no changes are detected (infrastructure matches configuration)
- Fails if drift is detected

## Prerequisites

1. **Go 1.21+** installed
2. **Terraform >= 1.6.0** installed
3. **AWS Credentials** configured (via environment variables, AWS CLI, or IAM role)
4. **AWS Permissions**: The test requires permissions to create/read/delete:
   - VPC, Subnets, Security Groups
   - S3 Buckets
   - KMS Keys
   - IAM Roles
   - CloudTrail
   - Glue Databases

## Running Tests

### Run All Tests
```bash
cd tests/terratest
go test -v -timeout 30m
```

### Run Specific Test
```bash
go test -v -timeout 30m -run TestInfrastructure/PlanCheck
go test -v -timeout 30m -run TestInfrastructure/Apply
go test -v -timeout 30m -run TestInfrastructure/VerifyOutputs
go test -v -timeout 30m -run TestInfrastructure/VerifyAWSResources
go test -v -timeout 30m -run TestInfrastructure/CheckDrift
```

### Run with AWS Region Override
```bash
AWS_DEFAULT_REGION=us-west-2 go test -v -timeout 30m
```

## Test Configuration

Tests use the `infra/env/dev` configuration by default. To test a different environment:

1. Modify `terraformDir` in `infrastructure_test.go`
2. Ensure the target environment has valid Terraform configuration

## Backend Configuration

**Important**: Tests will use the backend configuration specified in `infra/env/dev/backend.tf`. 

For testing, you may want to:
- Use a local backend (comment out backend block temporarily)
- Use a separate test state bucket
- Ensure the backend bucket and DynamoDB table exist before running tests

## Test Timeout

Tests are configured with a 30-minute timeout to accommodate:
- Terraform init/plan/apply operations
- AWS resource creation (VPC, subnets, S3, KMS, etc.)
- Resource validation via AWS API calls
- Cleanup operations

## Expected Test Duration

- **PlanCheck**: ~30 seconds
- **Apply**: ~5-10 minutes (depends on AWS resource creation time)
- **VerifyOutputs**: ~1 second
- **VerifyAWSResources**: ~10-30 seconds
- **CheckDrift**: ~30 seconds
- **Destroy**: ~3-5 minutes

**Total**: Approximately 10-20 minutes

## Troubleshooting

### Test Fails with "Backend configuration not found"
- Ensure the S3 backend bucket exists
- Verify DynamoDB lock table exists
- Or temporarily use local backend for testing

### Test Fails with "Access Denied"
- Check AWS credentials are configured
- Verify IAM permissions include all required resource types
- Ensure you're using the correct AWS region

### Test Fails with "Resource already exists"
- Previous test run may not have cleaned up properly
- Manually destroy resources: `terraform destroy -chdir=infra/env/dev`
- Or wait for AWS resource deletion to complete

### Drift Detection Fails
- This indicates infrastructure has been modified outside of Terraform
- Review the plan output to identify changed resources
- Re-apply Terraform configuration to sync state

## CI/CD Integration

These tests are designed to run in CI/CD pipelines. Example GitHub Actions workflow:

```yaml
- name: Run Terratest
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: us-east-1
  run: |
    cd tests/terratest
    go test -v -timeout 30m
```

