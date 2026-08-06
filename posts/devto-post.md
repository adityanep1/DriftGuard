---
title: I built a GitOps platform on EKS that self-heals when you break it. Here's what actually went wrong.
published: false
description: DriftGuard is a full GitOps infrastructure platform on AWS EKS. I deployed it for real, broke it on purpose, and watched ArgoCD fix it. Along the way I found seven bugs that no test caught.
tags: aws, devops, kubernetes, gitops
cover_image: https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/01-two-layer-control.png
---

Last month I set out to build something I could point to and say "I understand production infrastructure." Not a tutorial cluster. Not a sandbox with three pods. A real platform with drift detection, progressive delivery, policy enforcement, and a single-command teardown so I don't accidentally pay $300/month while I sleep.

I called it DriftGuard. And then I deployed it. That's where it got interesting.

## What DriftGuard actually is

A two-layer infrastructure platform on AWS EKS:

- **Layer A** is Terraform. It provisions the VPC, subnets, NAT gateways, EKS cluster, IAM/IRSA roles, ECR repositories, DNS/ACM, and the remote state backend. It also performs one final act: installing ArgoCD via Helm. Then it steps back.

- **Layer B** is ArgoCD. Once installed, ArgoCD owns everything inside the cluster. Add-ons, policies, observability, workloads, progressive delivery. It pulls desired state from Git every 180 seconds and reconciles any drift it finds.

The boundary between these two layers is the most important decision in the whole platform. Terraform owns things that can't bootstrap themselves from inside Kubernetes. ArgoCD owns things that benefit from continuous drift correction.

![The two-layer control model showing Terraform handing off to ArgoCD](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/01-two-layer-control.png)

## The AWS infrastructure

Each environment gets its own isolated VPC with public subnets (for the load balancer and NAT gateway) and private subnets (for the worker nodes, which never touch the public internet directly). Production runs one NAT per availability zone for high availability; dev runs one to save cost.

![AWS infrastructure topology showing VPC, subnets, NAT, EKS, and supporting services](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/02-aws-infrastructure.png)

The EKS cluster pins a specific Kubernetes minor (1.30, not "latest"), encrypts secrets at rest with a dedicated KMS key, and restricts the API endpoint to an explicit CIDR allowlist. No `0.0.0.0/0` allowed. I learned the hard way that this matters when my IP rotated mid-session and I got locked out of my own cluster for twenty minutes.

## The GitOps control plane

ArgoCD uses the app-of-apps pattern. A single Root_Application discovers child Applications from Git. Those children include ApplicationSets that generate one Application per target (one per environment, one per add-on chart). Adding a new workload is a Git commit, not a kubectl command.

![GitOps control plane showing Root_Application fanning out to add-ons and workloads](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/03-gitops-control-plane.png)

Every Application binds to a default-deny AppProject that whitelists exactly which repos, namespaces, and cluster resources it can touch. Pruning is disabled globally. You have to opt in per-Application with a review marker.

## CI/CD: pull-based, no cluster credentials in CI

The delivery pipeline never runs `kubectl apply`. Instead:

1. GitHub Actions builds, tests, and scans the image.
2. On pass, it pushes to ECR using short-lived OIDC credentials (no static AWS keys).
3. It commits the new image tag to the Config Repo.
4. ArgoCD sees the tag change and deploys.

![CI/CD delivery flow showing the pull-based boundary](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/04-cicd-delivery.png)

This means CI has no cluster access. If CI is compromised, the attacker gets ECR push (scoped to one repo) and a Git commit (reviewable). They don't get `kubectl exec` on production pods.

## Progressive delivery and observability

The demo workload deploys as an Argo Rollout with canary steps (20%, 40%, 60%, 80%, 100%), each held for 300 seconds with a Prometheus analysis check. If error rate exceeds 5% or p95 latency exceeds 500ms, the rollout aborts and restores the previous stable version automatically.

The observability stack is Prometheus, Grafana, Loki, and Tempo, all delivered via GitOps with an OpenTelemetry Collector routing metrics, logs, and traces to the right backends.

![In-cluster runtime showing the canary rollout, metric analysis, and LGTM observability](https://raw.githubusercontent.com/suletetes/DriftGuard/main/docs/architecture/diagrams/05-runtime-delivery.png)

## The part where I actually deployed it

I provisioned a real dev environment on my AWS account. EKS came up, both nodes reported Ready, ArgoCD installed, the Root_Application discovered all 19 child Applications within seconds.

Then I built the demo-service container, pushed it to ECR, committed the tag to the overlay, and ArgoCD deployed a healthy Rollout with 2 pods answering requests.

And then I broke it on purpose.

```bash
kubectl patch rollout demo-service -n demo-dev --type merge -p '{"spec":{"replicas":5}}'
```

Replicas jumped to 5. ArgoCD flagged `OutOfSync` immediately. Within two minutes, it reverted the live state back to the Git-declared 2 replicas. No human intervention.

That's the core DriftGuard behavior. Someone (or something) mutates the cluster out of band, and the platform heals itself.

## Seven bugs the tests never caught

Here's the honest part. The offline test suite (38 tests, Rego policies, Hypothesis property tests) all passed. But when I ran `terraform plan` for real, five things crashed immediately:

1. **trimspace(null)** in the DNS module validation. Blocks plan even when DNS is disabled.
2. **for_each on a set of numbers.** Terraform needs strings. Nobody noticed because nobody actually planned.
3. **Kustomize cross-boundary reference.** ArgoCD couldn't render the manifests.
4. **commonLabels polluting the Rollout selector.** Argo Rollouts rejected the spec.
5. **AnalysisTemplate with no count.** "Runs indefinitely" is an error, not a feature.
6. **Karpenter hardcoded to prod cluster names.** Would silently provision nodes into the wrong security groups on dev.
7. **CI pinned Terraform 1.15.3.** That version doesn't exist.

The root cause of all seven: the CI pipeline had never actually run. It pinned a Terraform version that doesn't exist, so `setup-terraform` would fail silently. The property tests are excellent at logic verification but they parse YAML directly, never running kustomize, ArgoCD, or Argo Rollouts. The gap between "tests pass" and "it deploys" was larger than I expected.

I fixed all seven and verified the fixes by deploying again successfully.

## What I'd do differently

If I were starting over:

- **Run terraform plan in CI from day one.** Even without applying. A plan that fails is a bug.
- **Run kustomize build in CI.** Not just YAML parsing. The actual build, with the actual kustomize version ArgoCD ships.
- **Test with a real Argo Rollouts controller.** The InvalidSpec errors only surface when the CRD controller evaluates the manifest, not during offline schema checks.
- **Pin real tool versions.** Sounds obvious, but I wrote "1.15.3" in four places and never noticed it doesn't exist because I never ran it.

## Try it yourself

The repo is at [github.com/suletetes/DriftGuard](https://github.com/suletetes/DriftGuard). It's designed as a template: replace the placeholder account ID, org name, and domain, then follow the provisioning runbook. The architecture diagrams are generated as code and regenerate with `python generate_architecture.py`.

Fair warning: a running dev environment costs roughly $0.35/hour ($250/month). Run the teardown script when you're done.

---

*Built with Terraform, ArgoCD, EKS, Argo Rollouts, Karpenter, Gatekeeper, Falco, External Secrets Operator, Prometheus, Grafana, Loki, Tempo, and OpenTelemetry. Diagrams generated with the Python `diagrams` library.*
