variable "name_prefix" {
  description = "Environment-specific prefix used to make repository names unique."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]{0,40}[a-z0-9]$|^[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be a valid ECR repository prefix of at most 42 characters."
  }
}

variable "environment" {
  description = "Deployment environment used in required repository tags."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "project" {
  description = "Project identifier used in required repository tags."
  type        = string
  validation {
    condition     = length(trimspace(var.project)) > 0
    error_message = "project must not be empty."
  }
}

variable "managed_by" {
  description = "Value for the ManagedBy required repository tag."
  type        = string
  default     = "terraform"
  validation {
    condition     = length(trimspace(var.managed_by)) > 0
    error_message = "managed_by must not be empty."
  }
}

variable "services" {
  description = "Deployable service names; exactly one private ECR repository is created per service."
  type        = set(string)
  validation {
    condition = length(var.services) > 0 && alltrue([
      for service in var.services : can(regex("^[a-z0-9][a-z0-9._/-]*[a-z0-9]$|^[a-z0-9]$", service)) && length(service) <= 200
    ])
    error_message = "services must be non-empty valid ECR names of at most 200 characters."
  }
}

variable "untagged_image_retention_days" {
  description = "Age in days after which untagged images are expired; defaults to 14 days."
  type        = number
  default     = 14
  validation {
    condition     = var.untagged_image_retention_days >= 1 && var.untagged_image_retention_days <= 3650 && floor(var.untagged_image_retention_days) == var.untagged_image_retention_days
    error_message = "untagged_image_retention_days must be a whole number between 1 and 3650."
  }
}

variable "encryption_type" {
  description = "ECR encryption at rest mode; AES256 is the secure default and KMS is supported for customer-managed keys."
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN used when encryption_type is KMS."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.encryption_type != "KMS" || (var.kms_key_arn != null && can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn)))
    error_message = "kms_key_arn must be a KMS key ARN when encryption_type is KMS."
  }
}
