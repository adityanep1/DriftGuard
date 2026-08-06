---
inclusion: fileMatch
fileMatchPattern: 'driftguard-infra/**/*.tf'
---

# Terraform and AWS Implementation Rules

This guide covers everything you need to know when working with Terraform configurations in the driftguard-infra sub-project. It establishes module boundaries, provider constraints, security invariants, and the validation workflow that every infrastructure change must pass.

## Tooling and Version Pins

All versions are pinned in [versions.yaml](../../driftguard-gitops/versions.yaml) and must be updated there first:

| Tool | Version | Constraint |
|---|---|---|
| Terraform | 1.9.8 | Exact pin in CI and local development |
| AWS Provider | ~> 5.0 | Allows minor/patch updates within major 5 |
| conftest | 0.56.0 | Used for Rego policy evaluation against plan JSON |

Never float a version. When upgrading, update versions.yaml, the relevant `.terraform.lock.hcl`, and any CI workflow references in the same commit.

## Module Architecture

The infrastructure is composed of focused, independently invocable modules. Each module owns a clearly bounded domain and must not reach into another module's resources by path or hidden state. The full inventory lives in the [module catalog](../../driftguard-infra/modules/README.md).

### Module Boundaries

| Module | Owns | README |
|---|---|---|
| [networking](../../driftguard-infra/modules/networking/README.md) | VPC topology, public/private subnets, IGW, NAT, routes, network tags | VPC foundation |
| [eks](../../driftguard-infra/modules/eks/README.md) | Control plane, managed node groups, private node placement, API CIDR allowlisting, secrets encryption, OIDC provider, connection outputs | Kubernetes layer |
| [iam](../../driftguard-infra/modules/iam/README.md) | IRSA trust and permission policies binding one concrete namespace/service-account pair | Identity and access |
| [ecr](../../driftguard-infra/modules/ecr/README.md) | One private encrypted repository per service, scan-on-push, lifecycle policy, required tags | Container registry |
| [dns](../../driftguard-infra/modules/dns/README.md) | Route53, ACM DNS validation, optional ALB aliases (does not own Kubernetes Ingress) | DNS and certificates |
| [addons-bootstrap](../../driftguard-infra/modules/addons-bootstrap/README.md) | Pinned ArgoCD install and the Root_Application seed that hands off to GitOps | ArgoCD handoff |
| [github-oidc](../../driftguard-infra/modules/github-oidc/README.md) | GitHub Actions OIDC federation for short-lived AWS credentials in CI | CI identity |

A module may consume provider configuration and declared input variables, but it must produce only well-typed outputs. Cross-module references happen through output values in composition roots, never through filesystem paths or hidden state.

## Live Environments

Each environment has its own root composition under [live/](../../driftguard-infra/live/README.md), with an isolated backend key (`env/<environment>/terraform.tfstate`). Environments compose modules with environment-specific variable values and must not diverge in structure without explicit justification.

## Provider and State Rules

These rules protect state integrity and prevent credential leaks:

- Pin Terraform, every provider, and every chart/tool version. Commit `.terraform.lock.hcl`; never add it to `.gitignore`.
- AWS provider constraints must remain compatible with `~> 5.0` unless the specification is deliberately revised in a design document.
- Never place credentials in `.tf`, `.tfvars`, state fixtures, READMEs, plans, logs, or workflow source.
- Use variables for environment-specific values and add `validation {}` blocks to reject unsafe inputs before resources are evaluated.
- Backend configuration uses S3 for state and DynamoDB for locking; the key pattern is `env/<environment>/terraform.tfstate`.

## Security Invariants

These are non-negotiable for every resource in the infrastructure layer:

**Tagging:** Every taggable AWS resource receives exactly `Environment`, `Project`, and `ManagedBy` tags with non-empty string values. The Rego policy in [tags.rego](../../driftguard-infra/policies/tags.rego) enforces this against plan JSON.

**Network isolation:** EKS API access must use a non-empty restricted CIDR allowlist; the policy in [eks.rego](../../driftguard-infra/policies/eks.rego) rejects IPv4 `0.0.0.0/0` and IPv6 `::/0` unrestricted entries. Nodes use private subnet IDs only. Production uses NAT-per-AZ; non-production deviations must be explicit and documented.

**IAM least privilege:** IAM policies must enumerate actions and resources. The [iam.rego](../../driftguard-infra/policies/iam.rego) policy rejects combinations of wildcard action with wildcard resource. Trust policies for IRSA must bind exactly one `system:serviceaccount:<namespace>:<service-account>` subject.

**Encryption and scanning:** EKS secrets encryption, ECR encryption, scan-on-push, and private repository settings are mandatory. See [ecr.rego](../../driftguard-infra/policies/ecr.rego) and [security_group.rego](../../driftguard-infra/policies/security_group.rego) for specific enforcement rules.

For a deeper dive into the policy framework and IAM review process, see [30-security-validation.md](30-security-validation.md).

## Validation Workflow

The full validation flow is codified in [validate.sh](../../driftguard-infra/scripts/bash/validate.sh) and runs in [ci-infra.yml](../../.github/workflows/ci-infra.yml). The steps in order:

```bash
# 1. Format check (no mutations)
terraform fmt -check -recursive

# 2. Initialize without a real backend
terraform init -backend=false

# 3. Validate configuration syntax and type correctness
terraform validate

# 4. Run Python policy conformance tests
python3 -m pytest policies/python/ -q
```

When a real plan is available (requires AWS credentials), the additional steps are:

```bash
# 5. Generate plan JSON
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json

# 6. Run Rego policies against the plan
conftest test plan.json -p policies/
```

Validate the affected module, its examples, and every live environment that composes it. Use plan JSON for policy checks; do not infer plan compliance from source text alone when a real plan is available.

Policy test fixtures live in [policies/tests/](../../driftguard-infra/policies/tests/) with both valid and invalid plan samples.

## Python Policy Tests

The Python conformance tests in [policies/python/](../../driftguard-infra/policies/python/README.md) use pytest with hypothesis for property-based testing. They validate that the Rego policies correctly accept compliant plans and reject non-compliant ones. Always run these from the `driftguard-infra/` root:

```bash
cd driftguard-infra
python3 -m pytest policies/python/ -q
```

## Change Review Checklist

Before considering a Terraform change complete, confirm:

- Dependency order is correct and there are no circular references
- Unknown-value behavior is handled (values not known until apply are not used in conditionals)
- Timeout behavior is specified for long-running resources
- Destroy behavior is safe (prevent_destroy where appropriate, deletion protection enabled)
- All taggable resources carry the required tags
- IAM follows least privilege with enumerated actions
- Environment isolation is maintained (no cross-environment state references)
- Outputs are typed and documented
- The nearest README is updated
- A rollback path exists for the change

A resource that can create an external bill or delete data requires an explicit retention/deletion review before merge.
