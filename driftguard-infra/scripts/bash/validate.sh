#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required validation tool is unavailable: $1" >&2
    exit 127
  }
}

for cmd in terraform python tflint tfsec checkov conftest; do
  require_command "$cmd"
done

terraform fmt -check -recursive
VALIDATION_DIRS="bootstrap modules/networking modules/networking/examples/basic modules/eks modules/iam modules/ecr modules/ecr/examples/basic modules/dns modules/addons-bootstrap modules/github-oidc live/dev live/staging live/prod"
for dir in $VALIDATION_DIRS; do
  (cd "$ROOT/$dir" && terraform init -backend=false -input=false -upgrade=false && terraform validate && tflint --force)
done
python -m pytest policies/python -q
tfsec "$ROOT" --exclude-downloaded-modules
checkov -d "$ROOT" --quiet
conftest test --all-namespaces --policy "$ROOT/policies" "$ROOT/policies/tests/valid-plan.json"
if conftest test --all-namespaces --policy "$ROOT/policies" "$ROOT/policies/tests/invalid-security-plan.json"; then
  echo 'Expected invalid security fixture to fail conformance' >&2
  exit 1
fi
GITOPS_DIR="$ROOT/../driftguard-gitops"
if [ -d "$GITOPS_DIR" ]; then
  require_command kubeconform
  find "$GITOPS_DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) \
    ! -path '*/.github/*' \
    ! -name 'versions.yaml' \
    ! -name 'demo-service-slo-rules.yaml' \
    ! -name 'demo-service-slo-test.yaml' \
    ! -name '.pre-commit-config.yaml' \
    ! -name 'kustomization.yaml' \
    -print0 | xargs -0 -r kubeconform -strict -ignore-missing-schemas -summary
else
  echo "Skipping kubeconform: driftguard-gitops directory not found alongside driftguard-infra"
fi
echo 'Validation completed without applying infrastructure or contacting AWS.'
