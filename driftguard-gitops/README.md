# DriftGuard Config_Repo

This repository is the declarative Layer B control plane. ArgoCD pulls it and reconciles Kubernetes state; Terraform only installs ArgoCD and seeds the Root_Application.

## Ownership boundary

- `bootstrap/` contains the Root_Application and its direct child Applications.
- `projects/` defines AppProject source, destination, and resource boundaries plus ArgoCD configuration/RBAC.
- `applicationsets/` generates pinned Helm Applications and environment workload Applications.
- `addons/` contains add-on-owned manifests such as the Karpenter NodePool.
- `policies/` contains Gatekeeper templates and constraints.
- `observability/` contains collectors, dashboards, SLO rules, and chart-owned configuration.
- `secrets/` contains references only: SecretStore and ExternalSecret objects, never secret values.
- `workloads/` contains Kustomize bases and environment overlays for deployable services.
- `optional/` contains features deliberately outside the default Root_Application path, including Crossplane.

## ArgoCD invariants

Every Application uses an approved default-deny AppProject. Source repositories, destination namespaces, and allowed cluster resources are explicit. Automated pruning is disabled by default; intentional pruning requires the per-Application approval marker checked by `conformance/argocd.rego`.

Use sync waves to express dependency order. Keep `selfHeal`, retry limit 5, and `CreateNamespace=true` where appropriate. Do not use a direct `kubectl apply` workflow for normal delivery. Change Git, let ArgoCD reconcile, and inspect Application history/status.

## Pinned dependencies

Third-party chart versions are recorded in `versions.yaml` and repeated in Application/ApplicationSet sources because ArgoCD consumes those declarations directly. Never replace a tested version with `latest`, a floating branch, or an unreviewed chart repository.

## Local checks

From this directory:

```powershell
python scripts/scan_no_plaintext_secrets.py .
python -m pytest tests -q
```

When installed, also run conftest over policy inputs and kubeconform over every YAML document. `promtool test rules observability/slo/demo-service-slo-test.yaml` validates the SLO fixture. YAML parsing and repository tests do not prove controller runtime behavior.

## Release and rollback

CI updates image tags through a Config_Repo commit after tests, image scanning, and ECR publication succeed. To roll back, revert the desired Git commit or image tag and let ArgoCD reconcile; do not patch the live workload as the normal recovery mechanism. For a failed sync, preserve the Application status and history before changing the desired state.

## Deployment blockers

Replace `your-org` repository URLs, example domains, account IDs, and placeholder ACM/IRSA values before bootstrapping. Crossplane remains disabled until both optional Application manifests are deliberately promoted into the Root_Application child path.
