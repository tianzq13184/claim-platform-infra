package terratest

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestInfrastructure(t *testing.T) {
	// Test configuration
	terraformDir := filepath.Join("..", "..", "infra", "env", "dev")
	region := "us-east-1"

	tfOptions := &terraform.Options{
		TerraformDir: terraformDir,
		NoColor:      true,
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
	}

	// Cleanup resources after all tests complete
	defer terraform.Destroy(t, tfOptions)

	// Step 1: Terraform Init and Plan (check for destructive changes)
	t.Run("PlanCheck", func(t *testing.T) {
		terraform.Init(t, tfOptions)

		// Run plan to check for destructive changes
		planString := terraform.RunTerraformCommand(t, tfOptions, terraform.FormatArgs(tfOptions, "plan")...)

		// Check for destroy operations in plan output
		if strings.Contains(planString, "destroy") || strings.Contains(planString, "forces replacement") {
			t.Logf("Warning: Plan contains destructive changes:\n%s", planString)
		}

		// Verify plan output is not empty
		assert.NotEmpty(t, planString, "Plan output should not be empty")
	})

	// Step 2: Terraform Apply
	t.Run("Apply", func(t *testing.T) {
		terraform.InitAndApply(t, tfOptions)
	})

	// Step 3: Verify Outputs
	t.Run("VerifyOutputs", func(t *testing.T) {

		// Get outputs
		vpcID := terraform.Output(t, tfOptions, "vpc_id")
		vpcCIDR := terraform.Output(t, tfOptions, "vpc_cidr")
		publicSubnetIDs := terraform.OutputList(t, tfOptions, "public_subnet_ids")
		privateSubnetIDs := terraform.OutputList(t, tfOptions, "private_subnet_ids")
		s3BucketNames := terraform.OutputMap(t, tfOptions, "s3_bucket_names")
		kmsKeyARNs := terraform.OutputMap(t, tfOptions, "kms_key_arns")
		iamRoleARNs := terraform.OutputMap(t, tfOptions, "iam_role_arns")
		tags := terraform.OutputMap(t, tfOptions, "tags")

		// Verify VPC outputs
		require.NotEmpty(t, vpcID, "VPC ID should not be empty")
		assert.True(t, strings.HasPrefix(vpcID, "vpc-"), "VPC ID should start with 'vpc-'")

		require.NotEmpty(t, vpcCIDR, "VPC CIDR should not be empty")
		assert.Equal(t, "10.10.0.0/16", vpcCIDR, "VPC CIDR should match expected value")

		// Verify subnet outputs
		require.Len(t, publicSubnetIDs, 2, "Should have 2 public subnets")
		require.Len(t, privateSubnetIDs, 2, "Should have 2 private subnets")

		for _, subnetID := range append(publicSubnetIDs, privateSubnetIDs...) {
			assert.True(t, strings.HasPrefix(subnetID, "subnet-"), "Subnet ID should start with 'subnet-'")
		}

		// Verify S3 bucket names
		require.Contains(t, s3BucketNames, "raw", "Should have raw bucket")
		require.Contains(t, s3BucketNames, "lake", "Should have lake bucket")
		require.Contains(t, s3BucketNames, "audit", "Should have audit bucket")

		for bucketType, bucketName := range s3BucketNames {
			assert.True(t, strings.HasPrefix(bucketName, "claim-dev-"),
				fmt.Sprintf("%s bucket should start with 'claim-dev-'", bucketType))
		}

		// Verify KMS keys
		require.Contains(t, kmsKeyARNs, "raw", "Should have raw KMS key")
		require.Contains(t, kmsKeyARNs, "lake", "Should have lake KMS key")
		require.Contains(t, kmsKeyARNs, "audit", "Should have audit KMS key")

		for keyType, keyARN := range kmsKeyARNs {
			assert.True(t, strings.HasPrefix(keyARN, "arn:aws:kms:"),
				fmt.Sprintf("%s KMS key should be a valid ARN", keyType))
		}

		// Verify IAM roles
		require.Contains(t, iamRoleARNs, "ingestion", "Should have ingestion role")
		require.Contains(t, iamRoleARNs, "etl", "Should have ETL role")
		require.Contains(t, iamRoleARNs, "analyst", "Should have analyst role")

		for roleType, roleARN := range iamRoleARNs {
			assert.True(t, strings.HasPrefix(roleARN, "arn:aws:iam:"),
				fmt.Sprintf("%s role should be a valid ARN", roleType))
		}

		// Verify tags
		require.Contains(t, tags, "Environment", "Should have Environment tag")
		require.Contains(t, tags, "Project", "Should have Project tag")
		require.Contains(t, tags, "ManagedBy", "Should have ManagedBy tag")
		assert.Equal(t, "dev", tags["Environment"], "Environment tag should be 'dev'")
		assert.Equal(t, "claim-management-system", tags["Project"], "Project tag should match")
		assert.Equal(t, "terraform", tags["ManagedBy"], "ManagedBy tag should be 'terraform'")
	})

	// Step 4: Verify AWS Resources
	t.Run("VerifyAWSResources", func(t *testing.T) {

		// Create AWS session
		sess, err := session.NewSession(&aws.Config{
			Region: aws.String(region),
		})
		require.NoError(t, err)

		// Get outputs
		vpcID := terraform.Output(t, tfOptions, "vpc_id")
		publicSubnetIDs := terraform.OutputList(t, tfOptions, "public_subnet_ids")
		privateSubnetIDs := terraform.OutputList(t, tfOptions, "private_subnet_ids")
		s3BucketNames := terraform.OutputMap(t, tfOptions, "s3_bucket_names")
		kmsKeyARNs := terraform.OutputMap(t, tfOptions, "kms_key_arns")

		// Verify VPC
		ec2Svc := ec2.New(sess)
		vpcOutput, err := ec2Svc.DescribeVpcs(&ec2.DescribeVpcsInput{
			VpcIds: []*string{aws.String(vpcID)},
		})
		require.NoError(t, err)
		require.Len(t, vpcOutput.Vpcs, 1, "VPC should exist")

		vpc := vpcOutput.Vpcs[0]
		assert.Equal(t, "10.10.0.0/16", *vpc.CidrBlock, "VPC CIDR should match")

		// Verify DNS hostnames attribute
		dnsHostnamesOutput, err := ec2Svc.DescribeVpcAttribute(&ec2.DescribeVpcAttributeInput{
			VpcId:     aws.String(vpcID),
			Attribute: aws.String("enableDnsHostnames"),
		})
		require.NoError(t, err)
		assert.True(t, *dnsHostnamesOutput.EnableDnsHostnames.Value, "VPC should have DNS hostnames enabled")

		// Verify DNS support attribute
		dnsSupportOutput, err := ec2Svc.DescribeVpcAttribute(&ec2.DescribeVpcAttributeInput{
			VpcId:     aws.String(vpcID),
			Attribute: aws.String("enableDnsSupport"),
		})
		require.NoError(t, err)
		assert.True(t, *dnsSupportOutput.EnableDnsSupport.Value, "VPC should have DNS support enabled")

		// Verify Subnets
		allSubnetIDs := append(publicSubnetIDs, privateSubnetIDs...)
		subnetOutput, err := ec2Svc.DescribeSubnets(&ec2.DescribeSubnetsInput{
			SubnetIds: aws.StringSlice(allSubnetIDs),
		})
		require.NoError(t, err)
		require.Len(t, subnetOutput.Subnets, 4, "Should have 4 subnets total")

		// Verify public subnets
		publicSubnetMap := make(map[string]bool)
		for _, id := range publicSubnetIDs {
			publicSubnetMap[id] = true
		}

		for _, subnet := range subnetOutput.Subnets {
			if publicSubnetMap[*subnet.SubnetId] {
				assert.True(t, *subnet.MapPublicIpOnLaunch,
					fmt.Sprintf("Subnet %s should be public", *subnet.SubnetId))
			}
		}

		// Verify S3 Buckets
		s3Svc := s3.New(sess)
		for bucketType, bucketName := range s3BucketNames {
			// Check bucket exists
			_, err := s3Svc.HeadBucket(&s3.HeadBucketInput{
				Bucket: aws.String(bucketName),
			})
			assert.NoError(t, err, fmt.Sprintf("%s bucket should exist", bucketType))

			// Check versioning
			versioningOutput, err := s3Svc.GetBucketVersioning(&s3.GetBucketVersioningInput{
				Bucket: aws.String(bucketName),
			})
			require.NoError(t, err)
			require.NotNil(t, versioningOutput.Status,
				fmt.Sprintf("%s bucket should have versioning status", bucketType))
			assert.Equal(t, "Enabled", *versioningOutput.Status,
				fmt.Sprintf("%s bucket should have versioning enabled", bucketType))

			// Check encryption
			encryptionOutput, err := s3Svc.GetBucketEncryption(&s3.GetBucketEncryptionInput{
				Bucket: aws.String(bucketName),
			})
			require.NoError(t, err)
			require.NotNil(t, encryptionOutput.ServerSideEncryptionConfiguration,
				fmt.Sprintf("%s bucket should have encryption configured", bucketType))
			require.Len(t, encryptionOutput.ServerSideEncryptionConfiguration.Rules, 1,
				fmt.Sprintf("%s bucket should have encryption rule", bucketType))

			encryptionRule := encryptionOutput.ServerSideEncryptionConfiguration.Rules[0]
			require.NotNil(t, encryptionRule.ApplyServerSideEncryptionByDefault,
				fmt.Sprintf("%s bucket should have default encryption", bucketType))
			assert.Equal(t, "aws:kms",
				*encryptionRule.ApplyServerSideEncryptionByDefault.SSEAlgorithm,
				fmt.Sprintf("%s bucket should use KMS encryption", bucketType))
		}

		// Verify KMS Keys
		kmsSvc := kms.New(sess)
		for keyType, keyARN := range kmsKeyARNs {
			// Use ARN directly for DescribeKey
			keyOutput, err := kmsSvc.DescribeKey(&kms.DescribeKeyInput{
				KeyId: aws.String(keyARN),
			})
			require.NoError(t, err, fmt.Sprintf("%s KMS key should exist", keyType))

			key := keyOutput.KeyMetadata
			assert.True(t, *key.Enabled, fmt.Sprintf("%s KMS key should be enabled", keyType))
			assert.Equal(t, "ENCRYPT_DECRYPT", *key.KeyUsage,
				fmt.Sprintf("%s KMS key should be for encryption/decryption", keyType))
		}
	})

	// Step 5: Check for Drift
	t.Run("CheckDrift", func(t *testing.T) {

		// Run terraform plan - after apply, should show no changes
		planOutput := terraform.RunTerraformCommand(t, tfOptions,
			terraform.FormatArgs(tfOptions, "plan")...)

		// After apply, plan should show "No changes"
		// Check for drift indicators
		if strings.Contains(planOutput, "No changes") ||
			strings.Contains(planOutput, "Your infrastructure matches the configuration") {
			t.Log("✓ No drift detected - infrastructure matches configuration")
		} else if strings.Contains(planOutput, "will be created") ||
			strings.Contains(planOutput, "will be updated") ||
			strings.Contains(planOutput, "will be destroyed") {
			t.Errorf("Drift detected! Plan shows changes after apply:\n%s", planOutput)
		} else {
			// Plan output doesn't clearly indicate changes, log for review
			t.Logf("Plan output (review for drift):\n%s", planOutput)
		}
	})

	// Cleanup is handled by defer at the top of TestInfrastructure function
}
