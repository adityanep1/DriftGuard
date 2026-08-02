variable "name" {
  description = "Stable EKS cluster name and resource name prefix."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,99}$", var.name))
    error_message = "name must be 1-100 characters and contain only letters, numbers, and hyphens."
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

variable "kubernetes_version" {
  description = "Explicit Kubernetes minor version, for example 1.30; floating aliases are not accepted."
  type        = string
  default     = "1.30"
  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version)) && var.kubernetes_version != "latest"
    error_message = "kubernetes_version must be an explicit Kubernetes minor in the form 1.XX, not latest."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS control plane and managed node groups."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2 && alltrue([for id in var.private_subnet_ids : length(trimspace(id)) > 0])
    error_message = "at least two non-empty private_subnet_ids are required."
  }
}

variable "public_access_cidrs" {
  description = "CIDR allowlist for the public EKS API endpoint; unrestricted IPv4/IPv6 ranges are forbidden."
  type        = list(string)
  validation {
    condition = length(var.public_access_cidrs) > 0 && alltrue([
      for cidr in var.public_access_cidrs : can(cidrhost(trimspace(cidr), 0)) && !(
        can(regex("/0+$", trimspace(cidr))) && contains(["0.0.0.0", "::"], cidrhost(trimspace(cidr), 0))
      )
    ])
    error_message = "public_access_cidrs must contain valid, restricted CIDRs and must not contain an unrestricted /0 network."
  }
}

variable "endpoint_private_access" {
  description = "Whether the EKS API endpoint is reachable from the VPC private network."
  type        = bool
  default     = true
}

variable "cluster_security_group_ids" {
  description = "Additional security groups for the EKS control plane."
  type        = list(string)
  default     = []
}

variable "max_node_count" {
  description = "Environment-wide maximum worker node count enforced by autoscaling and node-group validation."
  type        = number
  default     = 1000
  validation {
    condition     = floor(var.max_node_count) == var.max_node_count && var.max_node_count >= 1 && var.max_node_count <= 1000
    error_message = "max_node_count must be a whole number between 1 and 1000."
  }
}

variable "node_groups" {
  description = "Managed node groups and their explicit scaling and placement settings."
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
      desired_size   = 2
      instance_types = ["t3.medium"]
      disk_size      = 50
      capacity_type  = "ON_DEMAND"
      labels         = {}
    }
  }
  validation {
    condition = length(var.node_groups) > 0 && alltrue([
      for group in values(var.node_groups) : group.min_size >= 1 && group.max_size >= group.min_size && group.desired_size >= group.min_size && group.desired_size <= group.max_size && group.max_size <= var.max_node_count && contains(["ON_DEMAND", "SPOT"], group.capacity_type) && length(group.instance_types) > 0
    ])
    error_message = "node_groups must contain at least one group with valid min/max/desired sizes, instance types, capacity type, and max_size at or below max_node_count."
  }
}

variable "oidc_thumbprint" {
  description = "SHA-1-shaped example thumbprint for offline examples; supply the current issuer certificate thumbprint for a real deployment."
  type        = string
  default     = "0123456789abcdef0123456789abcdef01234567"
  validation {
    condition     = can(regex("^[0-9a-fA-F]{40}$", var.oidc_thumbprint))
    error_message = "oidc_thumbprint must be a 40-character hexadecimal SHA-1 thumbprint."
  }
}
