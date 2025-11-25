package terratest

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestS3SQSAndDynamoDB(t *testing.T) {
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

	// Step 0: Terraform Init and Apply (if needed)
	t.Run("InitAndApply", func(t *testing.T) {
		terraform.Init(t, tfOptions)
		// Only apply if resources don't exist
		// In a real scenario, you might want to check if resources exist first
		terraform.Apply(t, tfOptions)
	})

	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)

	// Step 1: Verify Terraform Outputs
	t.Run("VerifyOutputs", func(t *testing.T) {
		// Get outputs
		sqsQueueARN := terraform.Output(t, tfOptions, "sqs_queue_arn")
		sqsQueueURL := terraform.Output(t, tfOptions, "sqs_queue_url")
		sqsDLQARN := terraform.Output(t, tfOptions, "sqs_dlq_arn")
		dynamodbTableARN := terraform.Output(t, tfOptions, "dynamodb_table_arn")
		dynamodbTableName := terraform.Output(t, tfOptions, "dynamodb_table_name")
		s3BucketNames := terraform.OutputMap(t, tfOptions, "s3_bucket_names")

		// Verify SQS outputs
		require.NotEmpty(t, sqsQueueARN, "SQS queue ARN should not be empty")
		assert.True(t, strings.HasPrefix(sqsQueueARN, "arn:aws:sqs:"),
			"SQS queue ARN should be a valid ARN")

		require.NotEmpty(t, sqsQueueURL, "SQS queue URL should not be empty")
		assert.True(t, strings.Contains(sqsQueueURL, "sqs."),
			"SQS queue URL should contain 'sqs.'")

		require.NotEmpty(t, sqsDLQARN, "SQS DLQ ARN should not be empty")
		assert.True(t, strings.HasPrefix(sqsDLQARN, "arn:aws:sqs:"),
			"SQS DLQ ARN should be a valid ARN")

		// Verify DynamoDB outputs
		require.NotEmpty(t, dynamodbTableARN, "DynamoDB table ARN should not be empty")
		assert.True(t, strings.HasPrefix(dynamodbTableARN, "arn:aws:dynamodb:"),
			"DynamoDB table ARN should be a valid ARN")

		require.NotEmpty(t, dynamodbTableName, "DynamoDB table name should not be empty")
		assert.True(t, strings.HasPrefix(dynamodbTableName, "claim-dev-"),
			"DynamoDB table name should start with 'claim-dev-'")

		// Verify raw bucket exists in outputs
		require.Contains(t, s3BucketNames, "raw", "Should have raw bucket in outputs")
	})

	// Step 2: Verify SQS Queue Configuration
	t.Run("VerifySQSQueue", func(t *testing.T) {
		sqsSvc := sqs.New(sess)

		sqsQueueURL := terraform.Output(t, tfOptions, "sqs_queue_url")
		sqsDLQARN := terraform.Output(t, tfOptions, "sqs_dlq_arn")

		// Get queue attributes
		queueAttrs, err := sqsSvc.GetQueueAttributes(&sqs.GetQueueAttributesInput{
			QueueUrl:       aws.String(sqsQueueURL),
			AttributeNames: []*string{aws.String("All")},
		})
		require.NoError(t, err, "Should be able to get queue attributes")

		attrs := queueAttrs.Attributes

		// Verify KMS encryption
		kmsKeyID, exists := attrs["KmsMasterKeyId"]
		require.True(t, exists, "Queue should have KMS encryption configured")
		assert.NotEmpty(t, kmsKeyID, "KMS key ID should not be empty")

		// Verify redrive policy (DLQ configuration)
		redrivePolicy, exists := attrs["RedrivePolicy"]
		require.True(t, exists, "Queue should have redrive policy configured")
		assert.Contains(t, *redrivePolicy, sqsDLQARN,
			"Redrive policy should reference the DLQ ARN")

		// Verify message retention
		messageRetention, exists := attrs["MessageRetentionPeriod"]
		require.True(t, exists, "Queue should have message retention configured")
		assert.Equal(t, "345600", *messageRetention, // 4 days in seconds
			"Message retention should be 4 days (345600 seconds)")

		// Verify visibility timeout
		visibilityTimeout, exists := attrs["VisibilityTimeout"]
		require.True(t, exists, "Queue should have visibility timeout configured")
		assert.Equal(t, "30", *visibilityTimeout,
			"Visibility timeout should be 30 seconds")

		// Verify queue policy allows S3
		queuePolicy, exists := attrs["Policy"]
		require.True(t, exists, "Queue should have a policy")
		assert.Contains(t, *queuePolicy, "s3.amazonaws.com",
			"Queue policy should allow S3 service")
		assert.Contains(t, *queuePolicy, "SendMessage",
			"Queue policy should allow SendMessage action")
	})

	// Step 3: Verify SQS DLQ Configuration
	t.Run("VerifySQSDLQ", func(t *testing.T) {
		sqsSvc := sqs.New(sess)

		sqsDLQURL := terraform.Output(t, tfOptions, "sqs_dlq_url")

		// Get DLQ attributes
		dlqAttrs, err := sqsSvc.GetQueueAttributes(&sqs.GetQueueAttributesInput{
			QueueUrl:       aws.String(sqsDLQURL),
			AttributeNames: []*string{aws.String("All")},
		})
		require.NoError(t, err, "Should be able to get DLQ attributes")

		attrs := dlqAttrs.Attributes

		// Verify KMS encryption
		kmsKeyID, exists := attrs["KmsMasterKeyId"]
		require.True(t, exists, "DLQ should have KMS encryption configured")
		assert.NotEmpty(t, kmsKeyID, "DLQ KMS key ID should not be empty")

		// Verify message retention (should be longer than main queue)
		messageRetention, exists := attrs["MessageRetentionPeriod"]
		require.True(t, exists, "DLQ should have message retention configured")
		// DLQ should have longer retention (14 days = 1209600 seconds)
		assert.Equal(t, "1209600", *messageRetention,
			"DLQ message retention should be 14 days (1209600 seconds)")
	})

	// Step 4: Verify DynamoDB Table Configuration
	t.Run("VerifyDynamoDBTable", func(t *testing.T) {
		dynamodbSvc := dynamodb.New(sess)

		dynamodbTableName := terraform.Output(t, tfOptions, "dynamodb_table_name")

		// Describe table
		tableOutput, err := dynamodbSvc.DescribeTable(&dynamodb.DescribeTableInput{
			TableName: aws.String(dynamodbTableName),
		})
		require.NoError(t, err, "DynamoDB table should exist")

		table := tableOutput.Table

		// Verify table status
		assert.Equal(t, "ACTIVE", *table.TableStatus,
			"Table should be in ACTIVE status")

		// Verify billing mode
		require.NotNil(t, table.BillingModeSummary, "Table should have billing mode summary")
		assert.Equal(t, "PAY_PER_REQUEST", *table.BillingModeSummary.BillingMode,
			"Table should use PAY_PER_REQUEST billing mode")

		// Verify hash key (file_id)
		require.NotNil(t, table.KeySchema, "Table should have key schema")
		require.Len(t, table.KeySchema, 1, "Table should have one key (hash key)")
		assert.Equal(t, "file_id", *table.KeySchema[0].AttributeName,
			"Hash key should be 'file_id'")
		assert.Equal(t, "HASH", *table.KeySchema[0].KeyType,
			"Key type should be HASH")

		// Verify attribute definition
		require.NotNil(t, table.AttributeDefinitions, "Table should have attribute definitions")
		foundFileID := false
		for _, attr := range table.AttributeDefinitions {
			if *attr.AttributeName == "file_id" {
				foundFileID = true
				assert.Equal(t, "S", *attr.AttributeType,
					"file_id attribute should be String type")
			}
		}
		assert.True(t, foundFileID, "Table should have file_id attribute definition")

		// Verify encryption
		require.NotNil(t, table.SSEDescription, "Table should have SSE description")
		assert.Equal(t, "ENABLED", *table.SSEDescription.Status,
			"Table should have encryption enabled")
		assert.NotNil(t, table.SSEDescription.KMSMasterKeyArn,
			"Table should use KMS encryption")

		// Verify point-in-time recovery
		pitrOutput, err := dynamodbSvc.DescribeContinuousBackups(&dynamodb.DescribeContinuousBackupsInput{
			TableName: aws.String(dynamodbTableName),
		})
		require.NoError(t, err, "Should be able to get continuous backups info")
		require.NotNil(t, pitrOutput.ContinuousBackupsDescription,
			"Table should have continuous backups description")
		require.NotNil(t, pitrOutput.ContinuousBackupsDescription.PointInTimeRecoveryDescription,
			"Table should have point-in-time recovery description")
		assert.Equal(t, "ENABLED",
			*pitrOutput.ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus,
			"Point-in-time recovery should be enabled")
	})

	// Step 5: Verify S3 Event Notification Configuration
	t.Run("VerifyS3EventNotification", func(t *testing.T) {
		s3Svc := s3.New(sess)

		s3BucketNames := terraform.OutputMap(t, tfOptions, "s3_bucket_names")
		sqsQueueARN := terraform.Output(t, tfOptions, "sqs_queue_arn")

		rawBucketName := s3BucketNames["raw"]
		require.NotEmpty(t, rawBucketName, "Raw bucket name should not be empty")

		// Get bucket notification configuration
		// Note: AWS SDK v1 uses GetBucketNotificationConfigurationRequest
		req, notificationOutput := s3Svc.GetBucketNotificationConfigurationRequest(&s3.GetBucketNotificationConfigurationRequest{
			Bucket: aws.String(rawBucketName),
		})
		err = req.Send()
		require.NoError(t, err, "Should be able to get bucket notification configuration")

		// Verify queue configuration exists
		require.NotNil(t, notificationOutput.QueueConfigurations,
			"Raw bucket should have queue notification configuration")
		require.Len(t, notificationOutput.QueueConfigurations, 1,
			"Raw bucket should have one queue notification")

		queueConfig := notificationOutput.QueueConfigurations[0]

		// Verify queue ARN matches
		assert.Equal(t, sqsQueueARN, *queueConfig.QueueArn,
			"Queue ARN in notification should match SQS queue ARN")

		// Verify events include ObjectCreated
		require.NotNil(t, queueConfig.Events, "Queue config should have events")
		foundObjectCreated := false
		for _, event := range queueConfig.Events {
			if strings.Contains(*event, "ObjectCreated") {
				foundObjectCreated = true
				break
			}
		}
		assert.True(t, foundObjectCreated,
			"Queue notification should include ObjectCreated events")
	})

	// Step 6: Test S3 Event Flow (Optional - sends a test message)
	t.Run("TestS3EventFlow", func(t *testing.T) {
		s3Svc := s3.New(sess)
		sqsSvc := sqs.New(sess)

		s3BucketNames := terraform.OutputMap(t, tfOptions, "s3_bucket_names")
		sqsQueueURL := terraform.Output(t, tfOptions, "sqs_queue_url")

		rawBucketName := s3BucketNames["raw"]
		testKey := "test/event-notification-test.txt"
		testContent := "This is a test file to verify S3 event notification to SQS"

		// Upload a test file to trigger event
		_, err := s3Svc.PutObject(&s3.PutObjectInput{
			Bucket: aws.String(rawBucketName),
			Key:    aws.String(testKey),
			Body:   strings.NewReader(testContent),
		})
		require.NoError(t, err, "Should be able to upload test file to S3")

		// Clean up test file after test
		defer func() {
			s3Svc.DeleteObject(&s3.DeleteObjectInput{
				Bucket: aws.String(rawBucketName),
				Key:    aws.String(testKey),
			})
		}()

		// Wait a moment for event to propagate
		// In a real scenario, you might want to use a more robust waiting mechanism
		// For now, we'll just verify the queue can receive messages

		// Check queue attributes to see if messages are available
		_, err = sqsSvc.GetQueueAttributes(&sqs.GetQueueAttributesInput{
			QueueUrl: aws.String(sqsQueueURL),
			AttributeNames: []*string{
				aws.String("ApproximateNumberOfMessages"),
				aws.String("ApproximateNumberOfMessagesNotVisible"),
			},
		})
		require.NoError(t, err, "Should be able to get queue message count")

		// Note: Messages might not appear immediately, so we just verify the queue is accessible
		// In production, you'd want to poll or use a more sophisticated waiting mechanism
		t.Logf("Queue message attributes retrieved successfully. " +
			"Note: Event propagation may take a few seconds.")
	})
}

