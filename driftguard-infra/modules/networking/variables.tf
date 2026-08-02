variable "environment" {
  description = "Deployment environment; prod receives one NAT gateway per AZ."
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

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the environment VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zones" {
  description = "At least two AZ names. Empty selects the first two available AZs in the provider region."
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) >= 2
    error_message = "availability_zones must be empty or contain at least two AZs."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per selected AZ."
  type        = list(string)
  default     = ["10.40.0.0/20", "10.40.16.0/20"]
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "at least two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per selected AZ."
  type        = list(string)
  default     = ["10.40.128.0/20", "10.40.144.0/20"]
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "at least two private subnet CIDRs are required."
  }
}

variable "cluster_name" {
  description = "EKS cluster name used for subnet discovery tags."
  type        = string
  default     = "driftguard"
}

variable "nat_per_az" {
  description = "Create one NAT gateway per selected AZ; prod always uses one per AZ regardless of this flag."
  type        = bool
  default     = false
}
