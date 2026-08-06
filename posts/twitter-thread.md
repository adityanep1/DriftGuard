# X (Twitter) Thread

## Format: 7 tweets (hook + 5 diagram tweets + closer)

Each tweet is under 280 characters. Images attach one per tweet (free tier allows 1 image per tweet in a thread).

---

## Tweet 1 (Hook, no image)

I built a GitOps platform on AWS that fixes itself when you break it.

Scaled a pod to 5 replicas with kubectl. ArgoCD caught it, marked OutOfSync, and reverted to 2 within 2 minutes. No human touched it.

Here's the full architecture in 5 diagrams:

---

## Tweet 2 (attach: 01-two-layer-control.png)

The core idea: two layers.

Terraform provisions the AWS substrate (VPC, EKS, IAM, ECR) and installs ArgoCD. Then it's done.

ArgoCD owns everything inside the cluster. It polls Git every 180s and converges any drift it finds.

---

## Tweet 3 (attach: 02-aws-infrastructure.png)

The AWS layer per environment:

- Private subnets for nodes (never public)
- NAT for outbound, ALB for inbound
- KMS encrypting secrets at rest
- S3 + DynamoDB for state locking
- CIDR-restricted API endpoint (no 0.0.0.0/0)

All provisioned by Terraform, isolated per env.

---

## Tweet 4 (attach: 03-gitops-control-plane.png)

ArgoCD's app-of-apps pattern:

One Root Application discovers all children from Git. ApplicationSets generate one app per env per workload from a shared template.

Adding a new service = one Git commit. No kubectl. No manual ArgoCD config.

---

## Tweet 5 (attach: 04-cicd-delivery.png)

CI never touches the cluster.

GitHub Actions builds, scans, pushes to ECR (OIDC, no static keys), then commits the image tag to the config repo.

ArgoCD sees the commit and deploys.

Compromised CI = ECR push + a reviewable commit. Not kubectl exec on prod.

---

## Tweet 6 (attach: 05-runtime-delivery.png)

Progressive delivery with Argo Rollouts:

Canary steps 20% -> 100%, each held 300s with Prometheus analysis.

If error rate > 5% or p95 latency > 500ms, it aborts and rolls back automatically. No pager needed.

---

## Tweet 7 (Closer, no image)

The honest part: 7 bugs crashed on real deploy that all offline tests missed.

terraform plan needs strings not numbers. Kustomize rejects cross-directory refs. Argo Rollouts needs bounded analysis counts.

Tests that never run the real tool chain lie about readiness.

Repo: github.com/suletetes/DriftGuard

---

## Engagement plan

- Post the thread Tuesday or Wednesday morning (US timezones waking up)
- The hook tweet must stand alone and create curiosity (it does: "fixes itself when you break it" + specific proof)
- After posting, reply to your own thread with: "Open source. Replace the placeholder account ID and domain, follow the runbook, and it deploys end to end."
- Quote-tweet the hook with a one-liner opinion later in the day to re-surface it
- Reply to any comments in the first hour (reply chains are 75-150x the value of a like on X)
