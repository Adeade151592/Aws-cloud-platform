# Backend Access Issue

## Problem
Terraform cannot access the S3 backend even though:
- ✅ Bucket exists: `cloudplatformterraformstate`
- ✅ User owns the bucket
- ✅ IAM policy grants S3 permissions
- ✅ KMS grant added for encryption key
- ✅ AWS CLI can access the bucket

## Error
```
Error: Error refreshing state: Unable to access object "environments/dev/terraform.tfstate" 
in S3 bucket "cloud-platform-terraform-state": operation error S3: HeadObject, 
https response error StatusCode: 403, api error Forbidden: Forbidden
```

## Workaround: Use Local Backend

Until this is resolved, use local backend:

### Option 1: Comment out backend in each module

In `terraform/environments/dev/main.tf`, `terraform/eks/main.tf`, etc:

```hcl
terraform {
  # backend "s3" {
  #   bucket         = "cloud-platform-terraform-state"
  #   key            = "environments/dev/terraform.tfstate"
  #   region         = "eu-west-1"
  #   encrypt        = true
  #   dynamodb_table = "cloud-platform-terraform-locks"
  # }
}
```

### Option 2: Use `-backend=false`

```bash
terraform init -backend=false
terraform plan
terraform apply
```

## Possible Causes

1. **IAM Policy Propagation Delay** - Wait 5-10 minutes
2. **SCP (Service Control Policy)** - Check organization policies
3. **Bucket Encryption** - KMS key policy might be restrictive
4. **Session Token** - Try refreshing AWS credentials

## Solution (When Ready)

Once backend access works:

```bash
# Initialize with backend
terraform init

# Migrate local state to S3
terraform init -migrate-state
```

## GitHub Actions

For GitHub Actions, ensure secrets are set:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

The GitHub Actions runner will have different permissions than your local user.
