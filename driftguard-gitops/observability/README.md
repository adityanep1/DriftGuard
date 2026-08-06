# Observability Configuration

This directory contains everything the platform needs to collect, store, query, and alert on metrics, logs, and traces. Helm Applications install the pinned versions of Prometheus, Grafana, Loki, and Tempo. Git-managed manifests configure the collectors, dashboards, recording rules, and alert definitions.

The goal is full observability for the DriftGuard platform: if something breaks or degrades, we should know about it before users do.

## Components

| Directory | What it provides |
|---|---|
| `kube-prometheus-stack/` | Prometheus and Grafana chart-owned configuration |
| `loki/` | Log storage, query configuration, and retention settings |
| `tempo/` | Trace storage, query configuration, and retention settings |
| `otel-collector/` | OpenTelemetry receivers, processors, exporters, and health endpoint |
| `dashboards/` | Dashboards-as-code delivered as ConfigMaps (Grafana reads them on startup) |
| `slo/` | SLI recording rules, error budget calculations, and multi-window burn-rate alerts |

## Signal contract

The Demo Service exposes Prometheus metrics at `/metrics` and can emit OpenTelemetry traces and logs. The collector configuration must preserve unaffected signals when one exporter fails (for example, if Tempo is temporarily down, metrics should still flow to Prometheus). Signal failures must be reported, not silently dropped.

For SLO attainment and error budget calculations, when telemetry is insufficient or missing, the status must evaluate as "unknown" rather than "compliant." Unknown is not a passing state.

## Running validation

```bash
# Parse all YAML and run GitOps tests
python -m pytest tests -q

# When promtool is installed
promtool test rules observability/slo/demo-service-slo-test.yaml
```

Runtime validation (confirming component readiness, telemetry freshness, dashboard population, and alert delivery) requires a test cluster with the observability stack deployed.

## Retention and cost considerations

Metrics, logs, and traces each have different retention requirements and cost profiles. Before making changes to production configuration, review storage class, replication factor, retention period, ingestion rate, and alert volume. Do not use production-sized retention or replica counts in dev without an explicit cost justification.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [GitOps and Kubernetes steering](../../.kiro/steering/20-gitops-kubernetes.md)
- [SLO recording rules](slo/README.md)
- [Rollouts analysis templates](../rollouts/README.md)
- [Test suite](../tests/README.md)
