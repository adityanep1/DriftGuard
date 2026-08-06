# GitOps Test Suite

This directory contains the automated tests that verify the safety invariants of the DriftGuard GitOps configuration. The tests run offline (no cluster needed) and validate that the YAML manifests in this repository follow the security and operational rules the platform depends on.

## Prerequisites

You will need:

- Python 3.11 or later
- `pytest` (test runner)
- `hypothesis` (property-based testing, optional but recommended)
- `pyyaml` (YAML parsing)

If hypothesis is not installed, the tests fall back to deterministic iteration, so you can still run the suite on a minimal toolchain.

## Running the tests

From the `driftguard-gitops/` directory:

```bash
python -m pytest tests -q
```

This runs all three test modules and should complete in a few seconds. You will see around 12-14 tests pass depending on whether hypothesis is available (it changes how property tests are structured).

## What each test file covers

### test_argocd_invariants.py

This is the core safety test. It verifies two critical properties using property-based testing (with a deterministic fallback when hypothesis is not installed):

- **Property 7 (Pruning is opt-in):** Automated pruning must never be enabled on an Application unless that Application carries the explicit annotation `driftguard.io/prune-approved: "true"`. This prevents accidental resource deletion during sync.
- **Property 8 (Project binding):** Every Application must belong to one of the approved default-deny AppProjects (`platform-addons`, `observability`, `security`, `workloads`). Bootstrap Applications are exempted by name.

Beyond the property tests, `test_repository_applications_obey_invariants` scans every `.yaml` file in the entire repository, finds all Application documents, and verifies that each one passes both the pruning safety check and the project binding check. This is your "no Application slipped through" safety net.

### test_no_plaintext_secrets.py

This module imports the secret scanner script (`scripts/scan_no_plaintext_secrets.py`) and tests it against known inputs:

- Verifies that legitimate references (encrypted values like `ENC[AES256,...]`, environment variable references like `${SECRET_REF}`, remote references, and placeholder markers) are accepted without false positives.
- Confirms that AWS access keys (`AKIA...`) and PEM private key blocks are rejected.
- Confirms that plaintext credential assignments (like `password: some-value`) are caught.
- Uses hypothesis (when available) to fuzz-test both the acceptance and rejection paths with randomized inputs.

### test_rollouts_manifests.py

This module validates the progressive delivery configuration:

- Checks that the demo-service Rollout has the correct canary steps: weight progression of 20, 40, 60, 80, 100 with 300-second pauses between each step and 5 analysis checks.
- Validates the analysis templates (`demo-service-error-rate` and `demo-service-p95-latency`): confirms they use Prometheus as the provider, have a 60-second query timeout, allow only 1 failure before aborting, and point to an HTTP Prometheus address.

## The Hypothesis approach

When hypothesis is installed, the property tests generate randomized inputs (random combinations of pruning flags, project names, CIDR lists, credential strings, etc.) and verify the safety invariants hold universally. When hypothesis is not available, the tests iterate through a carefully chosen set of deterministic cases that cover the same logical space. Either way, the safety properties are thoroughly tested.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [Security and validation steering](../../.kiro/steering/30-security-validation.md)
- [Conformance rules](../conformance/README.md)
- [Rollouts analysis templates](../rollouts/README.md)
- [Scripts (secret scanner)](../scripts/README.md)
