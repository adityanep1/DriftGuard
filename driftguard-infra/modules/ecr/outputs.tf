output "repository_names" {
  description = "Private ECR repository names keyed by service."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.name }
}

output "repository_urls" {
  description = "Private ECR repository URLs keyed by service."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.repository_url }
}

output "repository_arns" {
  description = "Private ECR repository ARNs keyed by service."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.arn }
}
