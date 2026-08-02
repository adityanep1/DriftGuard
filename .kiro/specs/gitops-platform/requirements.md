# Requirements Document

## Introduction

DriftGuard is a GitOps Infrastructure Automation Platform built on AWS EKS. It uses Terraform to provision production-grade infrastructure and ArgoCD to enforce a declarative, pull-based deployment model in which the cluster continuously reconciles its live state against a Git repository. The platform's defining behavior is drift detection and automatic reconciliation: any deviation of live infrastructure or application state from the version-controlled desired state is detected and, where configured, self-healed.

The platform demonstrates end-to-end AWS and platform-engineering depth: EKS, VPC, IAM/IRSA, ECR, ALB, Route53, ACM, S3, and DynamoDB provisioned via Terraform; GitOps delivery via ArgoCD (app-of-apps and ApplicationSets); CI via GitHub Actions; progressive delivery via Argo Rollouts; full observability via the LGTM stack (Loki, Grafana, Tempo, Prometheus/Mimir) with OpenTelemetry; and policy-as-code plus runtime security via OPA/Gatekeeper, Falco, and External Secrets Operator. A containerized demo microservice serves as the real workload that flows through the pipeline.

This document specifies the complete expert-level scope. Requirements are organized so the platform can be built incrementally (foundation → GitOps core → CI → progressive delivery → observability → security → stretch), while capturing the full target vision. The project is cost-sensitive; teardown and cost-control requirements are explicit.

## Glossary

- **Platform**: The complete DriftGuard GitOps Infrastructure Automation Platform, comprising all infrastructure, tooling, and workloads described in this document.
- **Terraform_Module**: A reusable, version-controlled Terraform configuration unit responsible for a defined infrastructure domain (networking, eks, iam, ecr, dns).
- **Terraform_State_Backend**: The remote Terraform state storage and locking mechanism using an S3 bucket and a DynamoDB lock table.
- **EKS_Cluster**: The AWS Elastic Kubernetes Service cluster provisioned by the Platform.
- **Node_Autoscaler**: The component (Karpenter and/or Cluster Autoscaler) that adjusts the number of worker nodes in the EKS_Cluster in response to workload demand.
- **IRSA**: IAM Roles for Service Accounts, the mechanism granting AWS permissions to Kubernetes pods via OIDC-federated IAM roles.
- **ArgoCD**: The GitOps continuous-delivery controller that reconciles EKS_Cluster state against the Config_Repo.
- **Config_Repo**: The Git repository containing the declarative desired state (Kubernetes manifests, Helm values, ArgoCD Applications) for the Platform.
- **Root_Application**: The bootstrap ArgoCD Application that manages all other ArgoCD Applications via the app-of-apps pattern.
- **ApplicationSet**: An ArgoCD controller resource that generates multiple ArgoCD Applications from a template.
- **Drift**: A detected difference between the live state of a managed resource and its desired state as declared in the Config_Repo (for ArgoCD) or Terraform configuration (for infrastructure).
- **Reconciliation**: The process by which ArgoCD brings live EKS_Cluster state back into agreement with the Config_Repo.
- **Self_Heal**: The ArgoCD behavior that automatically reconciles Drift without manual intervention.
- **CI_Pipeline**: The GitHub Actions automation that builds, tests, scans, and publishes container images and updates the Config_Repo.
- **Image_Registry**: The Amazon ECR repositories storing the Platform's container images.
- **Argo_Rollouts**: The progressive-delivery controller providing canary and blue-green deployment strategies with metric-based analysis.
- **Analysis_Run**: An Argo_Rollouts evaluation of metric queries against defined thresholds during a progressive deployment.
- **Observability_Stack**: The LGTM-based telemetry system (Prometheus/metrics, Loki/logs, Tempo/traces, Grafana/dashboards) plus OpenTelemetry instrumentation.
- **SLO**: A Service Level Objective, a target reliability threshold for a defined Service Level Indicator.
- **Burn_Rate_Alert**: A multi-window alert that fires when an SLO's error budget is being consumed faster than a defined rate.
- **Policy_Engine**: OPA/Gatekeeper, the admission-control component enforcing policy-as-code on the EKS_Cluster.
- **Runtime_Security_Agent**: Falco, the component detecting anomalous runtime behavior on the EKS_Cluster.
- **Secret_Operator**: External Secrets Operator (or Sealed Secrets), the component that materializes Kubernetes Secrets from an external secret store without storing plaintext secrets in Git.
- **Demo_Service**: The containerized microservice workload (Python/FastAPI or Node) deployed through the Platform to exercise the GitOps pipeline.
- **Environment**: An isolated deployment target of the Platform, one of dev, staging, or prod.
- **Operator**: A human platform engineer interacting with the Platform.

## Requirements

### Requirement 1: Terraform-Provisioned Network Foundation

**User Story:** As a platform engineer, I want the VPC and networking provisioned declaratively with Terraform, so that the cluster runs on a reproducible, isolated, production-grade network.

#### Acceptance Criteria

