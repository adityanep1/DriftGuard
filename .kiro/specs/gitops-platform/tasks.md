# Implementation Plan: DriftGuard — GitOps Infrastructure Automation Platform

## Overview

This plan converts the design into incremental, test-driven coding/config tasks. It follows the design's
bootstrap order and two-layer control model (ADR-004): Terraform provisions the AWS substrate and the
one-time ArgoCD install (day 0/1); ArgoCD then delivers everything else from the `Config_Repo` (day 2).

Sequence: Terraform bootstrap + repo scaffolding → networking → eks → iam/IRSA → ecr → dns → per-env
composition → ArgoCD bootstrap + app-of-apps/ApplicationSets/AppProjects → platform add-ons in sync-wave
order → observability → Demo_Service → CI/CD → cost/teardown/docs → E2E smoke → Crossplane (optional).

Two languages carry the authored logic that is property-tested: **Terraform + conftest/OPA Rego** over
`terraform plan -json`, **Rego** for Gatekeeper admission, and **Python (Hypothesis)** for the no-plaintext
scanner and node-cap validation. External controllers (ArgoCD, Rollouts, Karpenter, Gatekeeper webhook,
Falco, ESO) are validated by conformance/snapshot, integration, and end-to-end smoke tests, not PBT.

Every property test MUST run a minimum of 100 iterations and carry the tag
**`Feature: gitops-platform, Property N: <property text>`**.

### Kiro Hook Opportunities (policy-as-code guardrails)

This project benefits from automated guardrails. The following Kiro hooks can be created to enforce the
design's fail-closed posture on every edit (verify-RLS is N/A — there is no database):

- **verify-terraform-security** — `fileEdited` on `**/*.tf`, `**/*.tfvars` → run `tfsec`/`Checkov` +
  `conftest` over `terraform plan -json`; surfaces R24.5/R24.6 (P1, P2, P4, P5) before commit.
- **verify-argocd-invariants** — `fileEdited` on `driftguard-gitops/**/*.yaml` → run `kubeconform` +
  `conftest` for the ArgoCD manifest invariants (prune opt-in P7, App→Project default-deny P8) and
  Gatekeeper policy tests.
- **guard-secrets** — `fileCreated`/`fileEdited` on `driftguard-gitops/**` (esp. `secrets/`) → run the
  no-plaintext-secrets scanner (P9, R23.3/R24.4); reject plaintext before it ever reaches Git.

Hook creation is noted here for the operator; the underlying checks are implemented as tasks below so they
also run in CI.

## Tasks

- [x] 1. Repository scaffolding, Terraform state backend, and conformance harness
  - [x] 1.1 Scaffold both repositories with pinned versions
    - Create `driftguard-infra/` (`bootstrap/`, `modules/`, `live/{dev,staging,prod}/`, `policies/`,
      `.github/workflows/`) and `driftguard-gitops/` layouts per the design's repo/module layout
    - Author `versions.tf` (`required_version`) + `providers.tf` with AWS provider `~> 5.0`, every provider
      pinned, and `default_tags` set to exactly `{Environment, Project, ManagedBy}`
    - _Requirements: 8.1, 8.2, 8.7, 27.5_

  - [x] 1.2 Implement the `bootstrap/` Terraform state backend
    - S3 state bucket with SSE and versioning enabled; DynamoDB lock table; local-state-then-migrate README
    - _Requirements: 4.1, 4.2, 4.4_

  - [x] 1.3 Set up the static/conformance and property-test harness
    - Wire `terraform fmt -check`, `validate`, `tflint`, `tfsec`/`Checkov`, `conftest`, `kubeconform` runners
    - Scaffold the `policies/` conftest/OPA rule directory (over `terraform plan -json`) and a Python
      Hypothesis test project (≥100 iterations config) for authored-logic properties
    - _Requirements: 24.5, 8.3, 2.1_

  - [x] 1.4 Write conformance rules for provider pinning and per-env backend isolation
    - Rule: any provider lacking a version constraint fails before apply; each env uses a distinct
      `env/<env>/terraform.tfstate` backend key
    - _Requirements: 8.3, 8.4_

