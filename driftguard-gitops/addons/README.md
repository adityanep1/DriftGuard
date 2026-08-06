# Platform Add-ons

Platform add-ons are the cluster capabilities that workloads depend on. They are delivered by ArgoCD as pinned Helm Applications or small declarative manifests. Without these controllers running and healthy, workloads cannot get ingress, secrets, autoscaling, progressive delivery, or admission policy enforcement.

## What each add-on provides

| Add-on | Responsibility |
|---|---|
| Argo Rollouts | Progressive delivery (canary, blue-green) and Rollout CRDs |
| AWS Load Balancer Controller | Creates ALB resources from Ingress annotations |
| External Secrets Operator | Reads external secret stores and materializes Kubernetes Secrets |
| Gatekeeper | Admission policy enforcement (blocks non-compliant workloads) |
| Falco + Falcosidekick | Runtime threat detection and alert forwarding |
| Karpenter | Capacity management through NodePool and EC2NodeClass resources |

## Rules for add-on management

- Pin every chart revision. Keep source repositories explicitly listed in the target AppProject.
- Use sync waves to install CRDs and controllers before resources that depend on them.
- Never put static cloud credentials in Helm values. Controllers that need AWS access must use IRSA with a properly scoped role.

## Karpenter is environment-specific

The Karpenter `EC2NodeClass` needs two values that differ per cluster: the node IAM role and the `karpenter.sh/discovery` tag used to find subnets and security groups. Because of that, `addons/karpenter` is a Kustomize base with `overlays/dev`, `overlays/staging`, and `overlays/prod`. Each overlay patches the role (`driftguard-<env>-nodes`) and the discovery value (`driftguard-<env>`) to match that environment's cluster.

The Terraform `networking` module tags each cluster's private subnets, and the `eks` module tags the cluster security group, with `karpenter.sh/discovery = <cluster_name>`, so discovery resolves to the correct cluster automatically. Point each environment's Karpenter Application at its own overlay; never apply the raw base, since it carries deliberate placeholders that cannot launch nodes.

## Readiness and failure

A controller is not ready just because its ArgoCD Application exists. True readiness means the Deployment or DaemonSet pods are running, CRDs are established, webhooks are responding, and controller conditions report healthy.

If a controller fails, it must block dependent sync waves or produce an explicit degraded status. Do not work around health check failures by increasing timeouts without investigating the root cause first.

## Validation

For offline checks, run YAML parsing, kubeconform schema validation, and conformance policies. When Helm is available, render charts and inspect the output. For runtime validation, use the integration scripts and record chart versions, cluster context, timestamps, and observed health conditions.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [GitOps and Kubernetes steering](../../.kiro/steering/20-gitops-kubernetes.md)
- [ApplicationSets](../applicationsets/README.md)
- [AppProject security](../projects/README.md)
