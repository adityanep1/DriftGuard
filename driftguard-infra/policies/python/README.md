# Property-Based Test Framework

This directory contains the pure Python conformance functions and their accompanying test suites. Together, they form the offline verification layer for DriftGuard's infrastructure safety rules. The idea is simple: encode the platform's security invariants as pure functions, then test them exhaustively using property-based testing.

## How it fits together

The conformance functions are the "rules engine" and the tests prove those rules work correctly across a wide range of inputs. CI runs these tests on every pull request, so a broken safety rule never reaches production.

## Source modules

### conformance.py

This module contains pure functions (no side effects, no network calls) that enforce infrastructure safety rules:

- **`has_complete_required_tags(tags)`** - Validates that all three required tags (`Environment`, `Project`, `ManagedBy`) are present and non-empty.
- **`security_group_rule_is_safe(rule)`** - Rejects security group rules that open administrative ports (22/SSH, 3389/RDP) to the entire internet (`0.0.0.0/0` or `::/0`).
- **`eks_api_allowlist_is_safe(cidrs)`** - Ensures the EKS API server access list is non-empty, contains only valid CIDR notation, and never includes unrestricted addresses.
- **`iam_statement_is_safe(statement)`** - Rejects IAM statements that combine wildcard actions with wildcard resources (the "admin-by-accident" pattern).
- **`irsa_trust_is_scoped(trust)`** - Validates that an IRSA trust policy binds to exactly one concrete namespace/service-account pair (no wildcards, no multiple subjects).
- **`validate_max_node_count(max_node_count)`** - Validates the environment-wide node cap is a whole number between 1 and 1000.
- **`scaling_request_is_allowed(requested, max)`** - Checks whether a scaling request falls within the validated cap.
- **`clamp_node_count(requested, max)`** - Clamps a scaling result so it never exceeds the cap, raising an error for invalid inputs.

### ci_logic.py

This module mirrors the CI pipeline's stage-gating decisions as testable pure functions:

- **`stage_plan(test_passed, high_or_critical_findings, push_succeeded)`** - Returns the ordered list of CI stages that are allowed to run. If tests fail, the pipeline stops before scanning. If the scan finds HIGH/CRITICAL vulnerabilities, it stops before publishing. The GitOps config update only happens after a successful ECR push.
- **`drift_status(exit_code)`** - Maps Terraform's detailed exit codes to human-readable drift statuses. Exit code 0 means no drift, exit code 2 means drift detected, and anything else is treated as a failed check (fail-closed behavior).

## Test files

### test_conformance.py

Property tests for tag validation (Property 1) and security group safety (Property 5). Uses hypothesis to generate random tag dictionaries and random port/CIDR combinations, verifying that the functions correctly classify every input. Falls back to deterministic iteration when hypothesis is not installed.

### test_ci_logic.py

Deterministic tests for the CI stage gate logic. Verifies that the pipeline stops at the correct stage for each failure scenario and that drift exit codes are mapped fail-closed.

### test_networking_static.py

Reads the actual Terraform source files for the networking module and verifies the expected resource structure: two-tier routing (public via IGW, private via NAT), production NAT-per-AZ enforcement, private subnet placement for worker nodes, and required tags on all resources.

### test_node_cap.py

Property tests for the node count validation and clamping logic (Property 10). Verifies that scaling requests are correctly allowed or denied based on the cap, that clamping never exceeds the maximum, and that invalid inputs (booleans, floats, strings, out-of-range values) are properly rejected.

### test_platform_composition.py

Offline checks that verify the infrastructure composition:
- DNS module has validation timeout and optional ALB records
- ArgoCD bootstrap uses atomic install with wait and depends on the Helm release
- Each environment root composes networking, EKS, IAM, and ECR modules with distinct backend keys

### test_security_modules.py

Property tests for EKS API allowlist safety (Property 4), IAM statement safety (Property 2), and IRSA trust scoping (Property 3). Also includes static checks that verify the EKS module declares a pinned, private, encrypted cluster shape, and that the IAM and ECR modules enforce their security contracts.

## Running the tests

From the `driftguard-infra/` directory:

```bash
python -m pytest policies/python/ -q
```

All tests should pass in a few seconds. No AWS credentials, Terraform providers, or cluster access is required.

## The Hypothesis approach

When hypothesis is available, property tests generate randomized inputs and verify the safety invariants hold for every combination. This catches edge cases that hand-written test cases might miss. When hypothesis is not installed (for example, on a minimal CI runner), the tests fall back to deterministic iteration over carefully chosen representative inputs. Both approaches cover the same logical properties; hypothesis just explores the space more thoroughly.