- [x] 2. Implement the `networking` module
  - [x] 2.1 Implement VPC/subnet/NAT/IGW/route topology
    - One VPC per env; ≥1 public + ≥1 private subnet across ≥2 AZs; nodes private-only; NAT-per-AZ in prod;
      IGW + public/private route tables; tag every resource
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

  - [x] 2.2 Implement the universal tag-completeness conformance rule
    - conftest/OPA rule over plan JSON: reject any taggable resource missing exactly one of
      `Environment`/`Project`/`ManagedBy` or with an empty value
    - _Requirements: 1.4, 8.7, 8.8, 26.4_

  - [x] 2.3 Write property test for tag completeness
    - **Property 1: Universal tag completeness**
    - **Validates: Requirements 1.4, 5.6, 8.7, 8.8, 26.4**

  - [x] 2.4 Write property test for security-group admin-port exposure
    - **Property 5: Security-group ingress never opens administrative ports to the world**
    - **Validates: Requirements 24.3**

  - [x] 2.5 Run static + security conformance for networking
    - `terraform validate`/`tflint`/`tfsec` clean on the module and its example root
    - _Requirements: 24.5, 24.6_

- [x] 3. Implement the `eks` module
  - [x] 3.1 Implement EKS control plane, node groups, OIDC, and outputs
    - Pin an explicit k8s minor (no `latest`); ≥1 managed node group with explicit min/max/desired; enable
      OIDC; restrict API to a CIDR allowlist; emit `cluster_endpoint`/`cluster_ca_data`/`oidc_*` outputs;
      produce no connection outputs on create failure
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 3.2 Implement API-allowlist validation logic
    - Reject empty lists and any `0.0.0.0/0` or `::/0` entry before apply
    - _Requirements: 2.4, 2.5_

  - [x] 3.3 Write property test for the EKS API allowlist
    - **Property 4: EKS API allowlist excludes unrestricted CIDRs**
    - **Validates: Requirements 2.4, 2.5**

  - [x] 3.4 Write conformance rules for pinned k8s minor, private node placement, and encryption-at-rest
    - Assert pinned minor (R2.1), nodes only in private subnets (R1.3), EKS secrets encryption enabled (R24.2)
    - _Requirements: 2.1, 1.3, 24.2_

- [x] 4. Implement the `iam` module (IRSA)
  - [x] 4.1 Implement per-workload IRSA roles with least-privilege policies
    - One OIDC-federated role per workload; enumerated actions + resource ARNs; trust policy bound to a
      single `namespace:serviceaccount`
    - _Requirements: 7.1, 7.2, 7.4, 24.1_

  - [x] 4.2 Implement IAM wildcard and IRSA trust conformance rules
    - conftest/OPA rule over plan JSON: reject wildcard-action + wildcard-resource; assert single `sub`
      binding with no wildcard/multi service account
    - _Requirements: 7.2, 7.4, 24.1_

  - [x] 4.3 Write property test for IAM wildcard combinations
    - **Property 2: IAM statements never combine wildcard action with wildcard resource**
    - **Validates: Requirements 7.2, 24.1**

  - [x] 4.4 Write property test for IRSA trust-policy scoping
    - **Property 3: IRSA trust policy binds exactly one namespace and service account**
    - **Validates: Requirements 7.4**

- [x] 5. Implement the `ecr` module
  - [x] 5.1 Implement per-service private ECR repositories
    - One private repo per service (unique per env); encryption at rest; scan-on-push; lifecycle expiring
      untagged images (default 14d); required tags
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x] 5.2 Run tag + encryption conformance for ECR
    - Reuse Property 1 tag rule; assert encryption-at-rest flag set
    - _Requirements: 5.2, 5.6, 24.2_

