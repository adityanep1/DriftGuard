# Observability configuration

The observability tree delivers the metrics, logs, traces, dashboards, and SLO configuration consumed by the DriftGuard platform. Helm Applications install the pinned Prometheus/Grafana, Loki, and Tempo components; Git-managed manifests configure collectors, dashboards, recording rules, and alerts.

## Components

- `kube-prometheus-stack/` — Prometheus and Grafana chart-owned configuration.
- `loki/` — log storage/query configuration and retention decisions.
- `tempo/` — trace storage/query configuration and retention decisions.
- `otel-collector/` — OpenTelemetry receivers, processors, exporters, and health endpoint.
- `dashboards/` — dashboards-as-code ConfigMaps.
- `slo/` — SLI recording rules, error budget calculations, and long/short burn-rate alerts.

## Signal contract

The Demo_Service exposes Prometheus metrics and can emit OpenTelemetry traces/logs. The collector must preserve unaffected signals when one exporter fails and must report signal failures. SLO attainment and error budget must become unknown when telemetry is insufficient; unknown is not compliant.

## Validation

Parse all YAML, run GitOps tests, run `promtool test rules observability/slo/demo-service-slo-test.yaml` when installed, and inspect PrometheusRule labels/expressions. Runtime validation must confirm component readiness, telemetry freshness, dashboard population, and alert delivery in a test cluster.

## Retention and cost

Metrics, logs, and traces have different retention requirements and cost profiles. Review storage class, replication, retention, ingestion rate, and alert volume before production changes. Do not use production-sized retention or replicas in dev without an explicit cost reason.
