# DriftGuard Demo Service

The Demo_Service is a small FastAPI workload used to exercise the complete delivery path: source tests, container build, ECR publication, Config_Repo image-tag update, ArgoCD reconciliation, progressive delivery, metrics, logs, and traces.

## Local development

From `demo-service/`, create or activate a Python environment, install `requirements.txt`, and run:

```powershell
python -m pytest tests -q
uvicorn app.main:app --reload
```

Read-only endpoints:

- `GET /` returns the work response.
- `GET /healthz` returns readiness and returns HTTP 503 before startup readiness is established.
- `GET /metrics` exposes Prometheus metrics.

## Application contract

The service records request counters and latency histograms labelled for the `demo-service`. Optional OpenTelemetry dependencies instrument the FastAPI application and export spans through the configured runtime telemetry path. The readiness event is set only during the application lifespan and is cleared during shutdown.

## Container contract

The Dockerfile builds a minimal non-root image and supplies the labels required by the Gatekeeper baseline. Do not add privileged flags, embedded credentials, mutable `latest` image references, or production configuration defaults to the image.

## GitOps delivery

Kubernetes manifests live in `driftguard-gitops/workloads/demo-service`. The base contains the Rollout, Service, Ingress, ServiceAccount, and probes. Environment overlays carry environment-specific image tags and IRSA annotations. CI must pass tests and the image scan, push the full commit SHA to ECR, then commit the desired tag to the Config_Repo.

## Failure handling

A failing test stops before image scanning. A HIGH or CRITICAL image finding stops before push. A failed Config_Repo update must leave the Config_Repo unchanged. Rollout analysis failures must abort and restore the previous stable version through Argo Rollouts.
