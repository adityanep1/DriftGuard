output "role_arns" {
  description = "Example IRSA role ARNs."
  value       = module.iam.role_arns
}

output "service_account_bindings" {
  description = "Example workload trust bindings."
  value       = module.iam.service_account_bindings
}
