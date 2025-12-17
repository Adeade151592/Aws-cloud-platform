# Terraform validation rules for the entire project
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Validation for common variables across modules
locals {
  # Validate environment names
  valid_environments = ["dev", "staging", "prod"]
  
  # Validate AWS regions
  valid_regions = [
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "eu-west-1", "eu-west-2", "eu-central-1", "ap-southeast-1"
  ]
  
  # Common tags that should be applied to all resources
  common_tags = {
    Project     = "aws-cloud-platform"
    ManagedBy   = "Terraform"
    Environment = var.environment
    Owner       = "platform-engineering"
  }
}

# Data validation
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Validation checks
check "valid_aws_account" {
  assert {
    condition     = length(data.aws_caller_identity.current.account_id) == 12
    error_message = "AWS account ID must be exactly 12 digits."
  }
}

check "valid_region" {
  assert {
    condition     = contains(local.valid_regions, data.aws_region.current.name)
    error_message = "AWS region must be one of the approved regions."
  }
}