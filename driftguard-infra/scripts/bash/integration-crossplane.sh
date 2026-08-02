#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${1:-driftguard-dev}"
NAMESPACE="${2:-crossplane-system}"
CLAIM_NAME="${3:-driftguard-sample-bucket}"
TIMEOUT="${4:-900}"
CONFIRM_DEPROVISION="${5:-}"

if [ "$CONFIRM_DEPROVISION" != "--confirm-deprovision" ]; then
  echo "This integration test deletes the sample AWS resource." >&2
  echo "Re-run with --confirm-deprovision as the 5th argument against a dedicated test account." >&2
  exit 2
fi

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required." >&2; exit 127; }

PROVIDER_TIMEOUT=$((TIMEOUT < 600 ? TIMEOUT : 600))

echo "Waiting for Crossplane provider to be healthy..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait --for=condition=Healthy \
  provider.pkg.crossplane.io/provider-aws --timeout="${PROVIDER_TIMEOUT}s"

echo "Waiting for ProviderConfig to be healthy..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait --for=condition=Healthy \
  providerconfig.aws.upbound.io/default --timeout="${PROVIDER_TIMEOUT}s"

echo "Waiting for XRD to be established..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait --for=condition=Established \
  compositeresourcedefinition.apiextensions.crossplane.io/xbuckets.storage.driftguard.io \
  --timeout="${PROVIDER_TIMEOUT}s"

echo "Waiting for claim $CLAIM_NAME to become Ready..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait --for=condition=Ready \
  "bucket.storage.driftguard.io/${CLAIM_NAME}" --timeout="${TIMEOUT}s"

READY_STATUS=$(kubectl --context "$CONTEXT" -n "$NAMESPACE" get \
  "bucket.storage.driftguard.io/${CLAIM_NAME}" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
if [ "$READY_STATUS" != "True" ]; then
  echo "Crossplane claim $CLAIM_NAME did not report Ready=True." >&2; exit 1
fi
echo "Claim $CLAIM_NAME is Ready."

echo "Deleting claim $CLAIM_NAME..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" delete \
  "bucket.storage.driftguard.io/${CLAIM_NAME}"

echo "Waiting for claim deletion..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" wait --for=delete \
  "bucket.storage.driftguard.io/${CLAIM_NAME}" --timeout="${TIMEOUT}s"

echo "Crossplane claim $CLAIM_NAME became Ready and was deprovisioned within the configured timeout."
