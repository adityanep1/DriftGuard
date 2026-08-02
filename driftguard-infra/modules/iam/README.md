# IAM and IRSA module

Creates one IAM role per workload that needs AWS access through IAM Roles for Service Accounts (IRSA). Each trust policy binds to the supplied EKS OIDC provider and exactly one concrete Kubernetes namespace/service-account pair.

## Inputs

Provide `name_prefix`, `environment`, `project`, the EKS `cluster_oidc_provider_arn`, the HTTPS `oidc_issuer_url`, and a `workloads` map. Each workload must contain a namespace, service account, and at least one policy statement with non-empty action and resource sets.

Resources must be explicit ARNs or an intentionally reviewed single-dimension wildcard. A wildcard action combined with a wildcard resource is rejected before apply. Duplicate namespace/service-account bindings are rejected.

## Outputs

`role_arns`, `role_names`, and `service_account_bindings`, keyed by workload name.

## Security review

Confirm the trust principal is the intended OIDC provider, the `sub` condition is concrete, the audience condition is present, and permissions are scoped to the minimum AWS actions/resources. An unannotated or mismatched service account must not receive the role.

## Validation

Run the IAM Rego policy, valid/invalid plan fixtures, Python property tests, and a Terraform plan review. Never test by placing long-lived AWS credentials in a pod or repository.
