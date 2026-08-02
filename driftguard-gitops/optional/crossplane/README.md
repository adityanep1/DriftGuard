# Optional Crossplane feature

Crossplane is disabled by default. These manifests are intentionally outside
`bootstrap/children`, so the Root_Application does not discover or install them.

## Enablement

1. Confirm a dedicated test or target AWS account and configure the Crossplane
   provider's IRSA identity.
2. Apply the controller and resources Applications through a reviewed Git PR by
   copying `crossplane-controller-app.yaml` and `crossplane-resources-app.yaml`
   into `bootstrap/children/`.
3. Wait for the Crossplane Application and AWS provider to report Healthy/Ready.
4. Add or update `resources/sample-bucket-claim.yaml` through a reviewed Git PR; the resources Application applies it through GitOps only.
5. Confirm the claim and composed bucket report Ready before using the resource.

Do not place AWS credentials or Kubernetes Secret values in this directory.
The provider uses `InjectedIdentity` and the composed resource has
`deletionPolicy: Delete` so an approved claim deletion requests deprovisioning.
Remove the two child Application manifests to disable future reconciliation;
remove the claim through GitOps before disabling the controller.
