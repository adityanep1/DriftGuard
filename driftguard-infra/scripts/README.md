# Infrastructure scripts

Scripts are grouped by shell and safety level.

```
scripts/
├── powershell/       # Windows PowerShell (.ps1)
│   ├── validate.ps1
│   ├── integration-argocd.ps1
│   ├── integration-addons.ps1
│   ├── integration-crossplane.ps1
│   ├── e2e-smoke.ps1
│   └── teardown.ps1
├── bash/             # POSIX shell (.sh)
│   ├── validate.sh
│   ├── integration-argocd.sh
│   ├── integration-addons.sh
│   ├── integration-crossplane.sh
│   ├── e2e-smoke.sh
│   └── teardown.sh
└── README.md
```

Read the script before execution and confirm the working directory, AWS account, Kubernetes context, environment, and confirmation flags.

## Read-only or offline

- `validate.ps1` / `validate.sh` — formatting, Terraform initialization/validation, Python tests, security scans, conformance, and Kubernetes manifest schema checks. They never apply infrastructure. Kubeconform excludes GitHub workflow/Kustomize input files and uses `-ignore-missing-schemas` for CRDs not present in its bundled Kubernetes schemas; YAML parsing, Conftest, and repository tests still validate those custom resources.
- `integration-argocd.ps1` — cluster-dependent Root_Application and child-Application health/discovery check.
- `integration-addons.ps1` — readiness check plus opt-in ESO, Gatekeeper, Falco, and Loki runtime checks.
- `integration-crossplane.ps1` — opt-in Crossplane provider/claim readiness and deprovision check; it deletes the sample resource and requires `-ConfirmDeprovision`.

## Mutating or destructive

- `e2e-smoke.ps1` — provisions or exercises a complete dev flow, injects drift/canary failure, and tears down.
- `teardown.ps1` / `teardown.sh` — removes ingress/load-balancer dependencies and destroys one environment after explicit confirmation.

Do not run smoke, integration, apply, or teardown scripts against production or an unknown context. Use a dedicated test account and record tool versions, timestamps, target context, and exit codes.

## Windows examples

```powershell
Set-Location driftguard-infra
./scripts/powershell/validate.ps1
./scripts/powershell/integration-argocd.ps1 -Context driftguard-dev
./scripts/powershell/integration-addons.ps1 -Context driftguard-dev -RunMutationChecks
# Destructive and account-specific:
./scripts/powershell/teardown.ps1 -Environment dev -Confirm
```

## Linux/macOS examples

```bash
cd driftguard-infra
bash scripts/bash/validate.sh
bash scripts/bash/integration-argocd.sh driftguard-dev
bash scripts/bash/integration-addons.sh driftguard-dev --mutation
bash scripts/bash/integration-crossplane.sh driftguard-dev crossplane-system driftguard-sample-bucket 900 --confirm-deprovision
# Destructive:
bash scripts/bash/e2e-smoke.sh demo.example.invalid --confirm
bash scripts/bash/teardown.sh dev CONFIRM
```

Missing tools are failures. A script that cannot run `terraform`, `argocd`, `kubectl`, conftest, or another required dependency must stop and report it rather than print a passing result.
