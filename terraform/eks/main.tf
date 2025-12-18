terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "cloudplatformterraformstate"
    key            = "eks/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "cloud-platform-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-cloud-platform"
      ManagedBy   = "Terraform"
      Component   = "eks"
      Owner       = "platform-engineering"
    }
  }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "cloudplatformterraformstate"
    key    = "networking/terraform.tfstate"
    region = var.aws_region
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "cloudplatformterraformstate"
    key    = "iam/terraform.tfstate"
    region = var.aws_region
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = data.terraform_remote_state.iam.outputs.eks_cluster_role_arn
  version  = var.kubernetes_version
  
  # Ensure cluster creation doesn't fail due to dependencies
  timeouts {
    create = "30m"
    update = "60m"
    delete = "15m"
  }

  vpc_config {
    subnet_ids              = concat(
      data.terraform_remote_state.networking.outputs.private_subnet_ids,
      data.terraform_remote_state.networking.outputs.public_subnet_ids
    )
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_access
    public_access_cidrs     = var.enable_public_access ? var.public_access_cidrs : []
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }

  depends_on = [
    data.terraform_remote_state.iam
  ]
}

# OIDC Provider for IRSA
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc-provider"
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = data.terraform_remote_state.iam.outputs.eks_node_group_role_arn
  subnet_ids      = data.terraform_remote_state.networking.outputs.private_subnet_ids
  version         = var.kubernetes_version
  
  # Error handling and timeouts
  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
  
  # Lifecycle management
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
    create_before_destroy = false
  }

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  labels = {
    role        = "general"
    environment = var.environment
  }

  tags = {
    Name                                                  = "${var.cluster_name}-node-group"
    Environment                                           = var.environment
    "k8s.io/cluster-autoscaler/${var.cluster_name}"       = "owned"
    "k8s.io/cluster-autoscaler/enabled"                   = "true"
  }

  depends_on = [
    aws_eks_cluster.main
  ]
}

# EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-vpc-cni"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "coredns"
  addon_version            = var.coredns_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-coredns"
  }

  depends_on = [
    aws_eks_node_group.main
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  addon_version            = var.kube_proxy_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-kube-proxy"
  }
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_version
  service_account_role_arn = data.terraform_remote_state.iam.outputs.ebs_csi_driver_role_arn
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-ebs-csi-driver"
  }
}

# Security Group for additional node-to-node communication
resource "aws_security_group_rule" "node_to_node" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}