- [x] 6. Implement the `dns` module
  - [x] 6.1 Implement Route53 zone/records, ACM certificate, and DNS validation
    - Public hosted zone + records to the ALB; ACM cert covering every external hostname; DNS validation with
      a timeout that fails the apply and skips the HTTPS listener on timeout
    - _Requirements: 6.1, 6.2, 6.6_

  - [x] 6.2 Run static + validate conformance for dns
    - `terraform validate`/`tflint`/`tfsec` clean on the module
    - _Requirements: 24.5_

- [x] 7. Checkpoint — modules pass static, security, and property gates
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Compose per-environment roots and node-cap validation
  - [x] 8.1 Wire `live/{dev,staging,prod}` module composition
    - Distinct backend keys per env; env-specific tfvars (sizing, node cap, `nat_per_az`); documented per-env
      cost estimate placeholders
    - _Requirements: 8.4, 8.5, 2.2, 3.5, 1.5, 26.5, 26.7_

  - [x] 8.2 Implement node-count cap validation logic
    - Accept `max_node_count` only as a whole number in [1, 1000]; reject scaling requests over the cap and
      clamp the resulting count at or below the cap
    - _Requirements: 26.5, 26.6, 3.5_

  - [x] 8.3 Write property test for node-count cap validation
    - **Property 10: Node-count cap validation**
    - **Validates: Requirements 26.5, 26.6**

- [x] 9. Bootstrap ArgoCD via Terraform (the day 0/1 → day 2 handoff)
  - [x] 9.1 Implement `modules/addons-bootstrap` ArgoCD install + Root_Application seed
    - `helm_release` install (pinned chart) gated on all control-plane components Healthy/Ready ≤600s; on
      failure report the unhealthy component and do NOT create the Root_Application; seed a `Root_Application`
      pointing at `Config_Repo/bootstrap/root-app.yaml`
    - _Requirements: 9.1, 9.2, 9.5_

  - [x] 9.2 Write integration test for Root_Application child discovery
    - Root_Application creates all referenced children ≤180s against an ephemeral cluster
    - Script authored: `driftguard-infra/scripts/integration-argocd.ps1`
    - **Blocked check**: Execution requires an ephemeral cluster with ArgoCD deployed (kubectl + argocd CLI context)
    - _Requirements: 9.3_

- [x] 10. Author the Config_Repo GitOps control plane (app-of-apps, ApplicationSets, Projects, RBAC)
  - [x] 10.1 Author `bootstrap/root-app.yaml` and default-deny AppProjects
    - Root app-of-apps entrypoint; AppProjects for platform-addons/observability/security/workloads with
      explicitly enumerated `sourceRepos`, `destinations`, `clusterResourceWhitelist` (no wildcards)
    - _Requirements: 9.2, 10.1, 14.1, 14.2_

  - [x] 10.2 Author ApplicationSets for platform add-ons and workloads
    - Generators producing exactly one Application per target from a shared template; add/remove a target
      creates/removes only that App ≤300s; malformed targets rejected without disturbing existing Apps
    - _Requirements: 10.2, 10.3, 10.4, 10.5_

  - [x] 10.3 Configure Application sync policy defaults
    - Reconcile/poll ≤180s; self-heal window ≤120s; retry limit 5; sync-wave ordering with 300s wave-health
      timeout; `CreateNamespace` opt-in; prune disabled by default (opt-in per Application, never global)
    - _Requirements: 11.1, 11.3, 11.4, 11.6, 12.1, 12.2, 12.3, 12.4, 13.1, 13.5_

  - [x] 10.4 Implement ArgoCD manifest invariant conformance checks
    - `kubeconform` schema validation of every manifest; `conftest` rules asserting prune opt-in and
      App→Project default-deny binding across the Config_Repo
    - _Requirements: 13.1, 13.5, 14.1, 14.2_

  - [x] 10.5 Write property test for opt-in pruning
    - **Property 7: Pruning is opt-in per Application and never global**
    - **Validates: Requirements 13.1, 13.5**

  - [x] 10.6 Write property test for App→Project default-deny binding
    - **Property 8: Every Application is bound to a default-deny Project**
    - **Validates: Requirements 14.1, 14.2**

  - [x] 10.7 Author ArgoCD RBAC and admin hardening as declarative config
    - Least-privilege Operator roles (deny by default, denials recorded); disable the built-in `admin`
      account once an alternative auth method authenticates an admin; reject subsequent `admin` logins
    - _Requirements: 14.4, 14.5, 14.6, 14.7_

