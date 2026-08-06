---
inclusion: fileMatch
fileMatchPattern: 'driftguard-gitops/**'
---

# GitOps and Kubernetes Implementation Rules

This guide defines how ArgoCD, Kubernetes resources, progressive delivery, and observability work within DriftGuard. It covers the ownership model, safety constraints, resource quality expectations, and validation workflow for everything under the driftguard-gitops sub-project.

## Ownership and Delivery Model

The [driftguard-gitops](../../driftguard-gitops/README.md) directory is the Config_Repo: the single source of truth for all Kubernetes desired state. Terraform seeds ArgoCD via the [addons-bootstrap module](../../driftguard-infra/modules/addons-bootstrap/README.md); from that point forward, ArgoCD discovers child Applications from the [Root Application](../../driftguard-gitops/bootstrap/root-app.yaml) and owns day-2 resources.

**The delivery rule:** CI must update image tags or configuration through Git commits to this repository. No normal workflow may contain `kubectl apply` or any imperative cluster mutation. Use an Application, ApplicationSet, Kustomize overlay, Helm value, or declarative policy instead of a shell-side mutation.

## Repository Structure

| Directory | Purpose | README |
|---|---|---|
| [bootstrap/](../../driftguard-gitops/bootstrap/README.md) | Root Application and child app definitions | Entry point |
| [projects/](../../driftguard-gitops/projects/README.md) | ArgoCD AppProject definitions with default-deny permissions | Access control |
| [applicationsets/](../../driftguard-gitops/applicationsets/) | ApplicationSet generators for multi-env app creation | Templating |
| [addons/](../../driftguard-gitops/addons/README.md) | Platform add-ons (Karpenter, ALB controller, External Secrets, Gatekeeper, Falco) | Cluster services |
| [conformance/](../../driftguard-gitops/conformance/README.md) | Gatekeeper constraints and constraint templates | Policy enforcement |
| [observability/](../../driftguard-gitops/observability/README.md) | LGTM stack (Prometheus, Loki, Tempo, Grafana), SLO definitions | Telemetry |
| [workloads/demo-service/](../../driftguard-gitops/workloads/demo-service/README.md) | Demo service Kubernetes manifests with Kustomize overlays | Application delivery |
| [rollouts/](../../driftguard-gitops/rollouts/README.md) | Argo Rollouts configuration and AnalysisTemplates | Progressive delivery |
| [secrets/](../../driftguard-gitops/secrets/README.md) | ExternalSecret manifests (references only, never values) | Secret management |
| [scripts/](../../driftguard-gitops/scripts/README.md) | Validation scripts including secret scanner | Tooling |
| [tests/](../../driftguard-gitops/tests/README.md) | Python conformance tests for the GitOps configuration | Quality gates |
| [policies/](../../driftguard-gitops/policies/README.md) | GitOps-layer policy definitions | Governance |

## Pinned Versions

All chart and tool versions come from [versions.yaml](../../driftguard-gitops/versions.yaml). Key versions for this layer:

| Component | Version | Notes |
|---|---|---|
| ArgoCD chart | 7.7.16 | Helm chart for the ArgoCD installation |
| ArgoCD application | v2.13.3 | The ArgoCD server version deployed |
| Argo Rollouts chart | 2.37.8 | Progressive delivery controller |
| Karpenter chart | 1.0.6 | Node autoscaling |
| External Secrets chart | 0.10.0 | Secret synchronization from AWS |
| Gatekeeper chart | 3.16.3 | Policy enforcement |
| kube-prometheus-stack | 65.8.1 | Monitoring foundation |

Update versions.yaml first, then update any manifest or Helm value that references the version, in the same commit.

## ArgoCD Safety Rules

These constraints prevent accidental state corruption or privilege escalation:

**Project isolation:** Every Application binds to an explicitly approved default-deny AppProject defined in [projects/](../../driftguard-gitops/projects/README.md). Enumerate source repositories, destination clusters, namespaces, and allowed cluster resources. Never use wildcard project permissions to make a sync convenient.

**Pruning discipline:** Automatic pruning is disabled by default. Enabling pruning requires a per-Application review marker and must be narrowly justified in the commit message or PR description.

**Reconciliation settings:** Preserve `selfHeal: true`, retry limit 5, `CreateNamespace=true` where appropriate, and explicit sync waves. Repository reconciliation timeout is at most 180 seconds; installation timeouts are at most 600 seconds.

