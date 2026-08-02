# Terraform module catalog

Each module is independently reusable and receives provider configuration from its caller. Modules expose typed variables, validate unsafe values before resource evaluation, apply the required `Environment`, `Project`, and `ManagedBy` tags, and avoid hidden cross-module state.

## Module contracts

| Module | Owns | Important inputs | Important outputs |
|---|---|---|---|
| `networking` | VPC, public/private subnets, IGW, NAT, routes | environment, project, CIDRs, AZs, `nat_per_az` | VPC ID, public/private subnet IDs, NAT IDs |
| `eks` | Cluster, managed node groups, OIDC, secrets encryption | Kubernetes version, private subnet IDs, API CIDRs, node groups, node cap | cluster name/endpoint/CA, OIDC ARN/issuer |
| `iam` | Workload IRSA roles and enumerated policies | OIDC provider, issuer, namespace/SA bindings, actions/resources | role ARNs/names and bindings |
| `ecr` | Private service repositories and lifecycle policies | service set, encryption type/KMS ARN, retention days | repository names, URLs, ARNs |
| `dns` | Route53 zone, ACM certificate, DNS validation, optional ALB aliases | zone, hostnames, optional ALB name/zone ID | zone ID, certificate ARN, validation records |
| `addons-bootstrap` | Pinned ArgoCD release and dependent Root_Application | chart version, Config_Repo URL/revision, timeout | ArgoCD release/root metadata |
| `github-oidc` | GitHub Actions OIDC provider and short-lived CI roles | repository, branch, environment | provider and role ARNs |

## Composition rules

The live environment roots compose modules in dependency order. Networking feeds private subnet IDs to EKS; EKS feeds OIDC outputs to IAM; ECR and DNS remain environment-scoped; ArgoCD bootstrap is applied only after the cluster and provider configuration are usable.

Do not place Kubernetes day-2 resources in these modules. Do not use data lookups or hidden state to reach another module's resources. Add an input/output and a focused validation when a contract changes.

## Module validation

From `driftguard-infra/`, run Terraform formatting, initialize each module with `-backend=false`, run `terraform validate`, and run the security/conformance tools. Run the Python policy tests after module edits. Validate examples as well as live roots when the module includes examples.

## Review checklist

Verify tags, timeouts, unknown values, deletion behavior, least privilege, provider constraints, environment isolation, outputs, documentation, and cost impact. A module README must explain any external dependency or prerequisite that cannot be tested offline.