- [x] 11. Checkpoint — GitOps control plane reconciles and passes invariants
  - All offline tests pass (Python property tests, Terraform validate/fmt, YAML parsing)
  - Integration runtime (ArgoCD reconciliation) requires an ephemeral cluster

- [x] 12. Deliver platform add-ons via GitOps in sync-wave order
  - [x] 12.1 Author the Karpenter add-on and NodePool
    - Pinned Helm chart at an early sync wave; `NodePool` provisioning ≤300s, consolidation policy, and
      `limits` mapped from the env node cap; consumes the Karpenter IRSA role from the `iam` module
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 12.2 Author the AWS Load Balancer Controller add-on
    - Provision ALB from `Ingress`; HTTPS 443 via ACM cert; HTTP 80 → 301 HTTPS; reject uncovered hostnames
    - _Requirements: 6.3, 6.4, 6.5, 6.7_

  - [x] 12.3 Author the External Secrets Operator add-on and reference-only secrets
    - ESO ready ≤300s; `SecretStore` → AWS Secrets Manager; `ExternalSecret` references only (no plaintext);
      materialize ≤60s; store-unreachable preserves prior values; store timeout marks sync failed
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5_

  - [x] 12.4 Author Gatekeeper add-on with baseline ConstraintTemplates and Constraints (Rego)
    - Deny privileged containers, host namespaces (hostPID/hostIPC/hostNetwork), and missing required labels;
      admit compliant workloads; fail-closed on evaluation failure; policies reconcile ≤180s
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6_

  - [x] 12.5 Write property test for Gatekeeper baseline admission (Rego)
    - **Property 6: Gatekeeper baseline admission decision** (via OPA `test`/`gator`)
    - **Validates: Requirements 21.2, 21.3, 21.4**

  - [x] 12.6 Author the Falco add-on and alert forwarding
    - DaemonSet ready ≤600s; alerts identify rule/workload/severity ≤30s and forward to the Observability_Stack
      ≤30s; forward failure retries ×3, retains the alert, reports after exhaustion
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5_

  - [x] 12.7 Author the Argo Rollouts controller add-on
    - Pinned chart delivered via GitOps (rollout specs authored with the Demo_Service in Task 15)
    - _Requirements: 18.1_

  - [x] 12.8 Write integration tests for add-on runtime behavior
    - ESO materialize ≤60s then preserve on broken store (R23.2, R23.5); Gatekeeper webhook fail-closed
      (R21.6); Falco trigger + forward ≤30s (R22.2, R22.3)
    - Script authored: `driftguard-infra/scripts/integration-addons.ps1` with `-RunMutationChecks`
    - **Blocked check**: Execution requires an ephemeral cluster with add-ons deployed (kubectl context)
    - _Requirements: 23.2, 23.5, 21.6, 22.2, 22.3_

- [x] 13. Implement the no-plaintext-secrets scanner
  - [x] 13.1 Implement the scanner for pre-commit and CI
    - Reject content under the Config_Repo (especially `secrets/`) containing plaintext secret values (AWS
      keys, PEM blocks, high-entropy tokens); accept references/ciphertext
    - _Requirements: 23.3, 24.4_

  - [x] 13.2 Write property test for the no-plaintext-secrets scanner
    - **Property 9: No plaintext secrets are committed to Git**
    - **Validates: Requirements 23.3, 24.4**

