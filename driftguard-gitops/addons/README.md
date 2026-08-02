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

## Readiness and failure

A controller is not ready just because its ArgoCD Application exists. True readiness means the Deployment or DaemonSet pods are running, CRDs are established, webhooks are responding, and controller conditions report healthy.

If a controller fails, it must block dependent sync waves or produce an explicit degraded status. Do not work around health check failures by increasing timeouts without investigating the root cause first.

## Validation

For offline checks, run YAML parsing, kubeconform schema validation, and conformance policies. When Helm is available, render charts and inspect the output. For runtime validation, use the integration scripts and record chart versions, cluster context, timestamps, and observed health conditions.
