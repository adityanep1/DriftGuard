# DriftGuard Demo Service

The Demo Service is a small FastAPI application that exercises the complete delivery path from source code all the way to production. It covers testing, container builds, ECR publication, Config Repo image-tag updates, ArgoCD reconciliation, progressive canary delivery, metrics collection, logging, and distributed tracing.

Think of it as both a working microservice and a reference implementation for how any service should flow through the DriftGuard platform.

## Local development

Getting started locally is straightforward. From the `demo-service/` directory, create or activate a Python virtual environment, install the dependencies, and you are ready to go:

```bash
pip install -r requirements.txt
python -m pytest tests -q
uvicorn app.main:app --reload
```

The service exposes three read-only endpoints:

| Endpoint | What it does |
|---|---|
| `GET /` | Returns the main application response |
| `GET /healthz` | Readiness probe; returns HTTP 503 until the application has fully started |
| `GET /metrics` | Prometheus metrics endpoint for scraping |

## How the application works

The service records request counters and latency histograms labeled for `demo-service`. When OpenTelemetry dependencies are available, it instruments the FastAPI application and exports spans through the configured telemetry path. The readiness event is set during the application lifespan and cleared during shutdown, which means the health endpoint accurately reflects whether the service is ready to handle traffic.

## Container contract

The Dockerfile builds a minimal, non-root image and includes the labels required by the Gatekeeper admission baseline. A few things that must never be added to the image: privileged flags, embedded credentials, mutable `latest` image references, or production configuration defaults. The image should remain environment-neutral so the same build can run in dev, staging, and prod with only configuration differences.

## GitOps delivery

The Kubernetes manifests for this service live in `driftguard-gitops/workloads/demo-service/`. The base directory contains the Rollout, Service, Ingress, ServiceAccount, and probe definitions. Environment overlays (dev, staging, prod) carry environment-specific image tags and IRSA annotations.

The delivery flow: CI must pass all tests and the image scan, push the container with the full commit SHA as the tag to ECR, then commit the desired tag to the Config Repo. ArgoCD picks it up from there.

## Failure handling

The pipeline has multiple stop points to prevent bad deployments:

- A failing test stops the pipeline before image scanning even begins.
- A HIGH or CRITICAL vulnerability finding stops before the image is pushed to ECR.
- A failed Config Repo update leaves the Config Repo unchanged (no partial commits).
- If rollout analysis detects errors or latency issues in production, Argo Rollouts aborts the canary and restores the previous stable version automatically.

## Related documentation

- [Root README](../README.md)
- [Platform requirements](../.kiro/specs/gitops-platform/requirements.md)
- [CI workflow (ci-demo-service.yml)](../.github/workflows/ci-demo-service.yml)
- [GitOps workload manifests](../driftguard-gitops/workloads/demo-service/README.md)
- [Dockerfile](Dockerfile)
