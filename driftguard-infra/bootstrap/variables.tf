variable "aws_region" {
  description = "AWS region in which the shared state backend is created."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Required Environment tag for the bootstrap resources."
  type        = string
  default     = "bootstrap"
  validation {
    condition     = contains(["bootstrap", "dev", "staging", "prod"], var.environment)
    error_message = "environment must be bootstrap, dev, staging, or prod."
  }
}

variable "project" {
  description = "Project tag applied to the state backend resources."
  type        = string
  default     = "driftguard"
  validation {
    condition     = length(trimspace(var.project)) > 0
    error_message = "project must not be empty."
  }
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name."
  }
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  default     = "driftguard-terraform-locks"
  validation {
    condition     = length(trimspace(var.lock_table_name)) > 0
    error_message = "lock_table_name must not be empty."
  }
}
