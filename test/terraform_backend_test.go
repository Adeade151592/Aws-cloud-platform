package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformBackend(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/backend",
		Vars: map[string]interface{}{
			"state_bucket_name": "test-terraform-state-" + randomString(8),
			"lock_table_name":   "test-terraform-locks-" + randomString(8),
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndValidate(t, terraformOptions)
	terraform.Plan(t, terraformOptions)
}

func TestBackendBucketNaming(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name        string
		bucketName  string
		shouldError bool
	}{
		{"Valid bucket name", "valid-bucket-name-123", false},
		{"Too short", "ab", true},
		{"Invalid characters", "Invalid_Bucket", true},
		{"Starts with hyphen", "-invalid", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: "../terraform/backend",
				Vars: map[string]interface{}{
					"state_bucket_name": tt.bucketName,
				},
				NoColor: true,
			}

			_, err := terraform.InitAndValidateE(t, terraformOptions)
			if tt.shouldError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}
