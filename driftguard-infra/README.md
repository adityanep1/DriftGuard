# DriftGuard infrastructure repository

This repository owns the AWS substrate and the one-time ArgoCD handoff. It must not become a second Kubernetes deployment system: after ArgoCD is seeded, day-2 resources belong in `driftguard-gitops`.

## Ownership

Terraform owns networking, EKS, IAM/IRSA, ECR, DNS/ACM, remote state bootstrap, GitHub OIDC roles, and the pinned ArgoCD Helm release. The `live/dev`, `live/staging`, and `live/prod` roots compose those modules with distinct backend keys and environment-specific sizing.

## Directory map

- `bootstrap/`: one-time S3 state bucket and DynamoDB lock table.
- `modules/`: independently reusable infrastructure modules; see `modules/README.md`.
- `live/<env>/`: isolated environment roots; see `live/README.md`.
- `policies/`: Rego plan policies, fixtures, Python conformance helpers, and tests.
- `scripts/`: validation, integration, smoke, and guarded teardown scripts.
- `.github/workflows/`: plan, apply, drift, and security automation.

## Required toolchain

Terraform `1.15.3` is pinned in the project documentation. AWS provider constraints remain `~> 5.0`; Helm, Kubernetes, and TLS providers are pinned in module/provider files. Commit provider lock files. Validation also uses Python, pytest, tflint, tfsec or Checkov, conftest/OPA, kubeconform, and optionally promtool for GitOps rules.

## Provisioning order

1. Validate AWS identity, region, OIDC trust, and cost ownership.
2. Bootstrap the encrypted/versioned state bucket and DynamoDB lock table.
3. Select one environment and review its backend key, CIDRs, node groups, node cap, and NAT mode.
4. Apply networking, EKS, IAM, ECR, and optional DNS in dependency order.
5. Configure Kubernetes/Helm providers from the new EKS outputs.
6. Install ArgoCD through `modules/addons-bootstrap`; verify readiness before trusting the Root_Application.
7. Observe ArgoCD reconcile the Config_Repo; do not apply day-2 manifests manually.

## Validation

Run `./scripts/validate.ps1` from this directory on Windows or `./scripts/validate.sh` on POSIX. The validators are fail-closed: unavailable required tools block the run. Always run focused Python tests and `terraform fmt -check -recursive` before the full suite.

## Mutation and teardown warnings

`terraform apply`, `terraform destroy`, `e2e-smoke.ps1`, and integration scripts are mutating or destructive. Use a dedicated account/context, review the plan, and pass explicit confirmation flags. Teardown removes ALB-backed ingress dependencies first and stops on failure so a partial result can be investigated and rerun safely.

## Deployment blockers

Replace `your-org`, example account IDs, example domains, placeholder ARNs, and test-only values before any real deployment. Do not solve a missing secret by placing it in Terraform variables, GitHub workflow source, state fixtures, or GitOps YAML.