- [x] 14. Deliver the observability stack via GitOps
  - [x] 14.1 Author the LGTM stack add-ons
    - Prometheus/Mimir, Loki, Tempo, Grafana; deployment successful only when all components Healthy/Ready
      ≤600s; retention metrics ≥15d / logs ≥7d / traces ≥3d; discard expired telemetry
    - _Requirements: 19.1, 19.4, 19.7_

  - [x] 14.2 Author the OpenTelemetry Collector pipeline
    - Route metrics/logs/traces to the LGTM backends; traces queryable in Grafana ≤30s; continue unaffected
      signals and report a failed signal; stop when all three fail until one recovers
    - _Requirements: 19.2, 19.3, 19.6, 19.8_

  - [x] 14.3 Author dashboards-as-code
    - Grafana dashboards via ConfigMap/sidecar populating ≤10s; optional DORA metrics panel
    - _Requirements: 19.5, 20.5_

  - [x] 14.4 Author SLO recording rules and multi-window burn-rate alerts
    - ≥1 SLO for the Demo_Service (explicit SLI, target %, default 28d window); attainment + error budget
      panels using telemetry ≤60s old; long+short window burn-rate PrometheusRule delivered to a channel;
      insufficient telemetry shows `unknown` and is not reported compliant
    - _Requirements: 20.1, 20.2, 20.3, 20.4_

  - [x] 14.5 Write rules tests for SLO recording and burn-rate alerts
    - `promtool test rules` over the recording rules and multi-window burn-rate alert with time-series fixtures
    - _Requirements: 20.3_

- [x] 15. Implement the Demo_Service and its GitOps delivery artifacts
  - [x] 15.1 Implement the FastAPI service with OpenTelemetry
    - Routes `/healthz` (readiness ≤2s; never falsely ready), `/metrics` (Prometheus exposition ≤2s), `/`
      (work); OTel SDK for metrics/logs/traces
    - _Requirements: 25.1, 25.2, 25.3, 25.6, 19.2_

  - [x] 15.2 Write unit tests for the service endpoints
    - `/healthz` success when ready and not-ready failure without false readiness; `/metrics` format ≤2s
    - _Requirements: 25.2, 25.3, 25.6_

  - [x] 15.3 Author the Dockerfile
    - Multi-stage, non-root, minimal base, no privileged flags; carry required labels so it passes Gatekeeper
      admission
    - _Requirements: 21.2, 21.3_

  - [x] 15.4 Author the Kustomize base and per-env overlays
    - `base/` (Rollout, Service, Ingress, ServiceAccount) + `overlays/{dev,staging,prod}` carrying the image
      tag CI commits and the IRSA annotation (ADR-003)
    - _Requirements: 16.1, 25.4_

  - [x] 15.5 Author the Rollout spec and AnalysisTemplates
    - Canary steps 20/40/60/80/100% held 300s each and blue-green support; AnalysisTemplates for error-rate
      (>5%) and p95 latency (>500ms) over a 300s window querying Prometheus; promote on pass, abort+rollback
      on breach or metrics unavailable/slow
    - _Requirements: 18.2, 18.3, 18.4, 18.5, 18.6, 18.7_

  - [x] 15.6 Write a Rollouts analysis dry-run test
    - Against seeded Prometheus data: clean metrics promote; breaching/unavailable metrics abort and roll back
    - _Requirements: 18.5, 18.6_

- [x] 16. Checkpoint — workload builds, deploys via GitOps, and analyzes correctly
  - All offline tests pass (Demo_Service unit tests, Rollouts manifest tests, CI logic tests)
  - Runtime deployment and analysis requires an ephemeral cluster with ArgoCD + Argo Rollouts

