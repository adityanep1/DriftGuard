# Infrastructure Scripts

This directory contains the validation, integration, smoke-test, and teardown scripts for the DriftGuard infrastructure. Scripts are provided in both PowerShell (Windows) and Bash (POSIX) variants with identical functionality.

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

Always read a script before running it. Confirm the working directory, AWS account, Kubernetes context, target environment, and required confirmation flags.

## Read-only and offline scripts

These scripts validate without changing anything:

**validate.sh / validate.ps1** runs formatting checks, Terraform initialization and validation, Python tests, security scans, conformance checks, and Kubernetes manifest schema validation. It never applies infrastructure. Kubeconform uses `-ignore-missing-schemas` for CRDs not in its bundled schemas, but YAML parsing, Conftest, and repository tests still validate those custom resources.

**integration-argocd** checks Root Application and child Application health and discovery against a running cluster. Read-only.

**integration-addons** checks controller readiness plus opt-in ESO, Gatekeeper, Falco, and Loki runtime checks.

**integration-crossplane** checks provider and claim readiness. Note: the deprovision check (`-ConfirmDeprovision`) does delete the sample resource.

## Mutating and destructive scripts

These scripts change infrastructure:

**e2e-smoke** provisions or exercises a complete dev flow, injects drift and canary failures for testing, and tears down afterward.

**teardown** removes ingress and load-balancer dependencies first, then destroys one environment after explicit confirmation. It stops on failure so partial results can be investigated.

## Examples

### Linux/macOS

```bash
cd driftguard-infra
bash scripts/bash/validate.sh
bash scripts/bash/integration-argocd.sh driftguard-dev
bash scripts/bash/integration-addons.sh driftguard-dev --mutation
bash scripts/bash/integration-crossplane.sh driftguard-dev crossplane-system driftguard-sample-bucket 900 --confirm-deprovision
bash scripts/bash/e2e-smoke.sh demo.example.invalid --confirm
bash scripts/bash/teardown.sh dev CONFIRM
```

### Windows

```powershell
Set-Location driftguard-infra
./scripts/powershell/validate.ps1
./scripts/powershell/integration-argocd.ps1 -Context driftguard-dev
./scripts/powershell/integration-addons.ps1 -Context driftguard-dev -RunMutationChecks
./scripts/powershell/teardown.ps1 -Environment dev -Confirm
```

## Important: missing tools are failures

A script that cannot find a required dependency (terraform, argocd, kubectl, conftest, etc.) must stop and report the issue. Missing tools are never silently skipped: that would produce a false-passing result.

Do not run smoke, integration, apply, or teardown scripts against production or an unknown context. Use a dedicated test account and record tool versions, timestamps, target context, and exit codes.

## Related documentation

- [Infrastructure README (parent)](../README.md)
- [Module catalog](../modules/README.md)
- [Live environment roots](../live/README.md)
- [Python conformance tests](../policies/python/README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [Terraform and AWS steering](../../.kiro/steering/10-terraform-aws.md)
