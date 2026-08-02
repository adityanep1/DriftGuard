---
inclusion: fileMatch
fileMatchPattern: 'driftguard-infra/**/*.tf'
---

# Terraform and AWS implementation rules

## Module boundaries
- Keep modules independently invocable. A module may consume provider configuration and declared inputs, but it must not reach into another module's resources by path or hidden state.
- `networking` owns VPC topology, public/private subnets, IGW, NAT, routes, and network tags.
- `eks` owns the control plane, managed node groups, private node placement, API CIDR allowlisting, secrets encryption, OIDC, and connection outputs.
- `iam` owns IRSA trust and permission policies. Trust must bind one concrete namespace/service-account pair.
- `ecr` owns one private encrypted repository per service, scan-on-push, lifecycle policy, and required tags.
- `dns` owns Route53, ACM DNS validation, and optional ALB aliases; it does not own Kubernetes Ingress.
- `addons-bootstrap` owns only the pinned ArgoCD install and dependent Root_Application seed.

## Provider and state rules
- Pin Terraform, every provider, and every chart/tool version. Commit `.terraform.lock.hcl`; never ignore it.
- AWS provider constraints must remain compatible with `~> 5.0` unless the specification is deliberately revised.
- Each environment has an isolated backend key under `env/<environment>/terraform.tfstate`.
- Never place credentials in `.tf`, `.tfvars`, state fixtures, READMEs, plans, logs, or workflow source.
- Use variables for environment-specific values and validate unsafe values before resources are evaluated.

## Security invariants
- Every taggable AWS resource receives exactly `Environment`, `Project`, and `ManagedBy` with non-empty values.
- EKS API access must use a non-empty restricted CIDR allowlist; reject IPv4 and IPv6 unrestricted entries.
- Nodes use private subnet IDs only. Production uses NAT-per-AZ; non-production behavior must be explicit and documented.
- IAM policies must enumerate actions and resources. Do not combine wildcard action and wildcard resource.
- EKS secrets encryption, ECR encryption, scan-on-push, and private repository behavior are mandatory.

## Validation workflow
Run `terraform fmt -check -recursive`, initialize with `-backend=false`, run `terraform validate`, then tflint/security/conftest checks. Validate the affected module, its examples, and every live environment that composes it. Use plan JSON for policy checks; do not infer plan compliance from source text alone when a real plan is available.

## Change review checklist
Confirm dependency order, unknown-value behavior, timeout behavior, destroy behavior, tags, least privilege, environment isolation, outputs, documentation, and a rollback path. A resource that can create an external bill or delete data requires an explicit retention/deletion review.
