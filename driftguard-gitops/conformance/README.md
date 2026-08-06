# GitOps Conformance

Conformance testing protects the ArgoCD safety boundary before a manifest ever reaches a cluster. Think of it as a pre-flight check: if something violates the platform's rules, it gets caught here in CI, not after it has been deployed.

The conformance rules cover opt-in pruning and Application-to-AppProject binding. Gatekeeper Rego tests cover the baseline admission decisions (privileged containers, host namespaces, required labels).

## The invariants we enforce

- Every non-bootstrap Application belongs to an approved default-deny AppProject.
- Source repositories, destination namespaces, and cluster resources are explicitly enumerated in each project.
- Automated pruning is false by default. An Application can only enable pruning if it carries the annotation `driftguard.io/prune-approved: "true"`.
- No global or default pruning switch may silently enable deletion across Applications.
- Gatekeeper rejects privileged containers, host namespace access, and missing required labels. It fails closed when admission evaluation cannot complete.

## Running local checks

From `driftguard-gitops/`:

```bash
# Run the test suite (verifies all invariants against the actual YAML in this repo)
python -m pytest tests -q

# Run the secret scanner
python scripts/scan_no_plaintext_secrets.py .

# When conftest is installed
conftest test --policy conformance .

# When kubeconform is installed
kubeconform -strict -summary <yaml-files>
```

Conftest and kubeconform are required gates in CI. An unavailable binary is a blocked validation, not a pass.

## Evidence for policy changes

When proposing a change to a conformance rule, include:

- The affected manifest scope (which Applications or resources change)
- An allowed fixture (a manifest that should pass)
- A rejected fixture (a manifest that should fail)
- The expected denial message
- The command and tool version used for testing

Runtime admission behavior still requires testing against a real Gatekeeper webhook in a cluster.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [Security and validation steering](../../.kiro/steering/30-security-validation.md)
- [Admission policies](../policies/README.md)
- [Test suite](../tests/README.md)
