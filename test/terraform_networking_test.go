package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformNetworking(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/networking",
		Vars: map[string]interface{}{
			"environment":  "test",
			"vpc_cidr":     "10.99.0.0/16",
			"az_count":     3,
			"cluster_name": "test-eks-cluster",
		},
		BackendConfig: map[string]interface{}{
			"path": "test-terraform.tfstate",
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
	planOutput := terraform.InitAndPlan(t, terraformOptions)

	assert.Contains(t, planOutput, "aws_vpc.main")
	assert.Contains(t, planOutput, "aws_subnet.private")
	assert.Contains(t, planOutput, "aws_subnet.public")
	assert.Contains(t, planOutput, "aws_nat_gateway.main")
}

func TestNetworkingAZCount(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name        string
		azCount     int
		shouldError bool
	}{
		{"Valid 2 AZs", 2, false},
		{"Valid 3 AZs", 3, false},
		{"Invalid 1 AZ", 1, true},
		{"Invalid 7 AZs", 7, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: "../terraform/networking",
				Vars: map[string]interface{}{
					"environment":  "test",
					"vpc_cidr":     "10.99.0.0/16",
					"az_count":     tt.azCount,
					"cluster_name": "test-eks-cluster",
				},
				NoColor: true,
			}

			_, err := terraform.InitE(t, terraformOptions)
			if err == nil {
				_, err = terraform.ValidateE(t, terraformOptions)
			}
			if tt.shouldError {
				assert.Error(t, err)
			}
		})
	}
}
