# AppProject Security Model

This directory is where we define the security boundaries for everything ArgoCD manages. Think of AppProjects as the "who can deploy what, where" rules for the cluster. Every Application in the platform must belong to one of these projects, and each project explicitly lists what it is allowed to touch. Anything not listed is denied by default.

## How the default-deny model works

ArgoCD AppProjects follow a default-deny principle. That means an Application can only:

- Pull from source repositories that its project explicitly allows
- Deploy into destination namespaces that its project explicitly allows
- Create cluster-scoped or namespace-scoped resource kinds that its project explicitly allows

If a manifest tries to do something outside these boundaries, ArgoCD will refuse to sync it. This gives us a strong blast radius control: a misconfigured workload Application cannot accidentally create cluster-wide RBAC rules or deploy into the monitoring namespace.

## Project files

### platform-addons.yaml

This project governs the cluster add-ons that provide foundational capabilities. It allows pulling from the official Helm chart repositories for Argo Rollouts, AWS Load Balancer Controller, External Secrets Operator, Gatekeeper, Falco, Karpenter, and Crossplane. Destinations are scoped to the specific namespaces each controller needs (e.g., `karpenter`, `external-secrets`, `gatekeeper-system`, `argo-rollouts`, `falco`, `crossplane-system`, `aws-load-balancer-controller`). Because controllers often install CRDs and webhooks, this project has cluster-resource permissions for Namespaces, CustomResourceDefinitions, ClusterRoles, ClusterRoleBindings, ValidatingWebhookConfigurations, and Crossplane provider kinds.

### observability.yaml

This project controls the metrics, logs, and traces stack (Prometheus, Grafana, Loki, Tempo). Sources are limited to the DriftGuard GitOps repo, the Prometheus community Helm charts, and the Grafana Helm charts. All deployments are restricted to the `monitoring` namespace. Cluster-resource permissions cover Namespaces, CRDs, ClusterRoles, and ClusterRoleBindings. Namespace resources include ConfigMaps, Deployments, Services, ServiceAccounts, PrometheusRules, and ServiceMonitors.

### security.yaml

This project handles Gatekeeper admission policies. The only allowed source is the DriftGuard GitOps repo, and the only allowed destination is `gatekeeper-system`. Cluster-resource permissions include Namespaces, CRDs, ClusterRoles, ClusterRoleBindings, ConstraintTemplates, and K8sBaseline constraints. This tight scoping ensures policy definitions cannot accidentally create resources outside the policy enforcement namespace.

### workloads.yaml

This project governs application deployments. The sole source is the DriftGuard GitOps repo, and destinations are limited to `demo-dev`, `demo-staging`, and `demo-prod`. Namespace-scoped resources include the kinds you would expect for a workload: ConfigMaps, Services, ServiceAccounts, Secrets, Deployments, Rollouts, AnalysisTemplates, Ingresses, ExternalSecrets, and SecretStores. The only cluster-scoped resource allowed is Namespace creation.

### argocd-config.yaml

This is a ConfigMap that sets declarative ArgoCD server configuration. It disables the admin account (you should use OIDC instead) and sets the reconciliation timeout to 180 seconds with zero jitter. It syncs early (wave -5) so these settings are in place before Applications start reconciling.

### argocd-rbac.yaml

This ConfigMap controls ArgoCD's role-based access. The default policy is `role:readonly`, meaning anyone who authenticates but has no explicit role assignment can only view, never modify. The `operator` role can get and sync Applications in the `workloads` and `platform-addons` projects, and can read logs, but cannot exec into pods. The `platform-operators` group is bound to this operator role.

## Why this matters

Without these boundaries, a single misconfigured Application could deploy anything anywhere. The explicit project model means:

- A workload deployment cannot escalate to cluster-admin
- The observability stack cannot modify resources in workload namespaces
- Policy Applications cannot deploy workloads
- Add-on controllers get only the cluster resources they genuinely need

If you need to expand permissions (for example, adding a new CRD kind to a project), do it through a reviewed Git PR and confirm the change is intentional and minimal.