- [x] 17. Implement CI/CD with GitHub OIDC federation
  - [x] 17.1 Implement the application CI build/test/scan/publish pipeline
    - Build ≤15 min; run tests (stop before scan on failure, report failed count); image scan (HIGH/CRITICAL
      fails, no push, report vulns); push to ECR tagged with the full commit SHA; push retries ×3 with no
      partial tag; any stage failure stops the rest and reports the failing stage
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8_

  - [x] 17.2 Implement the CI-driven GitOps tag update
    - On successful push, commit the new image tag into the env overlay so ArgoCD reconciles ≤180s; failed
      commit stops and leaves the Config_Repo unchanged; enforce that CI never runs `kubectl apply`
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 25.5_

  - [x] 17.3 Write unit tests for CI stage gating
    - Fixtures: stop-before-scan on test failure, no-push on HIGH/CRITICAL, stop-and-report on any stage failure
    - _Requirements: 15.3, 15.5, 15.8_

  - [x] 17.4 Implement the Terraform plan (PR) pipeline
    - `terraform plan` for the affected env posted to the PR; run `validate`/`tflint`/`tfsec`/`conftest` +
      Infracost; plan failure fails the check and applies nothing; HIGH/CRITICAL security findings block merge
    - _Requirements: 17.1, 17.5, 24.5, 24.6, 26.7_

  - [x] 17.5 Implement the Terraform apply (merge) pipeline
    - `terraform apply` for the affected env only; apply failure halts, reports the failing resource, and
      leaves the env in its pre-apply state (other envs untouched)
    - _Requirements: 17.2, 17.6, 8.6_

  - [x] 17.6 Implement the scheduled drift-check pipeline
    - `terraform plan -detailed-exitcode` per env (default 24h); exit `2` → drift reported with env +
      differing resources; exit `0` → no-drift status; exit `1` → check failed, never report drift-free
    - _Requirements: 17.3, 17.4, 17.7, 17.8_

  - [x] 17.7 Write unit tests for drift-check exit-code mapping
    - Map `{0, 1, 2}` to the correct reported status
    - _Requirements: 17.3, 17.4, 17.7, 17.8_

  - [x] 17.8 Provision GitHub OIDC federation IAM roles for CI
    - Short-lived assume-role for ECR push and Terraform plan/apply/drift; no long-lived access keys stored
    - _Requirements: 24.4_

- [x] 18. Cost control, teardown, and reproducibility documentation
  - [x] 18.1 Implement the teardown wrapper
    - Drain in-cluster LB-backed Services (remove ALB) then `terraform destroy` per env; leave zero billable
      compute, NAT gateways, and load balancers; on partial failure report each remaining resource, mark
      teardown incomplete, and leave remainders unmodified so re-run is safe
    - _Requirements: 26.1, 26.2, 26.3_

  - [x] 18.2 Author per-env cost estimates and Infracost wiring
    - Document each env's hourly + monthly USD estimate; ensure cost-allocation tags (Environment, Project)
    - _Requirements: 26.4, 26.7_

  - [x] 18.3 Author the reproducibility runbook (documented deliverable, R27)
    - Ordered provisioning sequence from an empty account (bootstrap → networking → eks → iam → ecr → dns →
      ArgoCD) with prerequisites, command/action, and observable completion condition per step; remediation
      per step; component descriptions; exact pinned tool/chart versions
    - _Requirements: 27.1, 27.3, 27.4, 27.5_

- [x] 19. End-to-end DriftGuard smoke scenario (Layer 5)
  - [x] 19.1 Implement the scripted end-to-end acceptance run
    - Against an ephemeral `dev` env: provision in documented order → deploy Demo_Service via GitOps and
      confirm HTTPS health → induce drift (`kubectl scale`) and observe OutOfSync ≤180s + self-heal ≤120s →
      induce a bad canary and observe abort + rollback to previous stable → single-command teardown leaving
      zero billable resources
    - _Requirements: 11.2, 11.3, 18.5, 26.1, 26.2, 27.2_

- [x] 20. Final checkpoint — full test pyramid green
  - Offline layer verified: 38 Python tests pass (24 infra + 10 gitops + 4 demo-service)
  - Terraform validate + fmt clean across all 7 modules, 3 env roots, and bootstrap
  - Integration scripts authored for layers 4–5 (argocd, addons, crossplane, e2e-smoke)
  - **Blocked checks**: Layer 4/5 integration + e2e require ephemeral cluster provisioning

