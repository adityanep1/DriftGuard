# Terraform Conformance Policies

The Rego policies in this directory consume Terraform plan JSON (or the small normalized policy inputs used by local tests) and enforce infrastructure safety rules. They operate fail-closed: missing required tags, violated provider constraints, improperly isolated backend keys, over-broad security groups, and networking shape violations all block the plan.

## How to use them

When conftest is installed:

```bash
terraform show -json plan.tfplan > plan.json
conftest test --policy policies plan.json
```

## Test fixtures

The offline fixtures under `policies/tests/` exercise both sides of the security gate:

- `valid-plan.json` must pass all policies
- `invalid-security-plan.json` must fail because it contains an over-broad IAM statement, an unscoped IRSA trust, and non-compliant ECR settings

The IAM trust rule specifically classifies only roles containing `sts:AssumeRoleWithWebIdentity` as IRSA roles. This means ordinary EKS control-plane and node roles are not incorrectly subjected to service-account scoping checks.

## Python conformance helpers

The `policies/python/` directory contains pure Python implementations of the same safety rules, tested with hypothesis property-based testing. See `policies/python/README.md` for full details on the test framework.

## Running the Python tests

```bash
cd driftguard-infra
python -m pytest policies/python/ -q
```

These tests run offline and validate tag completeness, security group safety, EKS API allowlists, IAM statement safety, IRSA trust scoping, node count caps, CI stage gating, and module composition.

## Related documentation

- [Infrastructure README (parent)](../README.md)
- [Python conformance helpers](python/README.md)
- [Module catalog](../modules/README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [Security and validation steering](../../.kiro/steering/30-security-validation.md)
