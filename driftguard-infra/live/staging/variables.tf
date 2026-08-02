variable "availability_zones" {
  description = "Two AZs for the staging public/private subnet pairs."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for staging public subnets."
  type        = list(string)
  default     = ["10.50.0.0/20", "10.50.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for staging private EKS node subnets."
  type        = list(string)
  default     = ["10.50.128.0/20", "10.50.144.0/20"]
}

variable "nat_per_az" {
  description = "Use one NAT gateway per AZ in this environment."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "Explicit EKS Kubernetes minor version."
  type        = string
  default     = "1.30"
}

variable "public_access_cidrs" {
  description = "Restricted CIDR allowlist for the EKS public API endpoint."
  type        = list(string)
  default     = ["203.0.113.0/24"]
}

variable "max_node_count" {
  description = "Maximum worker nodes permitted in the environment."
  type        = number
  default     = 20
  validation {
    condition     = floor(var.max_node_count) == var.max_node_count && var.max_node_count >= 1 && var.max_node_count <= 1000
    error_message = "max_node_count must be a whole number between 1 and 1000."
  }
}

variable "node_groups" {
  description = "Managed node-group sizing for this environment."
  type = map(object({
    min_size       = number
    max_size       = number
    desired_size   = number
    instance_types = set(string)
    disk_size      = optional(number, 50)
    capacity_type  = optional(string, "ON_DEMAND")
    labels         = optional(map(string), {})
  }))
  default = {
    default = {
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      instance_types = ["t3.medium"]
    }
  }
}

variable "ecr_services" {
  description = "Deployable services with private ECR repositories."
  type        = set(string)
  default     = ["demo-service"]
}

variable "enable_dns" {
  description = "Create the public Route53 zone and ACM certificate for this environment."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Public DNS zone used when enable_dns is true."
  type        = string
  default     = "example.invalid"
}

variable "external_hostnames" {
  description = "External hostnames covered by the environment certificate."
  type        = set(string)
  default     = ["demo.example.invalid"]
}

variable "github_repository" {
  description = "GitHub owner/repository for OIDC federation, e.g. your-org/driftguard-infra."
  type        = string
  default     = "your-org/driftguard-infra"
  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be OWNER/REPOSITORY."
  }
}
