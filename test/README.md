# Terratest Suite

Automated testing for Terraform infrastructure using Terratest.

## Prerequisites

- Go 1.21+
- Terraform 1.5.0+
- AWS credentials configured

## Quick Start

```bash
cd test

# Initialize Go modules
make init

# Run fast validation tests (no AWS resources created)
make test-fast

# Run full integration tests (creates real AWS resources)
make test
```

## Test Structure

- `terraform_backend_test.go` - Tests S3 backend and DynamoDB locking
- `terraform_networking_test.go` - Tests VPC, subnets, NAT gateways
- `terraform_eks_test.go` - Tests EKS cluster configuration
- `helpers.go` - Shared test utilities

## Running Specific Tests

```bash
# Test backend module only
make test-backend

# Test networking module only
make test-networking

# Test EKS module only
make test-eks
```

## Local Testing

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_REGION=eu-west-1

# Run tests
cd test
go test -v -timeout 30m
```

## CI/CD Integration

Tests run automatically on:
- Push to main/develop branches
- Pull requests to main
- Changes to terraform/ or test/ directories

Fast validation tests run on all PRs.
Full integration tests run only on main branch pushes.

## Test Cleanup

Tests automatically clean up AWS resources using `defer terraform.Destroy()`.

If tests fail and resources remain:
```bash
cd terraform/[module]
terraform destroy
```

## Cost Considerations

Full integration tests create real AWS resources:
- VPC and networking components
- EKS cluster (most expensive)
- S3 buckets and DynamoDB tables

Estimated cost per full test run: $0.50 - $2.00 (depending on duration)

Use `make test-fast` for validation without creating resources.
