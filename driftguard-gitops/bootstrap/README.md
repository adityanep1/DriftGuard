# GitOps bootstrap

Bootstrap is the controlled handoff from Terraform to ArgoCD. Terraform installs the pinned ArgoCD Helm chart and seeds one Root_Application. The Root_Application reads `bootstrap/children` from the Config_Repo and discovers the direct child Applications.

## Files

- `root-app.yaml` — the single seed Application created by Terraform.
- `children/projects-app.yaml` — AppProjects and declarative ArgoCD configuration.
- `children/applicationsets-app.yaml` — platform/workload/observability ApplicationSets.
- `children/security-app.yaml` — Gatekeeper policies and constraints.
- `children/secrets-app.yaml` — ExternalSecret and SecretStore references.
- `children/observability-config-app.yaml` — collector, dashboards, and SLO configuration.
- `children/karpenter-nodepool-app.yaml` — Karpenter capacity resources.
- explicit add-on child Applications — configured chart sources such as Falco/Falcosidekick.

## Safety invariants

The root source path must remain valid and reachable. Children must use approved AppProjects, explicit source repositories, explicit destination namespaces, sync waves, retry limit 5, and pruning disabled by default. Do not add a child that points to a plaintext secret or an unreviewed external repository.

## Bootstrap workflow

1. Confirm the Config_Repo URL, revision, branch, and placeholder replacement.
2. Apply Terraform `addons-bootstrap` only after EKS and provider configuration are ready.
3. Wait for all ArgoCD control-plane components to become Ready within 600 seconds.
4. Verify Root_Application sync/health and all direct child Applications within 180 seconds.
5. Inspect generated ApplicationSets and add-on health before deploying workloads.

## Failure handling

If ArgoCD is unhealthy, do not create or trust the Root_Application. If the repository is unreachable or a child is invalid, preserve existing healthy children, inspect Application conditions/events, and repair Git. Do not repair bootstrap by manually applying day-2 manifests.
