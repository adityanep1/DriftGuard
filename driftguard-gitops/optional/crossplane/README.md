# Optional Crossplane Feature

Crossplane is disabled by default. These manifests are intentionally outside `bootstrap/children/`, so the Root Application does not discover or install them. This is a deliberate choice: Crossplane provisions real AWS resources, so it should only be enabled when you have a dedicated account ready and understand the implications.

## How to enable Crossplane

1. Confirm you have a dedicated test or target AWS account and configure the Crossplane provider's IRSA identity.
2. Copy `crossplane-controller-app.yaml` and `crossplane-resources-app.yaml` into `bootstrap/children/` through a reviewed Git PR.
3. Wait for the Crossplane Application and AWS provider to report Healthy/Ready.
4. Add or update `resources/sample-bucket-claim.yaml` through a reviewed Git PR. The resources Application will apply it through GitOps.
5. Confirm the claim and the composed bucket both report Ready before using the resource.

## Important safety details

Do not place AWS credentials or Kubernetes Secret values in this directory. The Crossplane provider uses `InjectedIdentity` (IRSA) for authentication.

The composed resources have `deletionPolicy: Delete`, which means approving a claim deletion will actually deprovision the underlying AWS resource. Be deliberate about deletions.

## How to disable Crossplane

To stop Crossplane from reconciling:

1. Remove the claim through GitOps first (so the underlying resource gets cleaned up).
2. Then remove the two child Application manifests from `bootstrap/children/`.

Do not remove the controller before removing claims, or you will end up with orphaned AWS resources.

## Related documentation

- [Config Repo README (parent)](../../README.md)
- [GitOps and Kubernetes steering](../../../.kiro/steering/20-gitops-kubernetes.md)
- [Bootstrap](../../bootstrap/README.md)
- [AppProject security](../../projects/README.md)
