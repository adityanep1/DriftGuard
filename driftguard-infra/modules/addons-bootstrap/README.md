# ArgoCD Bootstrap Module

This module installs the pinned ArgoCD Helm chart and seeds the Root Application that kicks off the entire GitOps control plane. It is the bridge between Terraform (Layer A) and ArgoCD (Layer B).

## How it works

The Helm release is installed with `wait`, `atomic`, and a maximum 600-second readiness timeout. This means Terraform will not proceed until all ArgoCD components are actually running and healthy. If the Helm release fails to become ready within that window, the release is rolled back atomically.

The Root Application is a dependent `kubernetes_manifest` resource with `depends_on = [helm_release.argocd]`. This ensures Terraform will not attempt to create the Root Application if ArgoCD is not running. The Root Application points at `bootstrap/children` in the Config Repo, and the bootstrap manifest itself is `bootstrap/root-app.yaml`.

## What this module does NOT do

This module does not manage any day-2 add-ons through Terraform. Once ArgoCD is running and the Root Application is created, everything else is managed by ArgoCD through the Config Repo. The root module (in `live/<env>/`) must configure and pass the Helm and Kubernetes providers using the EKS cluster outputs.

## Inputs

- Chart version (pinned)
- Config Repo URL and revision
- Installation timeout in seconds (default 600)
- Standard environment and project tags

## Safety properties

The `prune: false` setting on the Root Application means ArgoCD will not delete resources that disappear from Git. This is a safety net during bootstrap. The tests in `test_platform_composition.py` verify that atomic install, wait, timeout, depends_on, and prune settings are all correctly declared.

## Related documentation

- [Module catalog](../README.md)
- [Python conformance tests](../../policies/python/README.md)
- [Live environment roots](../../live/README.md)
