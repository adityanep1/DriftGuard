# Demo_Service SLO rules

This directory defines the Demo_Service success-ratio SLO, recording rules, error budget, and multi-window burn-rate alerts. The default target and rolling window are documented in `demo-service-slo.yaml`; the test fixture is `demo-service-slo-test.yaml`.

## Rule contract

The success SLI must distinguish successful and failed HTTP requests using stable service/status labels. Long- and short-window alerts must identify the service/SLO, use explicit thresholds and evaluation windows, and route to the configured notification path. Missing or insufficient telemetry must evaluate as unknown and must not be reported compliant.

## Validation

From `driftguard-gitops/`:

```powershell
promtool test rules observability/slo/demo-service-slo-test.yaml
```

The command is cluster-independent but requires `promtool`. Also run YAML parsing, GitOps tests, and secret scanning. A passing fixture proves expression behavior for the supplied series; it does not prove Prometheus ingestion, Alertmanager delivery, or Grafana rendering.

## Change checklist

When changing metric names, labels, windows, targets, or alert thresholds, update the Demo_Service instrumentation, recording rules, AnalysisTemplates, dashboard panels, and test fixture together. Document alert routing and validate both clean and breaching series.
