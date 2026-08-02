# Kubernetes admission policies

This directory contains the Gatekeeper ConstraintTemplates and Constraints delivered through ArgoCD. The baseline rejects privileged containers, host PID/IPC/network namespaces, and workload objects missing the required `Environment`, `Project`, and `ManagedBy` labels.

## Policy ownership

- `constrainttemplates/` defines reusable Rego-backed constraint kinds.
- `constraints/` selects the enforcement action, match scope, and required labels.
- `conformance/` contains offline policy tests and invariant rules.

The policy AppProject must retain explicit cluster-resource permissions for the Gatekeeper CRDs and webhook resources. The security child Application syncs policy state after the controller is installed.

## Required behavior

Compliant workloads are admitted. Non-compliant workloads are rejected with an identifiable violation. If the Gatekeeper webhook cannot evaluate a request, the validating webhook must fail closed. Policy changes are Git changes and must reconcile through ArgoCD.

## Validation

Run the Gatekeeper Rego tests, parse every YAML document, run the no-plaintext scanner, and use `gator` or a live Gatekeeper webhook where available. Test both rejected and admitted objects. A static Rego test does not prove webhook availability or API-server admission behavior.

## Change review

Review match kinds, namespaces, enforcement action, required labels, host namespace fields, privileged fields, exemptions, sync ordering, and failure policy. Do not broaden exclusions to make an upstream chart pass without documenting and testing the exception.
