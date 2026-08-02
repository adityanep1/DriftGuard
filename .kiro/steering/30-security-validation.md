---
inclusion: fileMatch
fileMatchPattern: 'driftguard-infra/**'
---

# Security, policy, and validation rules

## Fail-closed posture
A missing security tool is a blocked gate, not a passing gate. Validation scripts must fail with the missing command and must not print that validation completed. A skipped runtime test must identify the missing cluster, controller, provider, or tool.

## Terraform plan policy
Conftest/OPA policies consume normalized Terraform plan JSON. Rules must inspect the resource type and actual `change.after` values, not merely filenames. Keep positive and negative fixtures. The valid fixture must pass; the invalid fixture must fail for the intended reasons.

## IAM review
- Classify an IAM role as IRSA only when its trust policy contains `sts:AssumeRoleWithWebIdentity`.
- Require one concrete `system:serviceaccount:<namespace>:<service-account>` subject per IRSA role.
- Reject wildcard action plus wildcard resource. A wildcard in only one dimension requires a separate documented justification.
- Review trust principals, conditions, external IDs, permissions boundaries, and resource scope.

## Kubernetes admission review
Gatekeeper policies must cover privileged containers, host namespaces, required labels, and webhook failure behavior. Test both rejected and compliant objects. If evaluation cannot complete, the expected result is rejection with an observable admission error.

## Secret scanning
The scanner must reject AWS access keys, private-key PEM blocks, plaintext credential assignments, and high-entropy token-like material. It must allow references, ciphertext markers, ExternalSecret remote references, and documented placeholders. Never weaken a scanner pattern to accommodate a real secret.

## CI/CD security
Use GitHub OIDC and short-lived roles. Do not add static AWS keys. Image scans must block HIGH/CRITICAL findings before push. Push retries must be bounded. Config_Repo updates must be Git commits; no normal workflow may contain `kubectl apply`.

## Evidence standards
Record the command, target path/context, tool version, exit code, and meaningful result for each security gate. Do not claim `promtool`, `kubeconform`, `tfsec`, `Checkov`, `conftest`, or cluster behavior unless that command actually ran successfully.
