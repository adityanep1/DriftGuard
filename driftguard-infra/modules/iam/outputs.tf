output "role_arns" {
  description = "IRSA role ARN keyed by workload name."
  value       = { for workload, role in aws_iam_role.irsa : workload => role.arn }
}

output "role_names" {
  description = "IRSA role name keyed by workload name."
  value       = { for workload, role in aws_iam_role.irsa : workload => role.name }
}

output "service_account_bindings" {
  description = "Explicit namespace/service-account binding keyed by workload name."
  value = {
    for workload, definition in var.workloads : workload => {
      namespace       = definition.namespace
      service_account = definition.service_account
    }
  }
}
