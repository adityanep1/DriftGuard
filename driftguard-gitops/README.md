# DriftGuard Config Repo

This is the declarative control plane for everything running inside Kubernetes. ArgoCD continuously pulls from this repository and reconciles cluster state to match what is declared here. Terraform only installs ArgoCD and seeds the Root Application; after that, this repo is the single source of truth for the cluster.

If you want to change what is running in the cluster, you change it here in Git. ArgoCD takes care of the rest.

## How the ownership boundary works

Each directory in this repository serves a specific role in the GitOps delivery model:

| Path | What it controls |
|---|---|
| `bootstrap/` | Root Application and its direct child Applications (the ArgoCD discovery tree) |
| `projects/` | AppProject security boundaries, ArgoCD declarative configuration, and RBAC |
| `applicationsets/` | Templated Application generators for add-ons, observability, and workloads |
| `addons/` | Platform add-on manifests like Karpenter NodePool configuration |
| `policies/` | Gatekeeper ConstraintTemplates and Constraints for admission control |
| `observability/` | Collectors, dashboards, SLO recording rules, and chart-owned config |
| `secrets/` | SecretStore and ExternalSecret references only (never actual secret values) |
| `workloads/` | Kustomize bases and environment overlays for deployable services |
| `rollouts/` | Argo Rollouts analysis templates for progressive delivery |
| `optional/` | Features outside the default Root Application path (e.g., Crossplane) |
| `conformance/` | Offline policy tests and invariant rules for pre-merge validation |
| `scripts/` | Secret scanner and validation utilities |
| `tests/` | Automated test suite (see `tests/README.md`) |

## ArgoCD safety invariants

The platform enforces several non-negotiable rules:

- Every Application uses an approved, default-deny AppProject. Source repos, destination namespaces, and allowed cluster resources are explicitly enumerated.
- Automated pruning is disabled by default. Intentional pruning requires the per-Application annotation `driftguard.io/prune-approved: "true"`, which is checked by the conformance policy.
- Sync waves express dependency order (controllers before dependents, CRDs before instances).
- Self-heal and retry (limit 5) keep Applications converging. `CreateNamespace=true` is used where appropriate.
- The normal delivery mechanism is always "change Git, let ArgoCD reconcile." Direct `kubectl apply` is not part of the standard workflow.

## Pinned dependencies

Third-party chart versions are recorded in `versions.yaml` and repeated in Application/ApplicationSet source declarations (ArgoCD reads these directly). Never replace a tested version with `latest`, a floating branch, or an unreviewed chart repository.

## Running local checks

From this directory, you can run the secret scanner and the test suite without any cluster access:

```bash
python scripts/scan_no_plaintext_secrets.py .
python -m pytest tests -q
```

When the tools are installed, you can also run:

```bash
conftest test --policy conformance .
kubeconform -strict -summary <yaml-files>
promtool test rules observability/slo/demo-service-slo-test.yaml
```

Keep in mind that YAML parsing and repository tests validate structure and safety rules, but they do not prove controller runtime behavior. You need a real cluster for that.

## Release and rollback

CI updates image tags through a Config Repo commit after tests, image scanning, and ECR publication succeed. The flow is: source tests pass, image is scanned, image is pushed to ECR with the full commit SHA as the tag, then the tag is committed here.

To roll back, revert the Git commit or image tag and let ArgoCD reconcile. Do not patch the live workload directly as a recovery mechanism. For a failed sync, preserve the Application status and history before changing the desired state.

## Before your first deployment

Replace all `your-org` repository URLs, example domains, account IDs, and placeholder ACM/IRSA values before bootstrapping. Crossplane remains disabled until its Application manifests are deliberately promoted into the `bootstrap/children/` path.

## Related documentation

- [Root README](../README.md)
- [Platform requirements](../.kiro/specs/gitops-platform/requirements.md)
- [GitOps and Kubernetes steering](../.kiro/steering/20-gitops-kubernetes.md)
- [CI workflow (ci-gitops.yml)](../.github/workflows/ci-gitops.yml)
- [Pinned versions (versions.yaml)](versions.yaml)
- [Bootstrap and handoff](bootstrap/README.md)
- [AppProject security](projects/README.md)
- [ApplicationSets](applicationsets/README.md)
- [Platform add-ons](addons/README.md)
- [Admission policies](policies/README.md)
- [Conformance rules](conformance/README.md)
- [Observability](observability/README.md)
- [Secrets](secrets/README.md)
- [Workloads (demo-service)](workloads/demo-service/README.md)
- [Progressive delivery (rollouts)](rollouts/README.md)
- [Test suite](tests/README.md)
- [Scripts](scripts/README.md)
- [Optional: Crossplane](optional/crossplane/README.md)
