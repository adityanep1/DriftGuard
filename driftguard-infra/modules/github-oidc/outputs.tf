output "github_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_publish_role_arn" {
  description = "Short-lived role used by image publishing CI."
  value       = aws_iam_role.ecr_publish.arn
}

output "terraform_role_arn" {
  description = "Short-lived role used by Terraform apply CI (branch-only trust)."
  value       = aws_iam_role.terraform.arn
}

output "terraform_plan_role_arn" {
  description = "Short-lived read-only role used by Terraform plan CI (branch + PR trust)."
  value       = aws_iam_role.terraform_plan.arn
}

output "terraform_drift_role_arn" {
  description = "Short-lived read-only role used by scheduled drift-check CI (branch-only trust)."
  value       = aws_iam_role.terraform_drift.arn
}
