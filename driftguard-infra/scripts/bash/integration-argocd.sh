#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${1:-driftguard-dev}"
CONFIG_REPO_REVISION="${2:-main}"

for cmd in kubectl argocd; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required for this integration test." >&2; exit 127; }
done

echo "Waiting for ArgoCD Application CRD to be established..."
kubectl --context "$CONTEXT" -n argocd wait --for=condition=Established \
  crd/applications.argoproj.io --timeout=180s

echo "Waiting for root-application to sync and become healthy..."
argocd app wait root-application --app-namespace argocd \
  --sync --health --revision "$CONFIG_REPO_REVISION" --timeout 180

EXPECTED=(
  argocd-projects
  driftguard-application-sets
  driftguard-observability-config
  driftguard-security-policies
  driftguard-external-secrets
  karpenter-nodepool
  falco
  falcosidekick
)

for name in "${EXPECTED[@]}"; do
  argocd app get "$name" --app-namespace argocd --hard-refresh --output wide
done

GENERATED=$(kubectl --context "$CONTEXT" -n argocd get applications -o jsonpath='{.items[*].metadata.name}')
MISSING=()
for name in "${EXPECTED[@]}"; do
  if ! echo "$GENERATED" | grep -qw "$name"; then
    MISSING+=("$name")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Root_Application did not discover all referenced children: ${MISSING[*]}" >&2
  exit 1
fi

echo "ArgoCD root and child Applications are synchronized and healthy."