**Optional features:** Crossplane and other billable-resource features remain outside the default Root_Application path or are guarded by an explicit enablement procedure. See [optional/crossplane/](../../driftguard-gitops/optional/crossplane/README.md) for the opt-in pattern.

## Kustomize Label Convention

When adding labels to resources via Kustomize, use the `labels` transformer with `includeSelectors: false`. This applies labels to metadata only, without injecting them into selector fields (which would break rolling updates for Deployments and StatefulSets). Do NOT use `commonLabels`, as it mutates selectors by default.

```yaml
labels:
  - pairs:
      app.kubernetes.io/managed-by: argocd
      app.kubernetes.io/part-of: driftguard
    includeSelectors: false
```

## Karpenter Configuration

Karpenter uses per-environment overlays located at:
- `addons/karpenter/overlays/dev/`
- `addons/karpenter/overlays/staging/`
- `addons/karpenter/overlays/prod/`

Each overlay configures NodePool and EC2NodeClass resources with `karpenter.sh/discovery` tags that match the corresponding EKS cluster name. This tag is how Karpenter discovers which subnets and security groups to use for provisioned nodes. The base configuration lives in `addons/karpenter/base/` and the overlays patch only environment-specific values (instance types, capacity limits, discovery tags).

## Progressive Delivery with Argo Rollouts

Rollout definitions and AnalysisTemplates live in [rollouts/](../../driftguard-gitops/rollouts/README.md). Key rules:

**AnalysisTemplates use `count: 5` for bounded analysis.** This means each analysis run executes exactly 5 measurement intervals before reaching a pass/fail conclusion. This prevents unbounded analysis that could block deployments indefinitely or consume excessive resources.

**Rollout requirements:** Every Rollout must specify the stable service, canary or blue-green behavior, analysis templates, pause windows, rollback behavior, and metric failure behavior. A Rollout without analysis is incomplete.

**Metric queries:** Prometheus queries in AnalysisTemplates must target real metrics exposed by the workload. Use `successCondition` and `failureLimit` to define clear pass/fail boundaries.

## Resource Quality Standards

Every Kubernetes resource in this repository must meet these quality expectations:

- Stable names, labels, selectors, namespaces, ownership labels, and sync-wave annotations
- Workloads need readiness/liveness probes, resource requests and limits, non-root execution where supported, and observable metrics/logs/traces endpoints
- Admission policies must fail closed for security-critical evaluation failures
- ExternalSecret manifests contain references only; never put a secret value in a manifest, Helm value, example, test fixture, or annotation
- Namespace-scoped resources must declare their namespace explicitly

## Validation Workflow

The GitOps validation pipeline runs in [ci-gitops.yml](../../.github/workflows/ci-gitops.yml) and consists of:

```bash
# From driftguard-gitops/ root:

# 1. Run conformance tests
python3 -m pytest tests/ -q

# 2. Scan for plaintext secrets
python3 scripts/scan_no_plaintext_secrets.py

# 3. (When available) YAML schema validation
# kubeconform -strict -ignore-missing-schemas .
```

The [conformance tests](../../driftguard-gitops/conformance/README.md) verify ArgoCD Application relationships, project bindings, and resource constraints. The [secret scanner](../../driftguard-gitops/scripts/scan_no_plaintext_secrets.py) rejects AWS access keys, PEM blocks, and plaintext credential assignments.

For additional security validation rules, see [30-security-validation.md](30-security-validation.md).

## Observability Expectations

The [observability stack](../../driftguard-gitops/observability/README.md) uses the LGTM pattern (Loki, Grafana, Tempo, Prometheus/Mimir). When adding or modifying observability resources:

- Prometheus rules need explicit recording expressions, alert thresholds, time windows, labels, and rule tests
- Telemetry pipelines must preserve unaffected signals when one backend fails
- Insufficient telemetry surfaces as "unknown" health rather than falsely "healthy"
- SLO definitions live in [observability/slo/](../../driftguard-gitops/observability/slo/README.md)

## Related Steering Files

- [00-driftguard-engineering.md](00-driftguard-engineering.md): Master engineering contract and two-layer model
- [30-security-validation.md](30-security-validation.md): Policy enforcement, admission review, and secret scanning details
- [40-documentation.md](40-documentation.md): README structure standards for new directories
