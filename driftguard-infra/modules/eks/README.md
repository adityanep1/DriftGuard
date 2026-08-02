# EKS Module

This module creates an EKS control plane with encrypted Kubernetes secrets, an OIDC provider for IRSA (IAM Roles for Service Accounts), and managed node groups placed exclusively in private subnets.

## Key design decisions

- **Kubernetes version** is an explicit `1.XX` minor version. No floating or "latest" references.
- **API access** is restricted by `public_access_cidrs`, which must be non-empty and must never contain `0.0.0.0/0` or `::/0`. The API endpoint is never configured as unrestricted.
- **Node groups** receive explicit minimum, maximum, and desired sizes. They are placed only in the private subnets you provide.
- **Secrets encryption** uses a KMS-backed envelope encryption configuration so etcd data is protected at rest.
- **OIDC provider** is created for IRSA, allowing workloads to assume IAM roles through service account annotations.

## How outputs work

The connection outputs (cluster endpoint, CA certificate, OIDC ARN and issuer) come directly from the EKS resources. Terraform propagates unknown values during creation, which means these outputs are not usable if the cluster resource fails to create. This is intentional fail-safe behavior: you cannot configure downstream providers against a broken cluster.

## Provider configuration

This module does not declare its own providers. Callers (live environment roots, module examples) must pass the AWS provider. This keeps the module reusable and avoids hidden provider assumptions.

The module accepts only the inputs it consumes. The VPC identity is represented by the supplied private subnet IDs and cluster security groups, not by a VPC ID lookup.

## Validation

Run Terraform formatting, initialization with `-backend=false`, `terraform validate`, and the security/conformance tools. The Python test suite (`test_security_modules.py`) verifies that the module source declares the expected shape: pinned version, private subnet placement, secrets encryption, restricted API access, and OIDC provider creation.
