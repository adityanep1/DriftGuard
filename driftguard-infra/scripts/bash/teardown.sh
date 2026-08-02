#!/usr/bin/env sh
set -eu
ENVIRONMENT=${1:-}
CONFIRM=${2:-}
case "$ENVIRONMENT" in dev|staging|prod) ;; *) echo 'Usage: teardown.sh <dev|staging|prod> CONFIRM' >&2; exit 2 ;; esac
[ "$CONFIRM" = "CONFIRM" ] || { echo 'Destructive teardown requires the literal CONFIRM argument.' >&2; exit 2; }
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
LOG="$ROOT/teardown-$ENVIRONMENT.log"
run() { "$@" 2>&1 | tee -a "$LOG"; }
if ! run kubectl --context "driftguard-$ENVIRONMENT" delete ingress --all --all-namespaces --wait=true --timeout=300s; then
  echo "Teardown incomplete: ingress drain failed; Terraform destroy was not attempted." >&2
  exit 1
fi
if ! (cd "$ROOT/live/$ENVIRONMENT" && run terraform init -input=false && run terraform destroy -input=false -auto-approve); then
  echo "Teardown incomplete for $ENVIRONMENT; see $LOG. Rerun after remediation." >&2
  exit 1
fi
echo "Teardown completed for $ENVIRONMENT."
