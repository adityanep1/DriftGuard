variable "environment" {
  description = "Environment used in tags and role names."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "project" {
  description = "Project identifier used in required tags."
  type        = string
  default     = "driftguard"
}

variable "github_repository" {
  description = "GitHub owner/repository, for example your-org/driftguard-infra."
  type        = string
  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be OWNER/REPOSITORY."
  }
}

variable "branch" {
  description = "Branch allowed to assume the CI roles."
  type        = string
  default     = "main"
}
