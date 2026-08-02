variable "zone_name" {
  description = "Public Route53 zone name, without a trailing dot."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$", var.zone_name))
    error_message = "zone_name must be a valid DNS name."
  }
}

variable "external_hostnames" {
  description = "Fully-qualified hostnames covered by the ACM certificate and optionally aliased to the ALB."
  type        = set(string)
  validation {
    condition     = length(var.external_hostnames) > 0 && alltrue([for hostname in var.external_hostnames : can(regex("^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$", hostname))])
    error_message = "external_hostnames must contain at least one valid hostname."
  }
}

variable "alb_dns_name" {
  description = "ALB DNS name. Leave null until the AWS Load Balancer Controller has created the ALB."
  type        = string
  default     = null
  nullable    = true
}

variable "alb_zone_id" {
  description = "Route53 hosted-zone ID for the ALB alias target. Required when alb_dns_name is set."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.alb_dns_name == null || (var.alb_zone_id != null && length(trimspace(var.alb_zone_id)) > 0)
    error_message = "alb_zone_id is required when alb_dns_name is set."
  }
}

variable "environment" {
  description = "Deployment environment used in required resource tags."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "project" {
  description = "Project identifier used in required resource tags."
  type        = string
  validation {
    condition     = length(trimspace(var.project)) > 0
    error_message = "project must not be empty."
  }
}

variable "managed_by" {
  description = "Value for the ManagedBy required tag."
  type        = string
  default     = "terraform"
  validation {
    condition     = length(trimspace(var.managed_by)) > 0
    error_message = "managed_by must not be empty."
  }
}
