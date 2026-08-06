# DriftGuard

Welcome to DriftGuard, a GitOps Infrastructure Automation Platform built for AWS EKS. This project demonstrates how to run a production-grade Kubernetes platform using a strict two-layer control model where every change flows through Git and every deployment is automated, auditable, and recoverable.

## The two-layer model

DriftGuard separates infrastructure provisioning from application delivery into two distinct control planes:

**Layer A (Terraform)** handles everything below the Kubernetes API: isolated AWS networking, EKS clusters, IAM and IRSA roles, ECR container registries, DNS and TLS certificates, remote state management, GitHub OIDC for keyless CI, and the initial ArgoCD installation that bridges the two layers.

**Layer B (ArgoCD)** handles everything above the Kubernetes API: platform add-ons, admission policies, observability (metrics, logs, traces), secret references, workload deployments, and progressive delivery. ArgoCD continuously reconciles the cluster state against this Git repository, so the cluster always matches what is declared in code.

Once Terraform installs ArgoCD and seeds the Root Application, Layer A steps back. Day-2 Kubernetes resources belong exclusively to Layer B.

## Repository map

| Path | What it does | Controlled by |
|---|---|---|
| `driftguard-infra/` | Terraform modules, live environment roots, conformance policies, CI workflows, and infrastructure scripts | Terraform and AWS |
| `driftguard-gitops/` | ArgoCD Applications, Helm chart sources, Gatekeeper policies, observability config, workload manifests, and progressive delivery | ArgoCD and Kubernetes |
| `demo-service/` | A FastAPI application that exercises the full delivery path: tests, container build, ECR publish, GitOps tag update, canary rollout | GitHub Actions and ECR |

## Getting started

If you are new to this codebase, here is a good reading order:

1. Start with [driftguard-infra/README.md](driftguard-infra/README.md) to understand how the AWS foundation is provisioned and what safety gates are in place.
2. Read [driftguard-gitops/README.md](driftguard-gitops/README.md) to understand the ArgoCD ownership boundary and how Kubernetes state is managed through Git.
3. Check out [demo-service/README.md](demo-service/README.md) to see how application code flows from source to production through the delivery pipeline.
4. Browse [driftguard-infra/modules/README.md](driftguard-infra/modules/README.md) for the Terraform module catalog and their contracts.
5. Look at [driftguard-gitops/bootstrap/README.md](driftguard-gitops/bootstrap/README.md) to understand how Terraform hands off control to ArgoCD.

## Safe local checks

These commands run entirely offline. They do not provision AWS resources or mutate any cluster.

From `driftguard-infra/`:

```bash
terraform fmt -check -recursive
python -m pytest policies/python -q
```

From `driftguard-gitops/`:

```bash
python scripts/scan_no_plaintext_secrets.py .
python -m pytest tests -q
```

From `demo-service/`:

```bash
python -m pytest tests -q
```

Full validation additionally requires pinned external tools (tflint, tfsec, conftest, kubeconform, promtool) and cached Terraform providers. Runtime claims require a dedicated test cluster.

## Safety rules

A few non-negotiable rules that apply everywhere in this repository:

- Never commit credentials, plaintext secret values, or provider lock-file changes without review.
- CI changes Git and publishes artifacts; it never runs `kubectl apply` directly.
- Do not run `terraform apply`, `terraform destroy`, or integration scripts without an explicitly identified safe target and account.
- Replace all `your-org` placeholders, example account IDs, and example domains before any real deployment.

## Documentation map

Every major directory has its own README with detailed guidance:

- Infrastructure operations and provisioning: [driftguard-infra/README.md](driftguard-infra/README.md)
- Terraform module contracts: [driftguard-infra/modules/README.md](driftguard-infra/modules/README.md)
- Environment isolation: [driftguard-infra/live/README.md](driftguard-infra/live/README.md)
- Validation and teardown scripts: [driftguard-infra/scripts/README.md](driftguard-infra/scripts/README.md)
- Policy conformance tests: [driftguard-infra/policies/python/README.md](driftguard-infra/policies/python/README.md)
- GitOps bootstrap and handoff: [driftguard-gitops/bootstrap/README.md](driftguard-gitops/bootstrap/README.md)
- AppProject security model: [driftguard-gitops/projects/README.md](driftguard-gitops/projects/README.md)
- Admission policies: [driftguard-gitops/policies/README.md](driftguard-gitops/policies/README.md)
- Conformance rules: [driftguard-gitops/conformance/README.md](driftguard-gitops/conformance/README.md)
- Observability stack: [driftguard-gitops/observability/README.md](driftguard-gitops/observability/README.md)
- Demo workload delivery: [driftguard-gitops/workloads/demo-service/README.md](driftguard-gitops/workloads/demo-service/README.md)
- GitOps test suite: [driftguard-gitops/tests/README.md](driftguard-gitops/tests/README.md)

## Platform specifications

The formal platform specification lives in the `.kiro/specs/gitops-platform/` directory and covers the full requirements, architecture, and implementation plan:

- [Requirements](.kiro/specs/gitops-platform/requirements.md): User stories, acceptance criteria, and security constraints
- [Design](.kiro/specs/gitops-platform/design.md): Architecture, ownership boundaries, component interfaces, and test strategy
- [Tasks](.kiro/specs/gitops-platform/tasks.md): Implementation sequence, property-test obligations, and task status

## Development guidance

The [steering files](.kiro/steering/README.md) provide workspace-level guidance for working in this monorepo. They cover engineering conventions, Terraform and AWS rules, GitOps and Kubernetes patterns, security validation, and documentation standards. The steering files activate automatically based on which files you are editing.

## Continuous integration

Root-level GitHub Actions workflows run validation for each sub-project whenever its files change:

- [ci-infra.yml](.github/workflows/ci-infra.yml): Terraform formatting, Python conformance tests, and conftest policy checks for `driftguard-infra/`
- [ci-gitops.yml](.github/workflows/ci-gitops.yml): Secret scanning, conftest conformance, and pytest for `driftguard-gitops/`
- [ci-demo-service.yml](.github/workflows/ci-demo-service.yml): Pytest and Docker build for `demo-service/`
