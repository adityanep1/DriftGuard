# Terraform Module Catalog

Each module in this directory is independently reusable and receives provider configuration from its caller (no hidden provider declarations). Modules expose typed variables, validate unsafe values before resource evaluation, apply the required `Environment`, `Project`, and `ManagedBy` tags to all resources, and avoid hidden cross-module state dependencies.

## Module overview

| Module | What it owns | Key inputs | Key outputs |
|---|---|---|---|
| `networking` | VPC, public/private subnets, IGW, NAT, routes | environment, project, CIDRs, AZs, `nat_per_az` | VPC ID, public/private subnet IDs, NAT IDs |
| `eks` | EKS cluster, managed node groups, OIDC, secrets encryption | Kubernetes version, private subnet IDs, API CIDRs, node groups, node cap | Cluster name/endpoint/CA, OIDC ARN/issuer |
| `iam` | Workload IRSA roles and scoped policies | OIDC provider, issuer, namespace/SA bindings, actions/resources | Role ARNs/names and bindings |
| `ecr` | Private container repositories and lifecycle policies | service set, encryption type/KMS ARN, retention days | Repository names, URLs, ARNs |
| `dns` | Route53 zone, ACM certificate, DNS validation, optional ALB aliases | zone, hostnames, optional ALB name/zone ID | Zone ID, certificate ARN, validation records |
| `addons-bootstrap` | Pinned ArgoCD Helm release and Root Application | chart version, Config Repo URL/revision, timeout | ArgoCD release/root metadata |
| `github-oidc` | GitHub Actions OIDC provider and CI roles | repository, branch, environment | Provider and role ARNs |

## How modules compose

The live environment roots compose modules in dependency order. Networking provides private subnet IDs to EKS. EKS provides OIDC outputs to IAM. ECR and DNS are environment-scoped and independent. The ArgoCD bootstrap module is applied last, only after the cluster and provider configuration are usable.

Do not place Kubernetes day-2 resources in these modules. Do not use data lookups or hidden state references to reach another module's resources. If a module needs something from another module, add an explicit input/output and a focused validation.

## Validation

From `driftguard-infra/`:

```bash
terraform fmt -check -recursive
terraform init -backend=false   # (in each module directory)
terraform validate
python -m pytest policies/python/ -q
```

Also run tflint and tfsec (or Checkov) for security scanning. Validate examples as well as live roots when a module includes example configurations.

## Review checklist

When reviewing module changes, verify: tags on all resources, timeouts, handling of unknown values, deletion behavior, least-privilege permissions, provider constraints, environment isolation, output completeness, documentation, and cost impact. Every module README should explain any external dependency or prerequisite that cannot be tested offline.
