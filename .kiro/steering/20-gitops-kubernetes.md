---
inclusion: fileMatch
fileMatchPattern: 'driftguard-gitops/**'
---

# GitOps and Kubernetes implementation rules

## Ownership and delivery
- The Config_Repo is the source of truth for Kubernetes desired state.
- Terraform seeds ArgoCD; ArgoCD discovers the Root_Application children and owns day-2 resources.
- CI must update image tags or configuration through Git commits. Do not add direct imperative deployment steps to application CI.
- Use an Application, ApplicationSet, Kustomize overlay, Helm value, or declarative policy instead of a shell-side mutation.

## ArgoCD safety
- Every Application binds to an explicitly approved default-deny AppProject.
- Enumerate source repositories, destination clusters, namespaces, and allowed cluster resources. Never use wildcard project permissions to make a sync convenient.
- Automatic pruning is disabled by default. Enabling pruning requires a per-Application review marker and must be narrowly justified.
- Preserve `selfHeal`, retry limit 5, `CreateNamespace=true` where appropriate, and explicit sync waves.
- Keep reconciliation and health timeouts within the specification: repository reconciliation at most 180 seconds and installation timeouts at most 600 seconds.

## Resource quality
- Use stable names, labels, selectors, namespaces, ownership labels, and sync-wave annotations.
- Workloads need readiness/liveness behavior, resource requests and limits, non-root execution where supported, and observable metrics/logs/traces.
- Admission policies must fail closed for security-critical evaluation failures.
- ExternalSecret manifests contain references only. Never put a secret value in a manifest, Helm value, example, test fixture, or annotation.
- Optional or billable features, including Crossplane, must be outside the default Root_Application path or guarded by an explicit enablement procedure.

## Progressive delivery and observability
- Rollouts must specify the stable service, canary/blue-green behavior, analysis templates, pause windows, rollback behavior, and metric failure behavior.
- Prometheus rules need explicit recording expressions, alert thresholds, windows, labels, and rule tests.
- Telemetry pipelines must preserve unaffected signals when one backend fails and must surface insufficient telemetry as unknown rather than healthy.

## Validation workflow
Parse every YAML document, run repository tests, scan for plaintext secrets, run kubeconform/conftest when installed, and inspect generated Application/project relationships. Runtime claims require an actual cluster test with timestamps and observed statuses; manifest presence alone is not runtime evidence.

