variable "argocd_namespace" {
  description = "Namespace for the ArgoCD control plane."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Pinned ArgoCD Helm chart version."
  type        = string
  default     = "7.7.16"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd_chart_version))
    error_message = "argocd_chart_version must be an exact semantic version."
  }
}

variable "config_repo_url" {
  description = "HTTPS URL of the Config_Repo containing the root application manifest."
  type        = string
  validation {
    condition     = can(regex("^https://", var.config_repo_url))
    error_message = "config_repo_url must use HTTPS."
  }
}

variable "config_repo_revision" {
  description = "Immutable branch, tag, or commit revision consumed by ArgoCD."
  type        = string
  default     = "main"
  validation {
    condition     = length(trimspace(var.config_repo_revision)) > 0
    error_message = "config_repo_revision must not be empty."
  }
}

variable "root_application_path" {
  description = "Path in Config_Repo containing the Root_Application children."
  type        = string
  default     = "bootstrap/children"
}

variable "installation_timeout_seconds" {
  description = "Maximum Helm wait time for ArgoCD readiness, capped at 600 seconds."
  type        = number
  default     = 600
  validation {
    condition     = floor(var.installation_timeout_seconds) == var.installation_timeout_seconds && var.installation_timeout_seconds >= 1 && var.installation_timeout_seconds <= 600
    error_message = "installation_timeout_seconds must be a whole number between 1 and 600."
  }
}
