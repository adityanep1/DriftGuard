# GitHub OIDC module

Creates the GitHub Actions OpenID Connect provider and short-lived IAM roles for ECR publication and Terraform automation. Workflows assume these roles through OIDC instead of storing long-lived AWS access keys.

## Inputs and outputs

Inputs are `environment`, `project`, `github_repository` in `OWNER/REPOSITORY` form, and the allowed `branch`. Outputs are the provider ARN, ECR publish role ARN, and Terraform role ARN.

## Trust review

Review the repository, branch, audience, subject conditions, environment boundary, and role policies together. A branch change changes who can assume the role and requires security review. Keep ECR and Terraform permissions separate when the deployment model permits it.

## Validation

Run Terraform validation and IAM security checks. Inspect GitHub workflow permissions for `id-token: write`, confirm no static access key variables exist, and verify CI cannot use cluster credentials for normal GitOps delivery.
