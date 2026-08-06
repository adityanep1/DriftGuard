# Argo Rollouts Analysis

This directory contains the Prometheus-backed analysis templates used by the Demo Service progressive delivery pipeline. When a new version is deployed, Argo Rollouts uses these templates to query real production metrics and decide whether to promote or abort the canary.

## How progressive delivery works here

During a canary rollout, traffic is shifted in increments (20%, 40%, 60%, 80%, 100%) with a 300-second pause between each step. At each pause, the analysis templates query Prometheus for error rate and p95 latency. If the metrics look good, the rollout promotes to the next step. If a threshold is breached, a metric is unavailable, or a query times out, the AnalysisRun fails, the Rollout aborts, and the previous stable version is restored automatically.

This means bad deployments get caught and rolled back without human intervention.

## Analysis template contract

The templates (`demo-service-error-rate` and `demo-service-p95-latency`) follow these rules:

- Each metric has a 60-second query timeout
- Failure limit is 1 (a single bad reading triggers abort)
- The Prometheus address must be a reachable HTTP endpoint
- Missing telemetry is never treated as success

## Validation

Run the rollout manifest tests from `driftguard-gitops/`:

```bash
python -m pytest tests/test_rollouts_manifests.py -q
```

When a Prometheus test environment is available, seed clean data, breaching data, and unavailable-metric scenarios. Verify that each case produces the expected outcome: promotion, abort, or rollback. Record AnalysisRun conditions and timestamps for evidence.

## Keeping things aligned

The Prometheus address, query windows, thresholds, pause durations, and service selectors in these templates must stay in sync with the workload Service definition and the SLO recording rules in `observability/slo/`. If you change a metric name or label, you need to update the service instrumentation, recording rules, analysis templates, dashboard panels, and test fixtures together.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [GitOps and Kubernetes steering](../../.kiro/steering/20-gitops-kubernetes.md)
- [Observability and SLO](../observability/slo/README.md)
- [Workload manifests](../workloads/demo-service/README.md)
- [Test suite](../tests/README.md)
