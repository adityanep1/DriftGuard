# GitOps conformance

Conformance protects the ArgoCD safety boundary before a manifest reaches a cluster. The rules cover opt-in pruning and Application-to-AppProject binding; Gatekeeper Rego tests cover baseline admission decisions.

## Invariants

- Every non-bootstrap Application belongs to an approved default-deny AppProject.
- Source repositories, destination namespaces, and cluster resources are explicitly enumerated.
- Automated pruning is false unless the individual Application carries `driftguard.io/prune-approved: "true"`.
- No global/default pruning switch may silently enable deletion.
- Gatekeeper rejects privileged containers, host namespaces, and missing required labels; it fails closed when admission evaluation cannot complete.

## Local checks

From `driftguard-gitops/`:

```powershell
python -m pytest tests -q
python scripts/scan_no_plaintext_secrets.py .
conftest test --policy conformance .
```

Use `kubeconform -strict -summary` over all YAML files when installed. Conftest and kubeconform are required gates in CI; an unavailable binary is a blocked validation, not a pass.

## Review evidence

For a policy change, include the affected manifest scope, an allowed fixture, a rejected fixture, the expected denial message, and the command/tool version used. Runtime admission behavior still requires a real Gatekeeper webhook test.
