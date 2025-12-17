terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cloud-platform-terraform-state"
    key            = "environments/staging/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "cloud-platform-terraform-locks"
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "aws-cloud-platform"
      Environment = "staging"
      ManagedBy   = "Terraform"
      Owner       = "platform-engineering"
    }
  }
}

# Networking Module
module "networking" {
  source = "../../networking"

  aws_region   = "eu-west-1"
  environment  = "staging"
  vpc_cidr     = "10.1.0.0/16"
  az_count     = 3
  cluster_name = "staging-eks-cluster"
}

# IAM Module
module "iam" {
  source = "../../iam"

  aws_region        = "eu-west-1"
  cluster_name      = "staging-eks-cluster"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
}

# EKS Module
module "eks" {
  source = "../../eks"

  aws_region               = "eu-west-1"
  environment              = "staging"
  cluster_name             = "staging-eks-cluster"
  kubernetes_version       = "1.28"
  enable_public_access     = false  # Disable public access for security
  public_access_cidrs      = []     # No public access
  node_group_desired_size  = 3
  node_group_min_size      = 2
  node_group_max_size      = 6
  node_instance_types      = ["t3.large"]

  depends_on = [module.networking, module.iam]
}
