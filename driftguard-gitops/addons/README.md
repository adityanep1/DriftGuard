# Platform add-ons

Platform add-ons are delivered by ArgoCD as pinned Helm Applications or small declarative manifests. They provide cluster capabilities required by workloads, policy, ingress, secrets, autoscaling, progressive delivery, and runtime security.

## Add-on ownership

- Argo Rollouts owns progressive delivery controllers and Rollout CRDs.
- AWS Load Balancer Controller owns ALB resources generated from Ingress.
- External Secrets Operator reads external secret stores and materializes references.
- Gatekeeper owns admission policy enforcement.
- Falco and Falcosidekick detect and forward runtime alerts.
- Karpenter owns capacity decisions through NodePool/EC2NodeClass resources.

## Rules

Pin every chart revision and keep source repositories explicitly allowed by the target AppProject. Use sync waves to install CRDs/controllers before dependent resources. Do not configure static cloud credentials in Helm values. Controllers requiring AWS access must use IRSA with a scoped role.

## Readiness and failure

A controller is not ready merely because its Application exists. Verify Deployment/DaemonSet readiness, CRD establishment, webhook health, and controller conditions. A failed controller must block dependent waves or produce an explicit degraded status; do not bypass health checks by increasing timeouts without investigation.

## Validation

Run YAML parsing, kubeconform, conformance policies, chart rendering where Helm is available, and the targeted runtime integration scripts. Record chart versions, cluster context, timestamps, and observed health conditions for runtime evidence.
