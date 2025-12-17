variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "cloudplatformterraformstate"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.state_bucket_name)) && length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "Bucket name must be 3-63 characters, start and end with lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "cloud-platform-terraform-locks"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.\\-]+$", var.lock_table_name)) && length(var.lock_table_name) >= 3 && length(var.lock_table_name) <= 255
    error_message = "Table name must be 3-255 characters and contain only letters, numbers, underscores, periods, and hyphens."
  }
}
