# ApplicationSets

ApplicationSets generate ArgoCD Applications from declarative target sets. They remove repetitive Application definitions while preserving explicit project, source, destination, version, sync policy, and retry behavior.

## Current generators

- `platform-addons-appset.yaml` — pinned platform Helm charts.
- `observability-appset.yaml` — Prometheus/Grafana, Loki, and Tempo charts.
- `workloads-appset.yaml` — one Demo_Service Application per Environment.

Falco forwarding and other resources that need custom Helm values may use explicit child Applications instead of forcing values into a generic template.

## Generator rules

Use `missingkey=error` for Go templates. Every target must provide all fields consumed by the template. A malformed or incomplete target must fail clearly and must not silently generate an unsafe Application. Removing a target must remove only its generated Application according to the selected pruning policy.

## Review checklist

Confirm target count, unique names, chart/source pins, approved AppProject, destination namespace, sync wave, `selfHeal`, retry limit 5, `CreateNamespace=true`, and `prune: false`. Test additions, removals, malformed input, and generated Application/project binding before merging.
