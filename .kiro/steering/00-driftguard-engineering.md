---
inclusion: always
---

# DriftGuard Engineering Contract

This is the master reference for anyone working in the DriftGuard monorepo. It defines the architecture boundary, the safety model, and the definition of done that applies to every change regardless of which sub-project you are touching.

## Platform Mission

DriftGuard is a GitOps infrastructure platform running on AWS EKS. Its defining behavior is controlled convergence: Terraform creates the AWS substrate and performs a one-time ArgoCD handoff; ArgoCD then owns all Kubernetes day-2 state and continuously reconciles it from Git. The full platform specification lives in [requirements](../specs/gitops-platform/requirements.md), [design](../specs/gitops-platform/design.md), and [tasks](../specs/gitops-platform/tasks.md).

The monorepo contains three sub-projects:

| Sub-project | Purpose | README |
|---|---|---|
| driftguard-infra | Terraform modules, live environments, Rego policies, Python tests | [driftguard-infra](../../driftguard-infra/README.md) |
| driftguard-gitops | ArgoCD applications, add-ons, conformance, workloads, Kubernetes tests | [driftguard-gitops](../../driftguard-gitops/README.md) |
| demo-service | FastAPI microservice that flows through the full delivery pipeline | [demo-service](../../demo-service/README.md) |

## Two-Layer Ownership Model

The platform operates in two distinct layers with a clean handoff boundary:

**Layer 1: Infrastructure (Terraform)**
Terraform owns VPC topology, subnets, NAT gateways, the EKS control plane, managed node groups, IAM/IRSA roles, ECR repositories, Route53/ACM DNS, remote state, and the initial ArgoCD installation via the [addons-bootstrap module](../../driftguard-infra/modules/addons-bootstrap/README.md). Once Terraform seeds ArgoCD and applies the [Root Application](../../driftguard-gitops/bootstrap/root-app.yaml), it steps back. The module catalog is documented in the [modules README](../../driftguard-infra/modules/README.md).

**Layer 2: Kubernetes (ArgoCD)**
ArgoCD discovers child Applications from the Root Application and owns platform add-ons, Gatekeeper policies, observability pipelines, External Secrets references, workloads, and progressive delivery via Argo Rollouts. The full GitOps configuration is organized under [driftguard-gitops](../../driftguard-gitops/README.md).

**The boundary rule:** CI changes Git and publishes container images. CI must not use cluster credentials or run `kubectl apply` for normal delivery. Direct cluster mutations are permitted only inside explicitly named, destructive-safe integration or teardown scripts.

## Non-Negotiable Safety Gates

These constraints apply to every change without exception:

1. No `terraform apply`, `terraform destroy`, cloud provisioning, or cluster mutation against production without explicit confirmation and an identified target.
2. Teardown must remove ingress and load-balancer dependencies first and stop on failure.
3. Crossplane and other billable-resource features remain disabled until deliberately enabled in a reviewed change.
4. Changes to IAM trust, security policies, admission failure behavior, pruning, deletion policies, or state backends require an explicit impact review.
5. Never commit credentials, access keys, private keys, copied tokens, real account secrets, or plaintext secret values anywhere in the repository.
6. Treat placeholders such as `your-org`, `example.invalid`, and example account IDs as deployment blockers, not production defaults.

See [30-security-validation.md](30-security-validation.md) for detailed policy enforcement rules and [10-terraform-aws.md](10-terraform-aws.md) for provider-level security invariants.

## Definition of Done

A change is complete only when implementation, documentation, validation, and failure behavior all agree. Here is what "done" means concretely:

**Infrastructure changes (driftguard-infra):**
```bash
# From driftguard-infra/ root:
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
python3 -m pytest policies/python/ -q
```
The full validation flow is codified in [validate.sh](../../driftguard-infra/scripts/bash/validate.sh).

**GitOps changes (driftguard-gitops):**
```bash
# From driftguard-gitops/ root:
python3 -m pytest tests/ -q
python3 scripts/scan_no_plaintext_secrets.py
```
See [tests README](../../driftguard-gitops/tests/README.md) for test conventions.

**Demo service changes (demo-service):**
```bash
# From demo-service/ root:
docker build -t demo-service:test .
```

**Documentation changes:**
Verify paths, commands, version pins, safety warnings, links, environment names, and the absence of em dashes.

If a required tool (terraform binary, conftest, kubeconform, a live cluster) is unavailable, report the exact blocked check and leave its task unchecked. Never convert an authored-but-unverified integration into a claimed runtime result.

## Change Discipline

1. Read the applicable specification in [specs](../specs/gitops-platform/README.md) before editing implementation.
2. Inspect neighboring code, README guidance, tests, and pinned versions before inventing a pattern.
3. Make the smallest coherent change; do not opportunistically reformat unrelated files.
4. Prefer pinned versions, explicit dependencies, least privilege, immutable artifacts, and reversible operations.
5. Keep terminology consistent: Config_Repo, Root_Application, Environment, IRSA, Self_Heal, and opt-in pruning are canonical terms.

## CI Workflows

The monorepo uses root-level GitHub Actions workflows that coordinate validation across all sub-projects:

- [ci-infra.yml](../../.github/workflows/ci-infra.yml): Terraform formatting, validation, and policy tests
- [ci-gitops.yml](../../.github/workflows/ci-gitops.yml): YAML parsing, secret scanning, and conformance tests
- [ci-demo-service.yml](../../.github/workflows/ci-demo-service.yml): Docker build and application tests

## Documentation Contract

Every new operational boundary needs a README or an update to the nearest README. Document purpose, ownership, inputs, outputs, prerequisites, commands, expected success, failure modes, rollback/cleanup, and validation. See [40-documentation.md](40-documentation.md) for full documentation standards.

## Related Steering Files

This engineering contract is always loaded. The following domain-specific steering files activate when you touch relevant files:

- [10-terraform-aws.md](10-terraform-aws.md): Terraform module boundaries, provider rules, and AWS security invariants
- [20-gitops-kubernetes.md](20-gitops-kubernetes.md): ArgoCD safety, Kubernetes resource quality, and progressive delivery
- [30-security-validation.md](30-security-validation.md): Policy enforcement, secret scanning, and IAM review
- [40-documentation.md](40-documentation.md): README structure, writing style, and accuracy standards
