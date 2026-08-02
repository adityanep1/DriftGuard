# EKS module

This module creates an EKS control plane, encrypted Kubernetes secrets, an OIDC provider for IRSA, and managed node groups placed only in the supplied private subnet IDs.

`kubernetes_version` is an explicit `1.XX` minor version. `public_access_cidrs` must be non-empty and must not contain `0.0.0.0/0` or `::/0`; the API endpoint is never configured as unrestricted. Every managed node group receives explicit minimum, maximum, and desired sizes.

The connection outputs are direct values from the EKS resources. Terraform propagates unknown values during creation and does not publish usable connection outputs when the cluster resource fails, which is the module's fail-safe behavior. No provider configuration is declared here; callers provide the AWS provider, including module examples and environment roots. The module accepts only inputs it consumes; the VPC identity is represented by the supplied private subnet IDs and cluster security groups.