- [x] 21. Crossplane provisioning from Kubernetes (STRETCH — optional)
  - [x] 21.1 Author the Crossplane + AWS provider add-on behind a feature flag
    - Install via GitOps when enabled; Healthy/Ready ≤600s or report failed and reject claims; disabled by default
    - Manifests authored: `driftguard-gitops/optional/crossplane/` (controller app, resources app, provider, XRD, composition)
    - Outside Root_Application path; enablement requires copying into `bootstrap/children/` via reviewed PR
    - _Requirements: 28.1, 28.2_

  - [x] 21.2 Author a sample claim and provisioning/deprovisioning flow
    - Claim applied via GitOps provisions the AWS resource ≤900s and records ready; provision failure records
      failure and is not marked ready; deletion deprovisions ≤900s leaving no billable resource; deprovision
      failure retains deletion state and is not reported removed
    - Manifests authored: `optional/crossplane/resources/sample-bucket-claim.yaml`
    - Integration test authored: `driftguard-infra/scripts/integration-crossplane.ps1` (requires `-ConfirmDeprovision`)
    - **Blocked check**: Execution requires ephemeral cluster with Crossplane + AWS provider configured
    - _Requirements: 28.3, 28.4, 28.5, 28.6_

## Notes

- Tasks marked with `*` are optional (test/conformance sub-tasks) and can be skipped for a faster MVP; core
  implementation tasks are never optional.
- Task 21 (Crossplane) is the stretch feature and is entirely optional; it is disabled by default to control
  cost and scope.
- Every task references the requirement clauses and/or design properties it implements for traceability.
- Property tests (Properties 1–10) each run a minimum of 100 iterations and are tagged
  `Feature: gitops-platform, Property N: <property text>`; they are placed next to the code that implements
  the property so failures are caught early.
- External controllers (ArgoCD, Rollouts, Karpenter, Gatekeeper webhook, Falco, ESO) are validated via
  conformance/snapshot, integration (Layer 4), and the Layer-5 end-to-end smoke run — not PBT.
- Checkpoints (Tasks 7, 11, 16, 20) enforce incremental validation at natural boundaries.
- The three Kiro hooks described in the Overview automate the same guardrails these tasks implement, so the
  policy-as-code posture is enforced on every edit as well as in CI.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "15.1"] },
    { "id": 2, "tasks": ["1.4", "2.1", "13.1", "15.2", "15.3"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.4", "2.5", "3.1", "13.2"] },
    { "id": 4, "tasks": ["3.2", "3.3", "3.4", "4.1", "5.1", "6.1"] },
    { "id": 5, "tasks": ["4.2", "4.3", "4.4", "5.2", "6.2", "8.1"] },
    { "id": 6, "tasks": ["8.2", "8.3", "9.1"] },
    { "id": 7, "tasks": ["9.2", "10.1"] },
    { "id": 8, "tasks": ["10.2", "10.3", "10.7"] },
    { "id": 9, "tasks": ["10.4", "10.5", "10.6"] },
    { "id": 10, "tasks": ["12.1", "12.2", "12.3", "12.4", "12.6", "12.7"] },
    { "id": 11, "tasks": ["12.5", "12.8", "14.1"] },
    { "id": 12, "tasks": ["14.2", "14.3", "14.4"] },
    { "id": 13, "tasks": ["14.5", "15.4", "15.5"] },
    { "id": 14, "tasks": ["15.6", "17.1", "17.8"] },
    { "id": 15, "tasks": ["17.2", "17.4", "17.5", "17.6"] },
    { "id": 16, "tasks": ["17.3", "17.7", "18.1", "18.2", "18.3"] },
    { "id": 17, "tasks": ["19.1"] },
    { "id": 18, "tasks": ["21.1"] },
    { "id": 19, "tasks": ["21.2"] }
  ]
}
```
