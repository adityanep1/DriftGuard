# GitHub OIDC Module

This module creates the GitHub Actions OpenID Connect provider and short-lived IAM roles for CI automation. Instead of storing long-lived AWS access keys as GitHub secrets, workflows assume these roles through OIDC federation. Credentials are issued on-demand, scoped to a specific repository and branch, and expire automatically.

## What gets created

- A GitHub Actions OIDC identity provider in AWS IAM
- An ECR publish role (for pushing container images)
- A Terraform automation role (for running infrastructure plans and applies)

## Inputs and outputs

**Inputs:** `environment`, `project`, `github_repository` (in `OWNER/REPOSITORY` format), and the allowed `branch`.

**Outputs:** Provider ARN, ECR publish role ARN, and Terraform role ARN.

## Trust boundary

The trust policy binds role assumption to a specific repository, branch, audience, and subject. Changing the branch condition changes who can assume the role, so branch changes require security review.

Keep ECR and Terraform permissions in separate roles when the deployment model allows it. The ECR role should only be able to push images; the Terraform role should only be able to plan and apply infrastructure.

## Validation

Run Terraform validation and IAM security checks. In the GitHub workflow, confirm that `id-token: write` permission is set, no static access key variables exist, and CI cannot use cluster credentials for normal GitOps delivery (that is ArgoCD's job, not CI's).

## Related documentation

- [Module catalog](../README.md)
- [Python conformance tests](../../policies/python/README.md)
- [Live environment roots](../../live/README.md)
