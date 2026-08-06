# Demo Service GitOps Delivery

This directory contains the Kubernetes desired state for the Demo Service. The application repository (in `demo-service/`) builds and publishes the container image; this Config Repo controls the image tag, deployment strategy, ingress rules, identity, probes, and environment-specific configuration.

In other words: the app repo decides what the container looks like, and this directory decides how and where it runs.

## Directory layout

| Path | What it contains |
|---|---|
| `base/` | Rollout, Services, Ingress, ServiceAccount, labels, probes, and shared configuration |
| `overlays/dev/` | Development image tag and dev-specific settings |
| `overlays/staging/` | Pre-production image tag and staging configuration |
| `overlays/prod/` | Production image tag, stricter availability expectations |

## How deployment works

CI commits the full image commit SHA into the selected overlay only after tests, image scanning, ECR publication, and push retries all succeed. Once that commit lands in this repo, ArgoCD reconciles the overlay and Argo Rollouts manages the progressive delivery.

The normal deployment mechanism is always: change Git, let ArgoCD and Rollouts handle it. Do not edit the live Rollout or use `kubectl apply` for routine deployments.

## Progressive delivery

The Rollout uses a canary strategy. Traffic is shifted gradually (20%, 40%, 60%, 80%, 100%) with analysis checks at each step. The AnalysisTemplates query Prometheus for error rate and p95 latency. If a metric breaches its threshold, is unavailable, or the analysis is too slow, the rollout aborts and the previous stable version is restored automatically.

Each canary step weight and pause duration is part of the release contract. Do not change them without understanding the impact on detection time and blast radius.

## Security and operational requirements

A few things to keep in mind:

- The ServiceAccount IRSA annotation must be scoped to the intended workload role only.
- Preserve the required labels: `Environment`, `Project`, and `ManagedBy`.
- Maintain non-root security settings, resource requests/limits, and readiness/liveness probes.
- Keep the HTTP-to-HTTPS ingress redirect behavior.
- Environment overlays add the concrete environment label; the shared base must remain environment-neutral.
- Secrets are always ExternalSecret references, never actual values.

## Validation

```bash
# Run invariant tests and rollout manifest checks
python -m pytest tests -q

# Run the secret scanner
python scripts/scan_no_plaintext_secrets.py .
```

When available, also run Kustomize rendering and schema checks. Full runtime validation requires Argo Rollouts, Prometheus, the ingress controller, and a reachable test endpoint.

## Related documentation

- [Config Repo README (parent)](../../README.md)
- [Demo Service application repository](../../../demo-service/README.md)
- [GitOps and Kubernetes steering](../../../.kiro/steering/20-gitops-kubernetes.md)
- [Rollouts analysis templates](../../rollouts/README.md)
- [Observability and SLO](../../observability/README.md)
