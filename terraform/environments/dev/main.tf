terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cloudplatformterraformstate"
    key            = "environments/dev/terraform.tfstate"
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
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "platform-engineering"
    }
  }
}

# Networking Module
module "networking" {
  source = "../../networking"

  aws_region   = "eu-west-1"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 3
  cluster_name = "dev-eks-cluster"
}

# IAM Module
module "iam" {
  source = "../../iam"

  aws_region        = "eu-west-1"
  cluster_name      = "dev-eks-cluster"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
}

# EKS Module
module "eks" {
  source = "../../eks"

  aws_region               = "eu-west-1"
  environment              = "dev"
  cluster_name             = "dev-eks-cluster"
  kubernetes_version       = "1.29"
  enable_public_access     = true   # Enable for GitHub Actions
  public_access_cidrs      = ["0.0.0.0/0"]  # GitHub Actions IPs - restrict in production
  node_group_desired_size  = 2
  node_group_min_size      = 1
  node_group_max_size      = 4
  node_instance_types      = ["t3.medium"]

  # Networking outputs
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  # IAM outputs
  eks_cluster_role_arn     = module.iam.eks_cluster_role_arn
  eks_node_group_role_arn  = module.iam.eks_node_group_role_arn
  ebs_csi_driver_role_arn  = module.iam.ebs_csi_driver_role_arn
}
