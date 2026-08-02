#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:-demo.example.invalid}"
CONFIRM="${2:-}"

if [ "$CONFIRM" != "--confirm" ]; then
  echo "This smoke test provisions and destroys AWS resources." >&2
  echo "Re-run with --confirm after reviewing the plan." >&2
  exit 2
fi

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
LIVE="$ROOT/live/dev"
CONTEXT="driftguard-dev"
NAMESPACE="demo-dev"
APP="demo-service-dev"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

for cmd in terraform argocd kubectl curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required." >&2; exit 127; }
done

cleanup() {
  echo "Running single-command teardown for the ephemeral environment..."
  bash "$SCRIPT_DIR/teardown.sh" dev CONFIRM || true
}
trap cleanup EXIT

echo "=== Provisioning dev infrastructure ==="
(cd "$LIVE" && terraform init -input=false && terraform apply -input=false -auto-approve)

echo "=== Waiting for ArgoCD root-application ==="
argocd app wait root-application --app-namespace argocd --health --sync --timeout 600

echo "=== Waiting for demo-service rollout ==="
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait \
  --for=condition=Available rollout/demo-service --timeout=300s

echo "=== Verifying HTTPS health ==="
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://$HOSTNAME/healthz")
if [ "$HTTP_CODE" != "200" ]; then
  echo "HTTPS health check returned $HTTP_CODE" >&2; exit 1
fi
echo "HTTPS health check returned 200."

echo "=== Injecting replica drift ==="
kubectl --context "$CONTEXT" -n "$NAMESPACE" scale rollout/demo-service --replicas=1
echo "Waiting for ArgoCD to detect OutOfSync and self-heal..."
argocd app wait "$APP" --app-namespace argocd --sync --timeout 180
sleep 120
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait \
  --for=jsonpath='{.spec.replicas}'=2 rollout/demo-service --timeout=120s
echo "Self-heal confirmed: replicas restored to 2."

echo "=== Injecting bad canary image ==="
kubectl --context "$CONTEXT" -n "$NAMESPACE" argo rollouts set image \
  rollout/demo-service demo-service=ghcr.io/your-org/demo-service:known-bad
kubectl --context "$CONTEXT" -n "$NAMESPACE" argo rollouts abort demo-service
kubectl --context "$CONTEXT" -n "$NAMESPACE" argo rollouts get rollout demo-service --watch=false
echo "Canary abort confirmed."

echo "=== E2E smoke test passed. Teardown will run via trap. ==="