1. THE networking Terraform_Module SHALL provision one VPC per Environment with at least one public subnet and at least one private subnet in each of at least two Availability Zones.
2. THE networking Terraform_Module SHALL provision at least one NAT gateway in a public subnet to provide outbound internet access for resources in private subnets.
3. THE networking Terraform_Module SHALL place EKS_Cluster worker nodes in private subnets and SHALL NOT place EKS_Cluster worker nodes in public subnets.
4. THE networking Terraform_Module SHALL apply a tag set including Environment, Project, and ManagedBy to every taggable network resource it provisions.
5. WHERE the Environment is prod, THE networking Terraform_Module SHALL provision one NAT gateway per Availability Zone.
6. THE networking Terraform_Module SHALL provision an internet gateway and configure public subnet routing so that public subnets have a route to the internet gateway.
7. THE networking Terraform_Module SHALL configure private subnet routing so that private subnets reach the internet through the NAT gateway.

### Requirement 2: Terraform-Provisioned EKS Cluster

**User Story:** As a platform engineer, I want the EKS cluster and node groups provisioned with Terraform, so that the Kubernetes control plane and compute are reproducible and version-controlled.

#### Acceptance Criteria

1. THE eks Terraform_Module SHALL provision an EKS_Cluster pinned to an explicitly specified Kubernetes minor version rather than a floating or latest alias.
2. THE eks Terraform_Module SHALL provision at least one managed node group for the EKS_Cluster with explicitly configured minimum, maximum, and desired node counts per Environment.
3. THE eks Terraform_Module SHALL enable an OIDC identity provider on the EKS_Cluster to support IRSA.
4. THE eks Terraform_Module SHALL restrict EKS_Cluster API server access to an allowlist of one or more defined CIDR ranges.
5. THE eks Terraform_Module SHALL NOT permit unrestricted (0.0.0.0/0) access to the EKS_Cluster API server.
6. WHEN the eks Terraform_Module is applied, THE eks Terraform_Module SHALL produce cluster connection outputs including the cluster endpoint, certificate authority data, and the OIDC provider issuer URL.
7. IF the apply operation fails to create the EKS_Cluster, THEN THE eks Terraform_Module SHALL report the failing resource and SHALL produce no cluster connection outputs.

### Requirement 3: Node Autoscaling

**User Story:** As a platform engineer, I want worker nodes to scale automatically, so that workloads get capacity on demand without manual node management and without paying for idle nodes.

#### Acceptance Criteria

1. THE Platform SHALL deploy a Node_Autoscaler (Karpenter or Cluster Autoscaler) to the EKS_Cluster.
2. WHEN one or more pending pods cannot be scheduled due to insufficient node capacity, THE Node_Autoscaler SHALL provision additional worker nodes sufficient to schedule those pending pods within a configurable provisioning window not exceeding 300 seconds.
3. WHILE a worker node's aggregate CPU and memory resource requests remain below a configurable utilization threshold (default 50 percent) for a continuous configurable duration (default 600 seconds), THE Node_Autoscaler SHALL consolidate or terminate that node.
4. IF consolidating or terminating an underutilized worker node would leave any of its pods unschedulable on the remaining worker node capacity, THEN THE Node_Autoscaler SHALL retain that node.
5. THE Node_Autoscaler SHALL enforce a configurable maximum worker node count per Environment to bound compute cost.
6. IF one or more pending pods remain unschedulable and the Environment's configured maximum worker node count has been reached, THEN THE Node_Autoscaler SHALL NOT provision worker nodes beyond that maximum and SHALL leave those pending pods unscheduled.

### Requirement 4: Remote Terraform State Management

**User Story:** As a platform engineer, I want Terraform state stored remotely with locking and encryption, so that state is shared safely across operators and CI without corruption.

#### Acceptance Criteria

1. THE Terraform_State_Backend SHALL store all Terraform state in an S3 bucket with server-side encryption at rest enabled.
2. WHEN a state-mutating operation is initiated, THE Terraform_State_Backend SHALL acquire a lock in its DynamoDB lock table before applying any change to the stored state.
3. IF a state lock is already held when a state-mutating operation is initiated, THEN THE Terraform_State_Backend SHALL block the conflicting operation, report the identity of the existing lock holder, and leave the stored state unchanged.
4. THE Terraform_State_Backend SHALL enable versioning on the S3 state bucket so that prior state revisions are retained and recoverable.
5. THE Terraform_State_Backend SHALL isolate each Environment's state using a distinct state key or backend such that a state-mutating operation on one Environment cannot read or overwrite another Environment's state.
6. WHEN a state-mutating operation terminates, whether by completing, being blocked, or being aborted, THE Terraform_State_Backend SHALL release any lock it acquired for that operation.
7. IF the DynamoDB lock table is unreachable when a lock is requested, THEN THE Terraform_State_Backend SHALL abort the state-mutating operation, report an error indicating the lock could not be acquired, and leave the stored state unchanged.

### Requirement 5: Container Image Registry

**User Story:** As a developer, I want ECR repositories provisioned for container images, so that the Platform has a secure, private registry for the images it deploys.

#### Acceptance Criteria

1. THE ecr Terraform_Module SHALL provision exactly one ECR repository per deployable service, each with a repository name unique within the Environment.
2. THE ecr Terraform_Module SHALL enable encryption at rest on each ECR repository.
3. THE ecr Terraform_Module SHALL enable image scan-on-push on each ECR repository.
4. THE ecr Terraform_Module SHALL apply a lifecycle policy that expires untagged images older than a configurable retention age (default 14 days) to bound storage cost.
5. THE ecr Terraform_Module SHALL configure each ECR repository as private, denying anonymous and public pull access.
6. THE ecr Terraform_Module SHALL apply a tag set including Environment, Project, and ManagedBy to every ECR repository.

### Requirement 6: Ingress, DNS, and TLS

