# Kubernetes Admission Policies

This directory contains the Gatekeeper ConstraintTemplates and Constraints that ArgoCD delivers to the cluster. These policies form the admission control layer: they define what workloads are allowed to run and reject anything that does not meet the baseline security requirements.

The baseline rejects privileged containers, host PID/IPC/network namespace access, and workloads missing the required `Environment`, `Project`, and `ManagedBy` labels.

## Directory structure

| Path | What it contains |
|---|---|
| `constrainttemplates/` | Reusable Rego-backed constraint kinds (the "what to check" definitions) |
| `constraints/` | Enforcement action selection, match scope, and required labels (the "where and how to enforce" rules) |
| `conformance/` | Offline policy tests and invariant rules (pre-merge safety checks) |

## How it works in practice

When a workload is submitted to the Kubernetes API, the Gatekeeper webhook evaluates it against the active constraints. Compliant workloads are admitted; non-compliant ones are rejected with an identifiable violation message. If the webhook itself cannot evaluate a request (for example, if Gatekeeper is down), the validating webhook fails closed, meaning the request is denied rather than accidentally admitted.

The `security` AppProject must retain explicit cluster-resource permissions for the Gatekeeper CRDs and webhook resources. The security child Application syncs policies after the Gatekeeper controller is installed.

## Validation

For offline checks:

```bash
# Run Gatekeeper Rego tests (when gator or conftest is available)
conftest test --policy conformance .

# Parse every YAML document and run secret scanning
python scripts/scan_no_plaintext_secrets.py .
python -m pytest tests -q
```

Test both rejected and admitted objects. A static Rego test proves policy logic but does not prove webhook availability or API server admission behavior in a running cluster.

## Review checklist for policy changes

When reviewing a policy change, check: match kinds, namespaces, enforcement action, required labels, host namespace fields, privileged fields, exemptions, sync ordering, and failure policy. Do not broaden exclusions just to make an upstream chart pass without documenting and testing the exception.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [Security and validation steering](../../.kiro/steering/30-security-validation.md)
- [Conformance rules](../conformance/README.md)
- [AppProject security](../projects/README.md)
