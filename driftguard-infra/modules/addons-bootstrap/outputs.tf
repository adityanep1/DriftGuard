output "argocd_release_name" {
  description = "Installed ArgoCD Helm release name."
  value       = helm_release.argocd.name
}

output "root_application_name" {
  description = "Seeded Root_Application name."
  value       = kubernetes_manifest.root_application.manifest.metadata.name
}

output "root_application_path" {
  description = "Config_Repo path consumed by the Root_Application."
  value       = var.root_application_path
}
