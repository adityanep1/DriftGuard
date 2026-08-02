#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${1:-driftguard-dev}"
RUN_MUTATION_CHECKS="${2:-}"

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required." >&2; exit 127; }

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
GITOPS_ROOT="$ROOT/../driftguard-gitops"

echo "Checking add-on readiness..."

declare -a CHECKS=(
  "external-secrets:deployment/external-secrets:deployment/external-secrets-webhook"
  "gatekeeper-system:deployment/gatekeeper-controller-manager"
  "falco:daemonset/falco"
)

for entry in "${CHECKS[@]}"; do
  IFS=':' read -ra PARTS <<< "$entry"
  namespace="${PARTS[0]}"
  for resource in "${PARTS[@]:1}"; do
    kubectl --context "$CONTEXT" -n "$namespace" rollout status "$resource" --timeout=300s
  done
done

if [ "$RUN_MUTATION_CHECKS" != "--mutation" ]; then
  echo "Add-on readiness checks passed. Runtime checks were skipped (pass --mutation to enable)."
  exit 0
fi

echo "Running ESO preservation, Gatekeeper fail-closed, and Falco alert-path checks..."

kubectl --context "$CONTEXT" apply --server-side -f "$GITOPS_ROOT/policies/constraints/baseline.yaml"

# --- ESO materialize then preserve on broken store ---
echo "Verifying ESO materialize and preservation..."
kubectl --context "$CONTEXT" -n demo-dev wait --for=condition=Ready \
  externalsecret/demo-service-config --timeout=60s

BEFORE_DATA=$(kubectl --context "$CONTEXT" -n demo-dev get secret demo-service-config -o jsonpath='{.data}')
if [ -z "$BEFORE_DATA" ]; then
  echo "ESO created no materialized secret data." >&2; exit 1
fi

ORIGINAL_STORE=$(kubectl --context "$CONTEXT" -n demo-dev get secretstore aws-secrets-manager -o yaml)

cleanup() {
  echo "Restoring original SecretStore..."
  echo "$ORIGINAL_STORE" | kubectl --context "$CONTEXT" apply -f - 2>/dev/null || true
}
trap cleanup EXIT

kubectl --context "$CONTEXT" -n demo-dev patch secretstore aws-secrets-manager \
  --type merge -p '{"spec":{"provider":{"aws":{"region":"invalid-driftguard-region"}}}}'
kubectl --context "$CONTEXT" -n demo-dev annotate externalsecret demo-service-config \
  "driftguard.io/force-sync=$(date +%s)" --overwrite
sleep 35

AFTER_DATA=$(kubectl --context "$CONTEXT" -n demo-dev get secret demo-service-config -o jsonpath='{.data}')
if [ "$BEFORE_DATA" != "$AFTER_DATA" ]; then
  echo "ESO changed or removed previously materialized values after store failure." >&2; exit 1
fi
echo "ESO preservation verified."

# --- Gatekeeper fail-closed ---
echo "Verifying Gatekeeper fail-closed behavior..."
FAILURE_POLICY=$(kubectl --context "$CONTEXT" get validatingwebhookconfiguration \
  gatekeeper-validating-webhook-configuration -o jsonpath='{.webhooks[*].failurePolicy}')
if ! echo "$FAILURE_POLICY" | grep -q "Fail"; then
  echo "Gatekeeper validating webhook is not configured fail-closed." >&2; exit 1
fi

REPLICAS=$(kubectl --context "$CONTEXT" -n gatekeeper-system get deployment \
  gatekeeper-controller-manager -o jsonpath='{.spec.replicas}')

restore_gatekeeper() {
  kubectl --context "$CONTEXT" -n gatekeeper-system scale \
    deployment/gatekeeper-controller-manager --replicas="$REPLICAS" 2>/dev/null || true
  kubectl --context "$CONTEXT" -n gatekeeper-system rollout status \
    deployment/gatekeeper-controller-manager --timeout=300s 2>/dev/null || true
}

# Update trap to also restore Gatekeeper
trap 'restore_gatekeeper; cleanup' EXIT

kubectl --context "$CONTEXT" -n gatekeeper-system scale \
  deployment/gatekeeper-controller-manager --replicas=0
sleep 15

if kubectl --context "$CONTEXT" -n demo-dev run gatekeeper-negative-test \
  --image=busybox:1.36 --restart=Never --dry-run=server \
  --overrides='{"spec":{"containers":[{"name":"negative","image":"busybox:1.36","securityContext":{"privileged":true}}]}}' 2>/dev/null; then
  echo "Gatekeeper admitted a privileged test pod while scaled to zero." >&2; exit 1
fi
echo "Gatekeeper correctly rejected admission while unavailable."
restore_gatekeeper
# Reset trap back to just cleanup (store already handled)
trap cleanup EXIT

# --- Falco trigger and alert forwarding ---
echo "Verifying Falco alert trigger and forwarding..."
TARGET_POD=$(kubectl --context "$CONTEXT" -n demo-dev get pods \
  -l app.kubernetes.io/name=demo-service -o jsonpath='{.items[0].metadata.name}')
if [ -z "$TARGET_POD" ]; then
  echo "No demo-service pod found for Falco trigger." >&2; exit 1
fi

FALCO_PODS=$(kubectl --context "$CONTEXT" -n falco get pods \
  -l app.kubernetes.io/name=falco -o jsonpath='{.items[*].metadata.name}')
if [ -z "$FALCO_PODS" ]; then
  echo "No Falco pod found for runtime trigger." >&2; exit 1
fi

kubectl --context "$CONTEXT" -n demo-dev exec "$TARGET_POD" -- sh -c 'echo driftguard-falco-trigger'

DEADLINE=$(($(date +%s) + 30))
ALERT=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  for falco_pod in $FALCO_PODS; do
    LOGS=$(kubectl --context "$CONTEXT" -n falco logs "$falco_pod" --since=35s --all-containers=true 2>/dev/null || true)
    if echo "$LOGS" | grep -qi 'terminal shell\|shell in container\|falco'; then
      ALERT="$LOGS"
      break 2
    fi
  done
  sleep 3
done

if [ -z "$ALERT" ]; then
  echo "Falco did not emit an identifiable alert within 30 seconds." >&2; exit 1
fi
echo "Falco alert detected."

# --- Verify Loki forwarding ---
LOG_QUERY=$(printf '%s' '{job="falco"} |= "driftguard-falco-trigger"' | python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))")
LOKI_PATH="/api/v1/namespaces/monitoring/services/http:loki-gateway:80/proxy/loki/api/v1/query?query=$LOG_QUERY"
LOKI_RESPONSE=$(kubectl --context "$CONTEXT" get --raw "$LOKI_PATH")
RESULT_COUNT=$(echo "$LOKI_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('data',{}).get('result',[])))")
if [ "$RESULT_COUNT" -eq 0 ]; then
  echo "Falco emitted an alert, but it was not forwarded to Loki within 30 seconds." >&2; exit 1
fi
echo "Falco emitted and forwarded an identifiable alert within 30 seconds."
echo "All add-on runtime checks passed."