**User Story:** As a platform engineer, I want ingress with DNS and TLS provisioned declaratively, so that deployed services are reachable over HTTPS at stable domain names.

#### Acceptance Criteria

1. THE dns Terraform_Module SHALL provision a Route53 public hosted zone for the Platform's domain and DNS records that resolve each externally exposed service hostname to the AWS Application Load Balancer.
2. THE dns Terraform_Module SHALL provision an ACM certificate whose subject name and subject alternative names cover every externally exposed service hostname of the Platform.
3. THE Platform SHALL route external HTTPS traffic received on TCP port 443 to in-cluster services through an AWS Application Load Balancer.
4. WHEN an HTTP request is received on TCP port 80 for a Platform hostname, THE Platform SHALL respond with a permanent redirect to the same host and path using the HTTPS scheme on TCP port 443.
5. WHERE a service is exposed externally, THE Platform SHALL serve it over an active HTTPS listener using the ACM-provisioned TLS certificate that covers that service's hostname.
6. IF ACM certificate validation does not complete within a defined validation timeout, THEN THE dns Terraform_Module SHALL fail the apply operation and report the certificate as unvalidated without provisioning the dependent HTTPS listener.
7. IF an HTTPS request is received for a hostname not covered by the ACM-provisioned TLS certificate or without a matching DNS record, THEN THE Platform SHALL reject the request with a connection or default-action error response and SHALL NOT route it to an in-cluster service.

### Requirement 7: IRSA Least-Privilege Pod Permissions

**User Story:** As a security-conscious platform engineer, I want pods to receive AWS permissions through IRSA, so that workloads use scoped IAM roles instead of shared node credentials.

#### Acceptance Criteria

1. THE iam Terraform_Module SHALL create exactly one IAM role federated to the EKS_Cluster OIDC provider for each workload that requires AWS access.
2. THE iam Terraform_Module SHALL scope each IRSA role's policy to enumerated AWS actions and resource ARNs and SHALL NOT grant wildcard (`*`) actions or wildcard resources.
3. WHEN a pod annotated with an IRSA service account requests AWS credentials, THE Platform SHALL provide credentials for the mapped IAM role only and no other role.
4. THE iam Terraform_Module SHALL define each IRSA role's trust policy to restrict the role to a single named Kubernetes namespace and service account bound to the EKS_Cluster OIDC provider.
5. IF a service account not mapped to any IRSA role requests AWS credentials, THEN THE Platform SHALL deny the request and issue no credentials.
6. IF a pod's namespace or service account does not match an IRSA role's trust policy, THEN THE Platform SHALL reject the assume-role request and return an authorization failure.

### Requirement 8: Terraform Module Structure and Environment Isolation

**User Story:** As a platform engineer, I want Terraform organized into reusable modules with per-environment isolation, so that changes are safe, repeatable, and scoped to one environment at a time.

#### Acceptance Criteria

1. THE Platform SHALL organize Terraform into distinct, independently reusable Terraform_Modules for networking, eks, iam, ecr, and dns, where each Terraform_Module can be invoked without requiring resource definitions declared inside another Terraform_Module.
2. THE Platform SHALL pin every Terraform provider to a version constraint, with the AWS provider constrained to `~> 5.0`.
3. IF any Terraform provider is declared without a version constraint, THEN THE Platform SHALL fail the operation before applying changes and produce an error indicating which provider is missing a version constraint.
4. THE Platform SHALL maintain separate Terraform configurations or workspaces for exactly the dev, staging, and prod Environments, with each Environment's state stored independently so that no Environment shares state with another.
5. WHEN Terraform is applied to one Environment, THE Platform SHALL modify only the resources belonging to that Environment and SHALL leave the resources of all other Environments unmodified.
6. IF a Terraform apply targeting one Environment fails, THEN THE Platform SHALL leave the resources of every other Environment in their pre-apply state and produce an error indicating the failed Environment.
7. THE Platform SHALL apply a tag set containing exactly the Environment, Project, and ManagedBy tags to every taggable AWS resource it creates or manages.
8. IF a taggable AWS resource is created or managed without all three required tags (Environment, Project, ManagedBy), THEN THE Platform SHALL fail the operation before applying changes and produce an error indicating which required tag is missing.

### Requirement 9: ArgoCD Installation and Bootstrap

**User Story:** As a platform engineer, I want ArgoCD installed declaratively and bootstrapped with a root application, so that the GitOps control plane itself is reproducible and self-managed.

#### Acceptance Criteria

1. THE Platform SHALL install ArgoCD into the EKS_Cluster via Terraform and Helm, and SHALL consider the installation successful only when all ArgoCD control-plane components report a healthy and Ready status within a configurable installation timeout not exceeding 600 seconds.
2. THE Platform SHALL bootstrap ArgoCD with a Root_Application that manages all other ArgoCD Applications.
3. WHEN the Root_Application is created, THE ArgoCD SHALL discover and create every child Application it references from the Config_Repo within a configurable reconciliation interval not exceeding 180 seconds.
4. THE Platform SHALL manage the ArgoCD configuration itself as declarative state in the Config_Repo.
5. IF ArgoCD does not reach a healthy and Ready status within the configurable installation timeout, THEN THE Platform SHALL report the installation as failed identifying the unhealthy component and SHALL NOT proceed to bootstrap the Root_Application.
6. IF the Config_Repo is unreachable or a referenced child Application definition is invalid when the Root_Application is reconciled, THEN THE ArgoCD SHALL mark the Root_Application as degraded, report the unreachable repository or invalid child Application, and SHALL leave already-created child Applications unchanged.

