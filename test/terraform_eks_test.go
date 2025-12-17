package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformEKS(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/eks",
		Vars: map[string]interface{}{
			"environment":              "test",
			"cluster_name":             "test-eks-cluster",
			"kubernetes_version":       "1.28",
			"enable_public_access":     false,
			"public_access_cidrs":      []string{},
			"node_group_desired_size":  2,
			"node_group_min_size":      1,
			"node_group_max_size":      4,
			"node_instance_types":      []string{"t3.medium"},
		},
		NoColor: true,
	})

	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
	planOutput := terraform.InitAndPlan(t, terraformOptions)

	assert.Contains(t, planOutput, "aws_eks_cluster.main")
	assert.Contains(t, planOutput, "aws_eks_node_group.main")
	assert.Contains(t, planOutput, "aws_iam_openid_connect_provider.cluster")
}

func TestEKSPublicAccessValidation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../terraform/eks",
		Vars: map[string]interface{}{
			"environment":          "test",
			"cluster_name":         "test-eks-cluster",
			"enable_public_access": true,
			"public_access_cidrs":  []string{},
		},
		NoColor: true,
	}

	_, err := terraform.InitE(t, terraformOptions)
	if err == nil {
		_, err = terraform.ValidateE(t, terraformOptions)
	}
	assert.Error(t, err, "Should fail when public access enabled without CIDRs")
}
