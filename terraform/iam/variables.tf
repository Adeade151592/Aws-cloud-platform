variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.cluster_name)) && length(var.cluster_name) >= 1 && length(var.cluster_name) <= 100
    error_message = "Cluster name must be 1-100 characters and contain only letters, numbers, and hyphens."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/", var.oidc_provider_arn))
    error_message = "OIDC provider ARN must be a valid AWS IAM OIDC provider ARN."
  }
}

variable "oidc_provider" {
  description = "OIDC provider URL without https://"
  type        = string
  validation {
    condition     = can(regex("^oidc\\.eks\\.[a-z0-9-]+\\.amazonaws\\.com/id/[A-Z0-9]+$", var.oidc_provider))
    error_message = "OIDC provider must be a valid EKS OIDC provider URL without https://."
  }
}