### Requirement 10: App-of-Apps and ApplicationSets

**User Story:** As a platform engineer, I want multiple services managed declaratively through the app-of-apps pattern and ApplicationSets, so that adding or removing services requires only a Git change.

#### Acceptance Criteria

1. THE ArgoCD SHALL manage multiple services using the app-of-apps pattern, where each managed service is represented by a child Application referenced by the Root_Application.
2. THE ArgoCD SHALL use at least one ApplicationSet that generates exactly one Application per target in a target set defined in the Config_Repo, applying a single shared template to each generated Application.
3. WHEN a new service definition is added to the Config_Repo, THE ArgoCD SHALL create the corresponding Application, without any manual ArgoCD configuration, within a configurable generation interval not exceeding 300 seconds.
4. WHEN a service definition is removed from the Config_Repo, THE ArgoCD SHALL remove only the corresponding Application within a configurable generation interval not exceeding 300 seconds, and SHALL leave all other managed Applications unchanged.
5. IF a service definition added to or modified in the Config_Repo is malformed or does not satisfy the ApplicationSet template's required parameters, THEN THE ArgoCD SHALL not generate an Application from that definition, SHALL report an error identifying the rejected service definition, and SHALL leave all previously generated Applications unchanged.

### Requirement 11: Drift Detection and Automatic Reconciliation

**User Story:** As a platform engineer, I want the cluster to continuously reconcile against Git and self-heal drift, so that the live state always matches the declared desired state (the core DriftGuard behavior).

#### Acceptance Criteria

1. THE ArgoCD SHALL compare live EKS_Cluster state against the desired state declared in the Config_Repo at a configurable polling interval not exceeding 180 seconds.
2. WHEN a managed resource's live state differs from its declared state in the Config_Repo, THE ArgoCD SHALL mark the owning Application as OutOfSync.
3. WHERE auto-sync with Self_Heal is enabled for an Application, WHEN Drift is detected, THE ArgoCD SHALL reconcile the live state back to the declared state without manual intervention within a configurable self-heal window not exceeding 120 seconds after Drift detection.
4. WHEN the Config_Repo desired state changes, THE ArgoCD SHALL apply the change to the EKS_Cluster within a configurable reconciliation interval not exceeding 180 seconds.
5. THE ArgoCD SHALL record the outcome of each Reconciliation as Application sync status and history.
6. IF a Reconciliation fails to bring the live state into agreement with the Config_Repo, THEN THE ArgoCD SHALL retry the Reconciliation up to a configurable maximum of 5 attempts, mark the Application sync status as failed after the final attempt, and leave the last known live state unchanged by the failed attempt.

### Requirement 12: Sync Options and Dependency Ordering

**User Story:** As a platform engineer, I want ordered, safe syncs, so that dependent resources deploy in the correct sequence and required namespaces exist.

#### Acceptance Criteria

1. WHEN an Application declares sync waves, THE ArgoCD SHALL apply resources in ascending sync-wave order and SHALL apply all resources within a given wave before beginning any resource in a later wave.
2. WHERE an Application enables the CreateNamespace sync option and targets a namespace that does not exist, THE ArgoCD SHALL create that namespace before applying the Application's namespaced resources.
3. WHILE resources in an earlier sync wave have not reported a healthy status, THE ArgoCD SHALL defer applying resources in later sync waves.
4. IF resources in an earlier sync wave do not reach a healthy status within a configurable sync timeout (default 300 seconds), THEN THE ArgoCD SHALL halt the sync, leave all later-wave resources unapplied, and mark the Application sync as failed with an indication of the sync wave that did not become healthy.
5. IF creating a target namespace fails, THEN THE ArgoCD SHALL halt the sync, apply none of that Application's namespaced resources, and report an error indicating the namespace could not be created.

### Requirement 13: Opt-In Pruning

**User Story:** As a platform engineer, I want resource pruning to be opt-in per application, so that removing a manifest never triggers unintended deletions across unrelated services.

#### Acceptance Criteria

1. THE ArgoCD SHALL disable automatic pruning by default for every Application unless auto-prune is explicitly enabled on that Application, and THE ArgoCD SHALL treat each Application's own pruning setting as taking precedence over any inherited or default pruning setting.
2. WHERE auto-prune is not enabled on an Application, WHEN a resource is removed from that Application's Config_Repo path, THE ArgoCD SHALL mark that Application as OutOfSync and SHALL retain the orphaned live resource without deleting it.
3. WHERE auto-prune is explicitly enabled on a specific Application, WHEN a resource is removed from that Application's Config_Repo path, THE ArgoCD SHALL delete only that Application's orphaned live resource and SHALL NOT delete any resource managed by another Application.
4. IF ArgoCD fails to delete an orphaned resource while pruning an auto-prune-enabled Application, THEN THE ArgoCD SHALL retain that resource and record a failed-prune outcome in the Application's sync status.
5. THE ArgoCD SHALL NOT enable auto-prune at a global or default scope. (Negative statement required to constrain a destructive default.)

### Requirement 14: ArgoCD RBAC and Project Scoping

**User Story:** As a security-conscious platform engineer, I want ArgoCD access hardened with project scoping and RBAC, so that Applications can only affect their permitted destinations.

#### Acceptance Criteria

