# Terraform conformance policies

The Rego policies in this directory consume Terraform plan JSON or the small normalized policy inputs used by the local tests. They fail closed for missing required tags, provider constraints, isolated backend keys, administrative security-group exposure, and networking shape violations.

Example (when conftest is installed):

```text
terraform show -json plan.tfplan > plan.json
conftest test --policy policies plan.json
```

The offline fixtures under `policies/tests/` exercise both sides of the security gate:
`valid-plan.json` must pass, while `invalid-security-plan.json` must fail because it contains
an over-broad IAM statement, an unscoped IRSA trust, and non-compliant ECR settings. The IAM
trust rule only classifies roles containing `sts:AssumeRoleWithWebIdentity` as IRSA roles, so
ordinary EKS control-plane and node roles are not incorrectly subjected to service-account checks.
