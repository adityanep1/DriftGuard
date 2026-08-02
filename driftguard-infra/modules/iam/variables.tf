variable "name_prefix" {
  description = "Lowercase prefix used for IRSA role names."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,40}$", var.name_prefix))
    error_message = "name_prefix must contain only letters, numbers, and hyphens and be at most 40 characters."
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

variable "cluster_oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider used to federate workload identities."
  type        = string
  validation {
    condition     = can(regex("^arn:[^:]+:iam::[0-9]{12}:oidc-provider/.+", var.cluster_oidc_provider_arn))
    error_message = "cluster_oidc_provider_arn must be an IAM OIDC provider ARN."
  }
}

variable "oidc_issuer_url" {
  description = "HTTPS issuer URL from the EKS cluster identity block."
  type        = string
  validation {
    condition     = can(regex("^https://[^/]+/.+$", var.oidc_issuer_url))
    error_message = "oidc_issuer_url must be an HTTPS OIDC issuer URL."
  }
}

variable "workloads" {
  description = "Workloads requiring IRSA, each with exactly one namespace/service-account binding and enumerated permissions."
  type = map(object({
    namespace       = string
    service_account = string
    policy_statements = list(object({
      actions   = set(string)
      resources = set(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for workload_name in keys(var.workloads) : can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$", workload_name))
    ])
    error_message = "Workload names must be valid IAM role suffixes of at most 63 characters."
  }

  validation {
    condition = length(distinct([
      for workload in values(var.workloads) : "${workload.namespace}:${workload.service_account}"
    ])) == length(var.workloads)
    error_message = "Each IRSA role must bind a unique namespace and service account pair."
  }

  validation {
    condition = alltrue([
      for workload in values(var.workloads) : length(workload.policy_statements) > 0
    ])
    error_message = "Each IRSA workload must define at least one permission statement."
  }

  validation {
    condition = alltrue(flatten([
      for workload in values(var.workloads) : [
        length(trimspace(workload.namespace)) > 0 && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", workload.namespace)) &&
        length(trimspace(workload.service_account)) > 0 && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", workload.service_account))
      ]
    ]))
    error_message = "Each IRSA namespace and service account must be a non-empty DNS-compatible name."
  }

  validation {
    condition = alltrue(flatten([
      for workload in values(var.workloads) : [
        for statement in workload.policy_statements : length(statement.actions) > 0 && length(statement.resources) > 0
      ]
    ]))
    error_message = "Every IRSA policy statement must enumerate at least one action and one resource."
  }

  validation {
    condition = alltrue(flatten([
      for workload in values(var.workloads) : [
        for statement in workload.policy_statements : !(contains(statement.actions, "*") && contains(statement.resources, "*"))
      ]
    ]))
    error_message = "IRSA policies must not combine wildcard actions with wildcard resources."
  }

  validation {
    condition = alltrue(flatten([
      for workload in values(var.workloads) : [
        for statement in workload.policy_statements : alltrue([
          for resource in statement.resources : resource == "*" || can(regex("^arn:[^:]+:", resource))
        ])
      ]
    ]))
    error_message = "Every IRSA policy resource must be an explicit ARN or the approved wildcard resource."
  }
}