1. THE ArgoCD SHALL assign every Application to an ArgoCD Project that explicitly enumerates the permitted source repositories, destination clusters, and destination namespaces for that Application.
2. THE ArgoCD SHALL default every ArgoCD Project to deny any source repository, destination cluster, or destination namespace that is not explicitly enumerated in that Project.
3. IF an Application attempts to sync to a source repository, destination cluster, or destination namespace not enumerated in its Project, THEN THE ArgoCD SHALL reject the sync, apply no changes to any destination, and record a policy violation that is retrievable through the Application's status.
4. THE ArgoCD SHALL enforce role-based access control in which each Operator is granted only the permissions explicitly assigned to that Operator's role, and every permission not explicitly assigned is denied.
5. WHEN an Operator requests an ArgoCD action for which the Operator's role holds no explicitly assigned permission, THE ArgoCD SHALL deny the action and record an authorization-denied event retrievable by an administrator.
6. WHEN an alternative authentication method has been configured and verified as able to authenticate at least one administrative Operator, THE ArgoCD SHALL disable the default administrative account.
7. IF the default administrative account is disabled, THEN THE ArgoCD SHALL reject any authentication attempt that uses the default administrative account.

### Requirement 15: CI Pipeline — Build, Test, Scan, Publish

**User Story:** As a developer, I want a CI pipeline that builds, tests, scans, and publishes images, so that only verified images reach the registry.

#### Acceptance Criteria

1. WHEN a commit is pushed to a source branch of the Demo_Service repository, THE CI_Pipeline SHALL build a container image from the committed source within 15 minutes of the push being received.
2. WHEN building an image, THE CI_Pipeline SHALL run the Demo_Service's automated test suite.
3. IF any test in the Demo_Service's automated test suite fails, THEN THE CI_Pipeline SHALL fail the build, stop before the scan stage, and report the count of failed tests.
4. WHEN building an image, THE CI_Pipeline SHALL run a container image security scan.
5. IF the container image security scan detects at least one vulnerability of severity HIGH or CRITICAL, THEN THE CI_Pipeline SHALL fail the build, record the scan stage as the failure point, ensure no image is pushed to the Image_Registry, and report each detected vulnerability at or above that severity.
6. WHEN the build, test, and scan stages all complete without failure, THE CI_Pipeline SHALL push the image to the Image_Registry tagged with the full commit identifier of the triggering commit.
7. IF pushing the image to the Image_Registry fails, THEN THE CI_Pipeline SHALL fail the build, retry the push up to 3 times, and report the push failure if all retries are exhausted without leaving a partially published image tag.
8. IF any stage of the CI_Pipeline fails, THEN THE CI_Pipeline SHALL stop remaining stages and report an error indicating which stage failed.

### Requirement 16: CI-Driven GitOps Update

**User Story:** As a developer, I want CI to update the config repo with the new image tag, so that deployment happens through GitOps rather than direct cluster access.

#### Acceptance Criteria

1. WHEN an image is successfully pushed to the Image_Registry, THE CI_Pipeline SHALL commit an update to the corresponding Demo_Service image tag in the Config_Repo so that the tag references the pushed image's commit identifier.
2. WHEN the Config_Repo image tag is updated, THE ArgoCD SHALL reconcile the Demo_Service to the new image within a configurable reconciliation interval not exceeding 180 seconds.
3. IF the CI_Pipeline fails to commit the image tag update to the Config_Repo, THEN THE CI_Pipeline SHALL stop, report the failing update, and leave the Config_Repo unchanged.
4. THE CI_Pipeline SHALL NOT apply changes directly to the EKS_Cluster using cluster credentials. (Negative statement required to enforce the pull-based GitOps boundary.)

### Requirement 17: Terraform CI and Scheduled Drift Detection

**User Story:** As a platform engineer, I want Terraform validated on PRs, applied on merge, and checked for drift on a schedule, so that infrastructure changes are reviewed and infrastructure drift is surfaced.

#### Acceptance Criteria

1. WHEN a pull request modifies Terraform configuration, THE CI_Pipeline SHALL run `terraform plan` for the affected Environment and publish the resulting plan output to that pull request.
2. WHEN a pull request modifying Terraform configuration is merged, THE CI_Pipeline SHALL run `terraform apply` for the affected Environment and SHALL modify only the resources belonging to that Environment.
3. THE CI_Pipeline SHALL run a scheduled infrastructure Drift check for each Environment using `terraform plan -detailed-exitcode` at a configurable interval, with a recommended default interval of 24 hours.
4. IF the scheduled Drift check detects infrastructure Drift, THEN THE CI_Pipeline SHALL report the detected Drift, including the affected Environment and the differing resources, to Operators.
5. IF `terraform plan` fails during a pull request check, THEN THE CI_Pipeline SHALL mark the pull request check as failed, publish the failure output to the pull request, and apply no changes to any Environment.
6. IF `terraform apply` fails after a pull request modifying Terraform configuration is merged, THEN THE CI_Pipeline SHALL halt the apply, report the failing resource to Operators, and leave the affected Environment's resources in their pre-apply state.
7. IF the scheduled Drift check cannot complete because `terraform plan -detailed-exitcode` returns its error exit code, THEN THE CI_Pipeline SHALL report the check as failed to Operators and SHALL NOT report the affected Environment as drift-free.
8. WHEN a scheduled Drift check completes and detects no infrastructure Drift for an Environment, THE CI_Pipeline SHALL report a no-drift-detected status for that Environment to Operators.

