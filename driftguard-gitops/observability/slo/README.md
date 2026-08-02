# Demo Service SLO Rules

This directory defines the Demo Service's Service Level Objective: a success-ratio SLO with recording rules, error budget calculations, and multi-window burn-rate alerts. The SLO target and rolling window are documented in `demo-service-slo.yaml`, and the test fixture lives in `demo-service-slo-test.yaml`.

## What the rules do

The success SLI distinguishes between successful and failed HTTP requests using stable service and status labels. From that raw signal, the recording rules calculate the SLO attainment over the rolling window.

The burn-rate alerts use a multi-window approach: long and short evaluation windows detect both sustained degradation and sudden failures. Each alert identifies the affected service and SLO, uses explicit thresholds and evaluation windows, and routes to the configured notification path.

One critical rule: when telemetry is missing or insufficient, the SLO must evaluate as "unknown." Unknown is never reported as compliant.

## Running validation

When `promtool` is installed:

```bash
promtool test rules observability/slo/demo-service-slo-test.yaml
```

This command is cluster-independent and proves that the recording rule expressions produce correct results for the supplied test series. It does not prove Prometheus ingestion, Alertmanager delivery, or Grafana rendering, so runtime testing in a cluster is still needed.

Also run the standard checks:

```bash
python -m pytest tests -q
python scripts/scan_no_plaintext_secrets.py .
```

## Coordinating changes

SLO rules do not exist in isolation. If you change a metric name, label, window, target, or alert threshold, you need to update all of the following together:

- Demo Service instrumentation code (the source of the metrics)
- Recording rules in this directory
- Analysis templates in `rollouts/`
- Dashboard panels in `observability/dashboards/`
- The test fixture (`demo-service-slo-test.yaml`)

Document the alert routing configuration and validate with both clean (happy path) and breaching (failure path) test series.
