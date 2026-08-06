# DriftGuard Infrastructure Repository

This repository owns the AWS substrate and the one-time handoff to ArgoCD. Its job is to provision everything Kubernetes needs to run, install ArgoCD, and then get out of the way. After ArgoCD is seeded with the Root Application, all day-2 Kubernetes resources belong in `driftguard-gitops`.

Think of this as the "foundation layer." It builds the house (networking, cluster, identity, registries, DNS), installs the construction manager (ArgoCD), and then hands over the keys.

## What Terraform owns

Terraform manages networking (VPC, subnets, NAT, routing), EKS (cluster, node groups, OIDC), IAM/IRSA (workload roles with least-privilege policies), ECR (private container registries), DNS/ACM (Route53 zones and TLS certificates), remote state (S3 backend with DynamoDB locking), GitHub OIDC (keyless CI roles), and the pinned ArgoCD Helm release.

The `live/dev`, `live/staging`, and `live/prod` roots each compose these modules with their own backend keys, CIDR ranges, and environment-specific sizing.

## Directory layout

| Path | Purpose |
|---|---|
| `bootstrap/` | One-time S3 state bucket and DynamoDB lock table setup |
| `modules/` | Independently reusable infrastructure modules (see `modules/README.md`) |
| `live/<env>/` | Isolated environment roots with their own state and variables (see `live/README.md`) |
| `policies/` | Rego plan policies, fixtures, Python conformance helpers, and tests (see `policies/python/README.md`) |
| `scripts/` | Validation, integration, smoke, and guarded teardown scripts (see `scripts/README.md`) |
| `.github/workflows/` | Plan, apply, drift detection, and security automation |

## Required toolchain

The project uses Terraform `1.9.8` with the AWS provider constrained to `~> 5.0`. Helm, Kubernetes, and TLS providers are pinned in module and provider files. Always commit provider lock files after changes.

For full validation, you will also need: Python 3.11+, pytest, tflint, tfsec (or Checkov), conftest/OPA, kubeconform, and optionally promtool for GitOps rule validation.

## Provisioning order

If you are setting up a new environment from scratch, follow these steps in order:

1. Validate your AWS identity, region, OIDC trust configuration, and cost-ownership tags.
2. Bootstrap the encrypted, versioned state bucket and DynamoDB lock table (see `bootstrap/README.md`).
3. Pick an environment (`dev`, `staging`, or `prod`) and review its backend key, CIDRs, node groups, node cap, and NAT mode.
4. Apply networking, EKS, IAM, ECR, and optional DNS in dependency order.
5. Configure the Kubernetes and Helm providers using the EKS outputs from the previous step.
6. Install ArgoCD through the `modules/addons-bootstrap` module. Wait for readiness before trusting the Root Application.
7. Observe ArgoCD reconcile the Config Repo. Do not manually apply day-2 manifests.

## Running validation locally

On POSIX systems:

```bash
bash scripts/bash/validate.sh
```

On Windows:

```powershell
./scripts/powershell/validate.ps1
```

The validators are fail-closed: if a required tool is unavailable, the run stops rather than reporting a false pass. You can always run the focused Python tests independently:

```bash
python -m pytest policies/python/ -q
terraform fmt -check -recursive
```

## Mutation and teardown warnings

Commands like `terraform apply`, `terraform destroy`, and the integration/smoke scripts are mutating or destructive. Always use a dedicated account or context, review the plan output carefully, and pass explicit confirmation flags. The teardown scripts remove ALB-backed ingress dependencies first and stop on failure so you can investigate before retrying.

## Before your first real deployment

Replace all `your-org` references, example account IDs, example domains, placeholder ARNs, and test-only values with your actual configuration. Never solve a missing secret by placing it directly in Terraform variables, GitHub workflow files, state fixtures, or GitOps YAML.

## Related documentation

- [Root README](../README.md)
- [Terraform and AWS steering](../.kiro/steering/10-terraform-aws.md)
- [CI workflow (ci-infra.yml)](../.github/workflows/ci-infra.yml)
- [Module catalog](modules/README.md)
- [Live environment roots](live/README.md)
- [Conformance policies](policies/README.md)
- [Python conformance tests](policies/python/README.md)
- [Validation and teardown scripts](scripts/README.md)
- [State backend bootstrap](bootstrap/README.md)