### Requirement 18: Progressive Delivery with Argo Rollouts

**User Story:** As a platform engineer, I want canary and blue-green deployments with automated rollback, so that releases are safe and bad versions are withdrawn automatically.

#### Acceptance Criteria

1. THE Platform SHALL deploy Argo_Rollouts to the EKS_Cluster.
2. THE Platform SHALL support both canary and blue-green deployment strategies for the Demo_Service.
3. WHEN a new Demo_Service version is deployed via a canary strategy, THE Argo_Rollouts SHALL shift traffic to the new version in incremental steps of 20 percent (20%, 40%, 60%, 80%, 100%), holding each step for a defined pause of 300 seconds before proceeding to the next step.
4. WHILE a progressive deployment is in progress, THE Argo_Rollouts SHALL run an Analysis_Run at each canary step that evaluates the error-rate metric against a threshold of 5 percent and the p95 latency metric against a threshold of 500 milliseconds, measured over the preceding 300-second window.
5. IF an Analysis_Run reports the error-rate metric exceeding 5 percent or the p95 latency metric exceeding 500 milliseconds, THEN THE Argo_Rollouts SHALL abort the deployment within 60 seconds, roll back all traffic to the previous stable version, and record the deployment state as failed with an indication of the breaching metric.
6. IF the metrics required by an Analysis_Run are unavailable or cannot be retrieved within 60 seconds, THEN THE Argo_Rollouts SHALL record the Analysis_Run result as ANALYSIS_FAILED, abort the deployment, and roll back all traffic to the previous stable version.
7. WHEN an Analysis_Run passes at every canary step, THE Argo_Rollouts SHALL promote the new version to 100 percent of traffic and record the deployment state as succeeded.

### Requirement 19: Metrics, Logs, and Traces Collection

**User Story:** As an operator, I want metrics, logs, and traces collected across the platform, so that I can observe system behavior and diagnose issues.

#### Acceptance Criteria

1. THE Platform SHALL deploy the Observability_Stack (Prometheus/metrics, Loki/logs, Tempo/traces, Grafana) to the EKS_Cluster, and SHALL consider the deployment successful only when all Observability_Stack components report a healthy and Ready status within a configurable installation timeout not exceeding 600 seconds.
2. WHEN the Demo_Service processes a request, THE Demo_Service SHALL emit metrics, logs, and traces for that request using OpenTelemetry instrumentation.
3. WHEN the Demo_Service processes a request, THE Observability_Stack SHALL capture a distributed trace for that request and make it queryable in Grafana within 30 seconds.
4. THE Observability_Stack SHALL retain collected metrics for at least 15 days, logs for at least 7 days, and traces for at least 3 days.
5. WHEN an Operator opens or refreshes an Observability_Stack dashboard, THE Observability_Stack SHALL present metrics, logs, and traces through Grafana dashboards populated within 10 seconds.
6. IF collection of one telemetry signal type fails, THEN THE Observability_Stack SHALL continue collecting the unaffected signal types and report the failed signal type.
7. WHEN collected telemetry exceeds the retention period for its signal type, THE Observability_Stack SHALL discard the expired telemetry.
8. WHILE all three telemetry signal types (metrics, logs, and traces) are failing simultaneously, THE Observability_Stack SHALL report all three failures and SHALL NOT attempt to collect any signal type until at least one signal type recovers.

### Requirement 20: SLO Dashboards and Burn-Rate Alerting

**User Story:** As an operator, I want SLO dashboards and burn-rate alerts, so that I am notified when reliability targets are at risk before the error budget is exhausted.

#### Acceptance Criteria

1. THE Observability_Stack SHALL define at least one SLO for the Demo_Service with an explicit Service Level Indicator and a target expressed as a percentage between 0.0 and 100.0 measured over a configurable rolling window (default 28 days).
2. WHEN an Operator opens or refreshes the SLO dashboard, THE Observability_Stack SHALL present each SLO's current attainment and remaining error budget as percentages using telemetry no older than a configurable refresh interval not exceeding 60 seconds.
3. WHEN an SLO's error budget is consumed faster than a defined multi-window burn rate, evaluated over both a long window and a short window against a defined burn-rate threshold, THE Observability_Stack SHALL fire a Burn_Rate_Alert that identifies the affected SLO and deliver it to an Operator notification channel.
4. IF the telemetry required to compute an SLO's attainment is unavailable or insufficient, THEN THE Observability_Stack SHALL present that SLO's attainment and remaining error budget as unknown, SHALL NOT report the SLO as compliant, and SHALL indicate the missing telemetry to the Operator.
5. WHERE DORA metrics are enabled, THE Observability_Stack SHALL display deployment frequency, lead time for changes, change failure rate, and time to restore service over a configurable reporting window (default 30 days).

### Requirement 21: Policy-as-Code Admission Control

**User Story:** As a security-conscious platform engineer, I want admission policies enforced with OPA/Gatekeeper, so that non-compliant workloads are blocked before they run.

#### Acceptance Criteria

