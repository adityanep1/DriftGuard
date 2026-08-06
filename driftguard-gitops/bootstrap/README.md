# GitOps Bootstrap

Bootstrap is where Terraform hands control to ArgoCD. This is the bridge between Layer A (infrastructure) and Layer B (GitOps). Terraform installs the pinned ArgoCD Helm chart and creates one Root Application. That Root Application reads from `bootstrap/children/` in this Config Repo and discovers all the direct child Applications that make up the platform.

From that single seed, the entire cluster configuration fans out.

## What is in this directory

| File | Purpose |
|---|---|
| `root-app.yaml` | The single seed Application created by Terraform |
| `children/projects-app.yaml` | AppProjects and declarative ArgoCD configuration |
| `children/applicationsets-app.yaml` | Platform, workload, and observability ApplicationSets |
| `children/security-app.yaml` | Gatekeeper policies and constraints |
| `children/secrets-app.yaml` | ExternalSecret and SecretStore references |
| `children/observability-config-app.yaml` | Collector, dashboards, and SLO configuration |
| `children/karpenter-nodepool-app.yaml` | Karpenter capacity resources |
| Explicit add-on child Applications | Configured chart sources such as Falco/Falcosidekick |

## Safety invariants

The bootstrap tree has strict rules:

- The root source path must remain valid and reachable (if ArgoCD cannot read it, the cluster stops converging).
- Every child must use an approved AppProject with explicit source repos, destination namespaces, and sync waves.
- Retry limit 5 and pruning disabled by default on all children.
- No child should point to a plaintext secret or an unreviewed external repository.

## How the bootstrap workflow works

1. Confirm the Config Repo URL, revision, branch, and that all placeholder values have been replaced.
2. Apply Terraform's `addons-bootstrap` module only after EKS and provider configuration are ready.
3. Wait for all ArgoCD control-plane components to become Ready (up to 600 seconds).
4. Verify that the Root Application syncs and is healthy, and that all direct child Applications come up within 180 seconds.
5. Inspect the generated ApplicationSets and add-on health before deploying any workloads.

## What to do when things go wrong

If ArgoCD is unhealthy, do not create or trust the Root Application. If the repository is unreachable or a child definition is invalid, preserve existing healthy children, inspect Application conditions and events, and fix the issue in Git. Do not attempt to repair the bootstrap by manually applying day-2 manifests; the whole point is that Git is the single source of truth.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [GitOps and Kubernetes steering](../../.kiro/steering/20-gitops-kubernetes.md)
- [AppProject security](../projects/README.md)
- [ArgoCD bootstrap module (Terraform)](../../driftguard-infra/modules/addons-bootstrap/README.md)
