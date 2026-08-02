# Argo Rollouts analysis

`analysis-templates.yaml` defines Prometheus-backed checks used by Demo_Service progressive delivery. The analysis contract covers error rate, p95 latency, query timeout, failure limit, and rollback behavior.

## Release behavior

A healthy analysis permits promotion through the declared canary steps. A threshold breach, unavailable metric, or slow query must fail the AnalysisRun, abort the Rollout, and restore the previous stable version. Do not treat missing telemetry as success.

## Validation

Run the rollout manifest tests and render/schema validation. When a Prometheus test environment is available, seed clean, breaching, and unavailable metric cases and verify promotion, abort, and rollback outcomes. Record AnalysisRun conditions and timestamps.

## Operational review

Keep the Prometheus address, query window, thresholds, pause durations, and service selectors aligned with the workload Service and SLO recording rules. Any change to a metric name or label requires coordinated updates to the service, Prometheus rules, AnalysisTemplates, and tests.