1. THE Platform SHALL deploy the Policy_Engine (OPA/Gatekeeper) to the EKS_Cluster, and SHALL consider the deployment successful only when all Policy_Engine components report a healthy and Ready status within a configurable installation timeout not exceeding 600 seconds.
2. IF a workload requests a privileged container, THEN THE Policy_Engine SHALL reject the workload admission, prevent the workload from being created in the EKS_Cluster, and return an admission response identifying the violated policy.
3. THE Policy_Engine SHALL evaluate every admission request for a workload created or updated in the EKS_Cluster against a defined baseline policy set including restrictions on privileged containers, host namespace usage (host PID, host IPC, and host network), and required resource labels (Environment, Project, and ManagedBy).
4. WHEN a workload complies with all policies in the enforced baseline policy set, THE Policy_Engine SHALL admit the workload and permit it to be created in the EKS_Cluster.
5. THE Platform SHALL manage all Policy_Engine policies as declarative state in the Config_Repo, and WHEN a policy definition in the Config_Repo changes, THE Platform SHALL reconcile the enforced Policy_Engine policy set to match the Config_Repo within a configurable reconciliation interval not exceeding 180 seconds.
6. IF the Policy_Engine cannot complete evaluation of an admission request against the baseline policy set, THEN THE Policy_Engine SHALL reject the workload admission, prevent the workload from being created in the EKS_Cluster, and report that the admission evaluation could not be completed.

### Requirement 22: Runtime Threat Detection

**User Story:** As a security-conscious platform engineer, I want runtime threat detection with Falco, so that anomalous in-cluster behavior is detected after workloads start running.

#### Acceptance Criteria

1. THE Platform SHALL deploy the Runtime_Security_Agent (Falco) to the EKS_Cluster, and SHALL consider the deployment successful only when all Runtime_Security_Agent components report a healthy and Ready status within a configurable installation timeout not exceeding 600 seconds.
2. WHEN in-cluster activity matches a defined Runtime_Security_Agent detection rule, THE Runtime_Security_Agent SHALL generate a security alert that identifies the matched rule, the involved workload, and the matched rule's severity level within 30 seconds of the matching activity.
3. WHEN the Runtime_Security_Agent generates a security alert, THE Runtime_Security_Agent SHALL forward that alert to the Observability_Stack within 30 seconds of generating it.
4. IF the Runtime_Security_Agent does not reach a healthy and Ready status within the configurable installation timeout, THEN THE Platform SHALL report the deployment as failed and identify the unhealthy component.
5. IF forwarding a generated alert to the Observability_Stack fails, THEN THE Runtime_Security_Agent SHALL retry the forward up to a configurable maximum of 3 attempts, retain the unforwarded alert without discarding it, and report the forwarding failure after the final attempt is exhausted.

### Requirement 23: Secret Management Without Plaintext in Git

**User Story:** As a security-conscious platform engineer, I want secrets managed through an external secret store, so that no plaintext secrets are committed to Git.

#### Acceptance Criteria

1. WHEN the Platform provisions the EKS_Cluster, THE Platform SHALL deploy the Secret_Operator (External Secrets Operator or Sealed Secrets) to the EKS_Cluster and confirm the Secret_Operator reaches a ready state within 300 seconds.
2. WHEN a workload requires a secret, THE Secret_Operator SHALL materialize the corresponding Kubernetes Secret from the external secret store within 60 seconds of the workload's deployment request.
3. THE Platform SHALL store only encrypted secret references or ciphertext in the Config_Repo and SHALL reject any commit or apply operation containing plaintext secret values.
4. IF the external secret store returns no successful response within 30 seconds after 3 retry attempts, THEN THE Secret_Operator SHALL mark the affected secret's synchronization status as failed with an indication identifying the unreachable store.
5. IF the external secret store is unreachable, THEN THE Secret_Operator SHALL leave the dependent workload's Kubernetes Secret unpopulated and SHALL preserve any previously materialized secret values without overwriting them.

### Requirement 24: Terraform Security Posture

**User Story:** As a security-conscious platform engineer, I want the Terraform configuration to enforce a strong security baseline, so that the provisioned infrastructure is secure by default.

#### Acceptance Criteria

1. THE Platform SHALL define all IAM policies in Terraform with explicitly enumerated action and resource scopes, and SHALL NOT declare a policy statement that combines a wildcard ("*") action with a wildcard ("*") resource.
2. THE Platform SHALL enable encryption at rest for the S3 state bucket, all ECR repositories, and EKS secrets, such that each of these resources has its encryption-at-rest setting explicitly set to enabled.
3. THE Platform SHALL restrict every security group ingress rule to explicitly defined port ranges and source CIDR ranges, and SHALL NOT permit ingress from the unrestricted source range 0.0.0.0/0 (or ::/0) to administrative ports (SSH port 22 and RDP port 3389).
4. THE Platform SHALL store no hardcoded secret values in Terraform configuration or committed variable files, such that secret values are supplied only through runtime-injected inputs or an external secret source.
5. WHEN Terraform configuration is validated in CI, THE CI_Pipeline SHALL run a Terraform security scan and report the full list of findings with their severity levels within 300 seconds.
6. IF the Terraform security scan detects one or more findings at HIGH or CRITICAL severity, including any detected hardcoded secret value, THEN THE CI_Pipeline SHALL fail the validation, block the merge, and report the failing findings.

### Requirement 25: Demo Application Workload

**User Story:** As a platform engineer, I want a real containerized demo microservice, so that the GitOps pipeline has a genuine workload to build, deploy, and observe.

#### Acceptance Criteria

