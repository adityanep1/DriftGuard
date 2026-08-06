# ApplicationSets

ApplicationSets are ArgoCD's way of generating multiple Applications from a single template. Instead of writing the same Application manifest over and over with slight variations, you declare the template once and provide a list of targets. ArgoCD generates the correct Application for each target automatically.

This saves a lot of repetition while preserving explicit control over project bindings, source pins, destinations, sync policies, and retry behavior.

## Current generators

| File | What it generates |
|---|---|
| `platform-addons-appset.yaml` | One Application per pinned platform Helm chart (Argo Rollouts, AWS LB Controller, ESO, etc.) |
| `observability-appset.yaml` | Applications for Prometheus/Grafana, Loki, and Tempo charts |
| `workloads-appset.yaml` | One Demo Service Application per environment (dev, staging, prod) |

Some resources that need custom Helm values (like Falco forwarding configuration) use explicit child Applications instead of forcing complex values into a generic template. That is fine; not everything needs to be an ApplicationSet.

## Generator rules

A few rules that keep ApplicationSets safe:

- Always use `missingkey=error` in Go templates. If a target does not provide a required field, the generation should fail loudly rather than producing a broken Application.
- Removing a target from the list must remove only its generated Application, following the configured pruning policy.
- Every generated Application must land in an approved AppProject with the correct source pin and destination namespace.

## Review checklist

Before merging changes to an ApplicationSet, verify:

- Target count matches expectations
- Each generated Application has a unique name
- Chart and source versions are pinned (no floating tags)
- The AppProject is one of the approved defaults
- Destination namespaces are correct
- Sync waves, `selfHeal`, retry limit 5, `CreateNamespace=true`, and `prune: false` are all set appropriately
- Test additions, removals, and malformed targets to confirm the template handles them correctly

## Related documentation

- [Config Repo README (parent)](../README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [GitOps and Kubernetes steering](../../.kiro/steering/20-gitops-kubernetes.md)
- [Platform add-ons](../addons/README.md)
- [AppProject security](../projects/README.md)
