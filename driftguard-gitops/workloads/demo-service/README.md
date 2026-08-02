# Demo_Service GitOps delivery

This directory contains the Kubernetes desired state for the Demo_Service. The application repository builds and publishes the image; this Config_Repo controls the image tag, deployment strategy, ingress, identity, probes, and environment overlays.

## Layout

- `base/`: Rollout, Services, Ingress, ServiceAccount, labels, probes, and common configuration.
- `overlays/dev/`: development image/configuration.
- `overlays/staging/`: pre-production image/configuration.
- `overlays/prod/`: production image/configuration and stricter availability expectations.

## Delivery contract

CI commits the full image commit identifier into the selected overlay only after tests, image scanning, ECR publication, and push retries succeed. ArgoCD then reconciles the overlay. Do not edit the live Rollout or use `kubectl apply` as the normal deployment mechanism.

## Progressive delivery

The Rollout supports canary and blue-green patterns. AnalysisTemplates query Prometheus for error rate and latency. A breach, unavailable metric, or slow analysis must abort the rollout and restore the previous stable version. Each canary step and pause duration is part of the release contract.

## Security and operations

Keep the ServiceAccount IRSA annotation scoped to the intended workload role. Preserve the required `Environment`, `Project`, and `ManagedBy` labels, non-root security settings, resource requests/limits, readiness/liveness probes, and the HTTP-to-HTTPS ingress behavior. Environment overlays add the concrete environment label; the shared base must remain environment-neutral. Secrets must be ExternalSecret references, never values.

## Validation

Run Kustomize rendering/schema checks when available, repository invariant tests, secret scanning, and rollout analysis tests. Runtime validation requires Argo Rollouts, Prometheus, the ingress controller, and a reachable test endpoint.
