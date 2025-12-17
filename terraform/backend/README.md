# Terraform Backend Configuration

## Purpose

This module creates the foundational infrastructure for remote Terraform state management:
- S3 bucket for state storage with versioning and encryption
- DynamoDB table for state locking to prevent concurrent modifications

## Initial Setup

⚠️ **Bootstrap Process**: This module must be applied FIRST before any other infrastructure.

```bash
# 1. Initialize and apply with local state
cd terraform/backend
terraform init
terraform apply

# 2. Note the outputs (bucket name and table name)
terraform output

# 3. Migrate to remote state (optional)
# Add backend configuration to this directory and run:
# terraform init -migrate-state
```

## Configuration

Default values:
- Region: `eu-west-1`
- Bucket: `cloud-platform-terraform-state`
- Lock Table: `cloud-platform-terraform-locks`

Override using:
```bash
terraform apply -var="state_bucket_name=custom-name"
```

## Security Features

- Bucket versioning enabled for state recovery
- Server-side encryption (AES256)
- Public access blocked at bucket level
- DynamoDB point-in-time recovery enabled
- Lifecycle prevent_destroy on bucket

## Using This Backend

After applying this module, configure other modules to use the remote backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "cloud-platform-terraform-state"
    key            = "environment/service/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "cloud-platform-terraform-locks"
  }
}
```