1. THE Platform SHALL include a Demo_Service implemented as a containerized microservice using Python/FastAPI or Node.
2. WHEN the Demo_Service health endpoint receives an HTTP GET request AND the Demo_Service is ready to serve traffic, THE Demo_Service SHALL respond within 2 seconds with a success status indicating readiness.
3. IF the Demo_Service health endpoint receives an HTTP GET request AND the Demo_Service is not ready to serve traffic, THEN THE Demo_Service SHALL respond with a failure status indicating a not-ready condition and SHALL NOT report readiness.
4. WHEN the CI_Pipeline commits an updated Demo_Service image tag to the Config_Repo, THE ArgoCD SHALL deploy the Demo_Service to the EKS_Cluster by reconciling the Config_Repo within a configurable reconciliation interval not exceeding 180 seconds.
5. THE Demo_Service SHALL NOT be deployed to or modified on the EKS_Cluster by any mechanism other than ArgoCD reconciliation of the Config_Repo. (Negative statement required to enforce the pull-based GitOps boundary.)
6. WHEN the Observability_Stack scrapes the Demo_Service metrics endpoint via an HTTP GET request, THE Demo_Service SHALL respond within 2 seconds with metrics in a Prometheus-compatible exposition format consumable by the Observability_Stack.

### Requirement 26: Cost Control and Teardown

**User Story:** As a cost-conscious owner, I want reliable teardown and cost controls, so that I do not incur ongoing AWS charges when the platform is idle (this is a high-cost project).

#### Acceptance Criteria

1. THE Platform SHALL provide a single Terraform-driven teardown procedure that, when invoked for a specified Environment, destroys all AWS resources provisioned for that Environment.
2. WHEN the teardown procedure completes for an Environment, THE Platform SHALL leave zero running billable compute instances, zero NAT gateways, and zero load balancers associated with that Environment.
3. IF the teardown procedure fails to destroy one or more resources for an Environment, THEN THE Platform SHALL report each resource that remains, indicate that teardown did not complete successfully, and retain the remaining resources without partial modification so the procedure can be safely re-run.
4. WHEN the Platform provisions a taggable AWS resource for an Environment, THE Platform SHALL apply cost-allocation tags containing the Environment identifier and the Project identifier to that resource.
5. THE Platform SHALL enforce a configurable maximum node count per Environment, where the configured value is a whole number between 1 and 1000 nodes.
6. IF a scaling operation would cause an Environment's node count to exceed its configured maximum, THEN THE Platform SHALL reject the operation, keep the node count at or below the configured maximum, and return a response indicating the maximum node count was reached.
7. THE Platform SHALL document, for each Environment, the estimated cost expressed as both an hourly rate in USD and a monthly rate in USD.

### Requirement 27: Reproducibility and Documentation

**User Story:** As an operator or interviewer, I want the platform to be reproducible from documentation, so that it can be stood up from scratch and explained clearly.

#### Acceptance Criteria

1. THE Platform SHALL provide documentation that specifies the ordered provisioning sequence from an empty AWS account to a running Platform, including for each step its prerequisites, the command or action to perform, and the observable completion condition that indicates the step succeeded.
2. WHEN the documented provisioning procedure is followed on an AWS account containing no Platform-created resources, THE Platform SHALL reach a running state in which the Demo_Service is deployed via GitOps and returns a successful health-check response over HTTPS.
3. IF any step of the documented provisioning procedure fails to reach its stated completion condition, THEN THE Platform documentation SHALL provide a remediation or verification action for that step, and the procedure SHALL indicate which step failed without leaving subsequent steps as completed.
4. THE Platform SHALL document each architectural component with its name, its purpose, and its relationship to at least one other component, such that every component referenced in the provisioning procedure has a corresponding description.
5. THE Platform SHALL pin every tool and chart used in provisioning to an exact version identifier, such that two provisioning runs from the same documentation install identical tool and chart versions.

### Requirement 28: Crossplane Provisioning from Kubernetes (Stretch)

**User Story:** As a platform engineer, I want to optionally provision AWS resources from within Kubernetes using Crossplane, so that I can demonstrate control-plane-driven infrastructure provisioning.

#### Acceptance Criteria

1. WHERE the Crossplane stretch feature is enabled, THE Platform SHALL install Crossplane with the AWS provider into the EKS_Cluster, and SHALL consider the installation successful only when all Crossplane components report a healthy and Ready status within a configurable installation timeout not exceeding 600 seconds.
2. WHERE the Crossplane stretch feature is enabled, IF Crossplane does not reach a healthy and Ready status within the configurable installation timeout, THEN THE Platform SHALL report the installation as failed identifying the unhealthy component and SHALL reject Crossplane resource claims.
3. WHERE the Crossplane stretch feature is enabled, WHEN a Crossplane resource claim is applied via GitOps, THE Platform SHALL provision the corresponding AWS resource within a configurable provisioning window not exceeding 900 seconds and record the provisioned resource as ready in the claim status.
4. WHERE the Crossplane stretch feature is enabled, IF provisioning the AWS resource for a claim fails, THEN THE Platform SHALL record the failure in the claim status, report the failure to Operators, and SHALL NOT mark the claim as ready.
5. WHERE the Crossplane stretch feature is enabled, WHEN a Crossplane resource claim is deleted via GitOps, THE Platform SHALL deprovision the corresponding AWS resource within a configurable deprovisioning window not exceeding 900 seconds and leave no billable AWS resource for that claim.
6. WHERE the Crossplane stretch feature is enabled, IF deprovisioning the AWS resource for a deleted claim fails, THEN THE Platform SHALL retain the deletion state, report the failure to Operators, and SHALL NOT report the resource as removed.
