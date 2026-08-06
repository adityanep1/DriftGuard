---
inclusion: fileMatch
fileMatchPattern: '{driftguard-infra/policies/**,driftguard-gitops/conformance/**,driftguard-gitops/policies/**,driftguard-gitops/secrets/**,driftguard-gitops/scripts/**,driftguard-infra/modules/iam/**,driftguard-infra/modules/github-oidc/**}'
---

# Security, Policy, and Validation Rules

This guide covers the security posture, policy enforcement framework, secret scanning, IAM review process, and evidence standards used throughout DriftGuard. It activates when you touch policy files, conformance definitions, secrets configuration, validation scripts, or identity modules.

## Fail-Closed Posture

The most important principle in DriftGuard's security model: a missing security tool is a blocked gate, not a passing gate. Validation scripts must fail with a clear error when the required tool is absent and must not print "validation completed" or exit 0. A skipped runtime test must explicitly identify the missing cluster, controller, provider, or tool.

This means:
- If `conftest` is not installed, policy checks fail (they do not silently pass)
- If `kubeconform` is not installed, schema validation reports "blocked" (not "passed")
- If the cluster is unreachable, admission tests report the exact connectivity issue

## Rego Policy Framework

The infrastructure policies live in [driftguard-infra/policies/](../../driftguard-infra/policies/) and consume normalized Terraform plan JSON. Each policy file targets a specific security domain:

| Policy file | Domain | What it checks |
|---|---|---|
| [iam.rego](../../driftguard-infra/policies/iam.rego) | IAM least privilege | Rejects wildcard action + wildcard resource combinations |
| [eks.rego](../../driftguard-infra/policies/eks.rego) | EKS hardening | Requires restricted CIDR allowlist, secrets encryption |
| [ecr.rego](../../driftguard-infra/policies/ecr.rego) | Container registry | Enforces encryption, scan-on-push, private repos |
| [tags.rego](../../driftguard-infra/policies/tags.rego) | Resource tagging | Requires Environment, Project, ManagedBy on all taggable resources |
| [security_group.rego](../../driftguard-infra/policies/security_group.rego) | Network security | Validates security group rules against unrestricted access |
| [backend_isolation.rego](../../driftguard-infra/policies/backend_isolation.rego) | State isolation | Ensures environment-isolated state backend keys |
| [provider_pinning.rego](../../driftguard-infra/policies/provider_pinning.rego) | Version pinning | Verifies providers are pinned to specific constraints |

Policies are evaluated using conftest 0.56.0 against plan JSON:

```bash
conftest test plan.json -p policies/
```

## Policy Test Fixtures

Test fixtures in [policies/tests/](../../driftguard-infra/policies/tests/) provide both valid and invalid plan samples. The valid fixture must pass all policies; the invalid fixture must fail for the intended reasons. When adding a new policy rule, always add both fixture types demonstrating the pass and fail cases.

## Python Conformance Tests

The [Python policy tests](../../driftguard-infra/policies/python/README.md) use pytest with hypothesis for property-based testing. They validate that Rego policies correctly accept compliant plans and reject non-compliant ones without requiring a live Terraform deployment. Run them from the sub-project root:

```bash
cd driftguard-infra
python3 -m pytest policies/python/ -q
```

## GitOps Conformance

The [conformance directory](../../driftguard-gitops/conformance/README.md) contains Gatekeeper ConstraintTemplates and Constraints that enforce cluster-level invariants at admission time. These policies cover:

- Privileged container rejection
- Host namespace access prevention
- Required label enforcement
- Webhook failure behavior (fail-closed for security-critical paths)

Test both rejected and compliant objects. If evaluation cannot complete (Gatekeeper is unavailable), the expected result is rejection with an observable admission error, not silent acceptance.

## Secret Scanning

The [secret scanner](../../driftguard-gitops/scripts/scan_no_plaintext_secrets.py) runs as part of the GitOps validation pipeline and must reject:

- AWS access keys (patterns matching `AKIA...`)
- Private-key PEM blocks (`-----BEGIN RSA PRIVATE KEY-----` and similar)
- Plaintext credential assignments (`password=`, `secret_key=` with non-placeholder values)
- High-entropy token-like material

It must allow (not false-positive on):
- ExternalSecret remote references
- Ciphertext markers and encrypted value placeholders
- Documented placeholder values like `your-secret-here` or `CHANGE_ME`
- Reference patterns pointing to AWS Secrets Manager or Parameter Store ARNs

Never weaken a scanner pattern to accommodate a real secret. If a legitimate value triggers the scanner, restructure the configuration to use an ExternalSecret reference instead.

## IAM Review Process

When creating or modifying IAM roles and policies, apply this review framework:

**IRSA classification:** A role qualifies as IRSA only when its trust policy contains `sts:AssumeRoleWithWebIdentity` with the EKS OIDC provider as the federated principal.

**Subject binding:** Each IRSA role must bind exactly one concrete `system:serviceaccount:<namespace>:<service-account>` subject. Multiple service accounts sharing a role indicates a boundary violation.

**Permission review:** Reject wildcard action plus wildcard resource. A wildcard in only one dimension (e.g., `s3:*` on a specific bucket ARN) requires documented justification in the commit message.

**Full review scope:** Trust principals, conditions, external IDs, permissions boundaries, resource scope, and session duration must all be reviewed for new IAM resources.

The [iam module](../../driftguard-infra/modules/iam/README.md) and [github-oidc module](../../driftguard-infra/modules/github-oidc/README.md) implement these patterns.

## GitHub OIDC for CI

The [github-oidc module](../../driftguard-infra/modules/github-oidc/README.md) establishes OIDC federation between GitHub Actions and AWS. This eliminates static AWS credentials in CI:

- GitHub Actions assumes a short-lived IAM role via OIDC token exchange
- The trust policy restricts assumption to specific repositories and branches
- No static `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` values exist in workflow files or secrets

When reviewing CI workflows, verify they use `aws-actions/configure-aws-credentials` with `role-to-assume` and do not reference static key secrets.

## CI/CD Security Constraints

These rules apply to all CI workflows in [.github/workflows/](../../.github/workflows/):

- Use GitHub OIDC and short-lived roles (never static AWS keys)
- Image scans must block HIGH/CRITICAL findings before push to ECR
- Push retries must be bounded (not infinite loops)
- Config_Repo updates must be Git commits; no normal workflow may contain `kubectl apply`
- Workflow permissions should follow least privilege (`permissions:` block with specific scopes)

## Evidence Standards

When claiming a security check has passed, record:

1. The exact command that ran
2. The target path or context
3. The tool version
4. The exit code
5. Meaningful output or summary of results

Do not claim `promtool`, `kubeconform`, `tfsec`, `Checkov`, `conftest`, or cluster behavior unless that command actually ran successfully and produced verifiable output. A missing tool is a blocked gate, documented as such, not a passing check.

## Related Steering Files

- [10-terraform-aws.md](10-terraform-aws.md): Provider rules, module security invariants, and the full validation workflow
- [20-gitops-kubernetes.md](20-gitops-kubernetes.md): Admission policies, resource quality, and GitOps validation
- [00-driftguard-engineering.md](00-driftguard-engineering.md): The non-negotiable safety gates that apply everywhere
