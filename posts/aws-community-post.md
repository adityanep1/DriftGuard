# Building a Self-Healing GitOps Platform on AWS EKS (and the bugs that only surface at deploy time)

I wanted to build something that demonstrates real platform engineering depth on AWS: not a tutorial cluster, but a complete infrastructure platform with drift detection, automatic reconciliation, progressive delivery, and policy enforcement. I called it DriftGuard.

The platform is open source at [github.com/suletetes/DriftGuard](https://github.com/suletetes/DriftGuard), and this post covers the architecture, the AWS services involved, and the practical lessons from deploying it to a real account.

## Architecture overview

DriftGuard uses a two-layer control model that separates imperative provisioning from declarative reconciliation:

![The two-layer control model](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/01-two-layer-control.png)

**Terraform (day 0/1)** provisions the AWS substrate: VPC with public and private subnets across two availability zones, an EKS cluster with managed node groups (private placement only), IAM roles federated through IRSA, private ECR repositories with scan-on-push, Route53/ACM for DNS and TLS, an S3 state backend with DynamoDB locking, and a one-time Helm install of ArgoCD.

**ArgoCD (day 2)** takes over and owns everything inside the cluster: platform add-ons (Karpenter, AWS Load Balancer Controller, External Secrets Operator, Gatekeeper, Falco, Argo Rollouts), the observability stack (Prometheus, Grafana, Loki, Tempo, OpenTelemetry), admission policies, and application workloads.

The boundary is deliberate. Terraform manages resources whose lifecycle is external to Kubernetes and whose creation is a prerequisite for the cluster to exist. ArgoCD manages resources that benefit from continuous drift correction. The handoff point is the ArgoCD install.

## AWS services and their roles

![AWS infrastructure and network topology](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/02-aws-infrastructure.png)

| Service | Role in DriftGuard |
|---|---|
| **EKS** | Kubernetes control plane (pinned to 1.30, secrets encrypted with KMS, OIDC enabled for IRSA) |
| **VPC/Subnets** | Network isolation; workers in private subnets only, ALB in public subnets |
| **NAT Gateway** | Outbound internet for private nodes (1 per AZ in prod, 1 total in dev) |
| **IAM + OIDC** | Short-lived credentials for pods (IRSA) and CI (GitHub OIDC federation, no static keys) |
| **ECR** | Private image registry with scan-on-push, immutable tags, lifecycle expiration |
| **Route53 + ACM** | DNS resolution and TLS termination at the ALB |
| **KMS** | EKS secrets encryption at rest |
| **S3 + DynamoDB** | Terraform state backend with encryption, versioning, and lock-based concurrency control |
| **Secrets Manager** | External secret store consumed by External Secrets Operator (no plaintext in Git) |

## Security posture

The platform was designed with least privilege as a constraint, not an afterthought:

- Every pod that needs AWS access gets its own IRSA role scoped to enumerated actions and resource ARNs. No role combines wildcard actions with wildcard resources (enforced by OPA policy).
- The EKS API endpoint is restricted to an explicit CIDR allowlist. `0.0.0.0/0` and `::/0` are rejected before apply by variable validation.
- CI uses GitHub OIDC federation for short-lived assume-role credentials. No long-lived access keys stored anywhere.
- Gatekeeper admission policies reject privileged containers, host namespaces, and missing required labels. The webhook is configured fail-closed.
- The Config Repo secret scanner runs in CI and as a pre-commit hook. It catches AWS keys, PEM blocks, credential assignments, and high-entropy tokens.

## GitOps and progressive delivery

![GitOps control plane](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/03-gitops-control-plane.png)

ArgoCD polls the Config Repo every 180 seconds. When it detects drift (live state differs from Git), it marks the Application `OutOfSync`. With self-heal enabled, it reverts the change within 120 seconds.

I tested this by patching a live Rollout's replica count from 2 to 5 via kubectl. ArgoCD detected `OutOfSync` immediately and self-healed within two minutes. No human action required.

The demo workload deploys through Argo Rollouts with a canary strategy: five weight steps (20% through 100%), each with a Prometheus-backed analysis check for error rate and p95 latency. A breach aborts the rollout and restores the previous stable version.

![Runtime delivery and progressive rollout](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/05-runtime-delivery.png)

## CI/CD: the pull-based boundary

![CI/CD delivery flow](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/04-cicd-delivery.png)

The delivery model enforces a strict boundary: CI builds, tests, scans, and publishes the container image to ECR, then commits the new tag to the Config Repo. ArgoCD reconciles from Git. CI never touches the cluster directly.

This means a compromised CI pipeline gives an attacker ECR push (scoped) and a Git commit (auditable and reviewable). It does not give them `kubectl exec` on running pods or access to the EKS API.

## Lessons from deploying to a real account

The offline test suite (38 property tests, OPA policies, conftest, kubeconform) passed cleanly. But `terraform plan` against a real AWS account revealed bugs that no offline check caught:

- Terraform's `for_each` requires string sets, not number sets. The networking module used `toset(range(...))` which produces numbers.
- A DNS module validation called `trimspace()` on a nullable variable, crashing the plan even when DNS was disabled.
- Kustomize's load restrictor rejected a manifest reference that reached outside its base directory. ArgoCD couldn't render the workload.
- Argo Rollouts rejected an AnalysisTemplate with no bounded `count`, treating it as "runs indefinitely."
- Karpenter's EC2NodeClass hardcoded a production cluster name, silently targeting the wrong security groups in dev.

Each of these works fine in isolation and passes offline tests. They only break when you run the actual tool chain against real infrastructure with real controllers evaluating real CRDs.

The lesson: run `terraform plan` in CI from day one, even without applying. Run `kustomize build` with the real kustomize binary. And validate AnalysisTemplates against a real Argo Rollouts controller, not just against YAML schema.

## Cost and teardown

A dev environment runs at roughly $0.35/hour (EKS control plane + 2 t3.medium nodes + 1 NAT gateway). The teardown script drains ingress-backed Services first (to remove the ALB), then runs `terraform destroy`. After a successful teardown I verified zero EKS clusters, zero running instances, zero NAT gateways, and zero load balancers remaining in the account.

## Repository

The full source is at [github.com/suletetes/DriftGuard](https://github.com/suletetes/DriftGuard). It includes:
- Terraform modules for networking, EKS, IAM/IRSA, ECR, DNS, and ArgoCD bootstrap
- ArgoCD app-of-apps with ApplicationSets, AppProjects, and sync-wave ordering
- Kustomize-based workload overlays with per-environment isolation
- Property tests (Hypothesis), OPA/Rego policies, and a Prometheus SLO rule test suite
- Architecture diagrams generated as code with the Python `diagrams` library
- A provisioning runbook documenting the ordered sequence from empty account to running platform

---

*AWS services used: EKS, VPC, EC2, IAM, ECR, Route53, ACM, KMS, S3, DynamoDB, Secrets Manager. Open-source tools: Terraform, ArgoCD, Argo Rollouts, Karpenter, Gatekeeper/OPA, Falco, External Secrets Operator, Prometheus, Grafana, Loki, Tempo, OpenTelemetry.*
