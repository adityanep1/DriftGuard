# IAM and IRSA Module

This module creates one IAM role per workload that needs AWS access through IAM Roles for Service Accounts (IRSA). Each role's trust policy binds to the EKS cluster's OIDC provider and exactly one concrete Kubernetes namespace/service-account pair. No wildcards, no shared roles.

## How it works

IRSA lets Kubernetes pods assume IAM roles without long-lived credentials. The pod's service account gets annotated with the role ARN, and when the pod starts, the EKS OIDC provider issues a token that AWS STS trusts. This module creates the roles and trust policies that make this work.

## Inputs

Provide `name_prefix`, `environment`, `project`, the EKS `cluster_oidc_provider_arn`, the HTTPS `oidc_issuer_url`, and a `workloads` map. Each workload entry must specify:

- A namespace and service account (exactly one pair)
- At least one policy statement with non-empty action and resource sets

Resources must be explicit ARNs or an intentionally reviewed single-dimension wildcard. A wildcard action combined with a wildcard resource is rejected before apply. Duplicate namespace/service-account bindings are also rejected.

## Outputs

`role_arns`, `role_names`, and `service_account_bindings`, all keyed by workload name.

## Security review

When reviewing IAM changes, confirm:

- The trust principal matches the intended OIDC provider
- The `sub` condition is concrete (no wildcards)
- The audience condition is present
- Permissions are scoped to the minimum required AWS actions and resources
- An unannotated or mismatched service account cannot receive the role

## Validation

Run the IAM Rego policy checks, test against both valid and invalid plan fixtures, and run the Python property tests. Never test IAM by placing long-lived AWS credentials in a pod or repository.
