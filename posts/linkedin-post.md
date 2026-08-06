# LinkedIn Post

## Hook options (pick one)

1. "I deployed a GitOps platform to real AWS, broke it with kubectl, and watched it fix itself in 2 minutes. Then I tore everything down with one command."
2. "7 bugs. That's how many things crashed when I actually deployed my infrastructure project to AWS. Every single test had passed."
3. "I built an EKS platform that detects when someone changes something they shouldn't and reverts it automatically. No human needed."

---

## Final post (ready to paste)

7 bugs.

That's how many things broke when I actually deployed my infrastructure project to AWS. Every offline test passed. All 38. Green across the board.

Then I ran terraform plan against a real account.

The project is DriftGuard: a GitOps platform on EKS that continuously compares live cluster state to what's declared in Git. If someone (or something) mutates a resource out of band, it detects the drift and self-heals within minutes.

Here's the architecture in five views:

[IMAGE 1: 01-two-layer-control.png]
Terraform provisions the AWS substrate (VPC, EKS, IAM, ECR), installs ArgoCD, then steps back. ArgoCD owns everything inside the cluster from that point forward.

[IMAGE 2: 02-aws-infrastructure.png]
Each environment gets isolated networking: private subnets for nodes, public subnets for the load balancer, NAT for outbound, KMS for secrets encryption.

[IMAGE 3: 03-gitops-control-plane.png]
A single Root Application fans out through AppProjects and ApplicationSets to every add-on and workload. Adding a service is a Git commit.

[IMAGE 4: 04-cicd-delivery.png]
CI builds, scans, and pushes the image. Then it commits a tag to the config repo. ArgoCD reconciles. CI never touches the cluster directly.

[IMAGE 5: 05-runtime-delivery.png]
Canary rollouts with Prometheus-backed analysis. If error rate or latency breaches the threshold, the rollout aborts and restores the previous version automatically.

The self-heal proof: I scaled a rollout from 2 to 5 replicas with kubectl. ArgoCD flagged OutOfSync immediately, then reverted it back to 2 within two minutes. No human intervention.

The 7 bugs that offline tests missed? Things like Terraform's for_each needing strings not numbers, Kustomize rejecting cross-directory references, and Argo Rollouts refusing an AnalysisTemplate with no bounded count. None of these surface until you run the real tool against real infrastructure.

Biggest lesson: a test suite that never actually runs terraform plan or kustomize build is lying to you about readiness.

Repo is open source (link in comments).

What's the worst "all tests pass but it doesn't deploy" moment you've hit?

---

## First comment (paste immediately after publishing)

Here's the repo if you want to dig in: https://github.com/suletetes/DriftGuard

Includes Terraform modules, ArgoCD app-of-apps, Argo Rollouts canary with metric analysis, full LGTM observability stack, OPA/Gatekeeper policies, and a single-command teardown. Architecture diagrams are generated as code.

---

## Hashtags (add at very bottom of post)

#AWS #DevOps #GitOps #Kubernetes #EKS #Terraform #CloudEngineering #BuildInPublic

---

## Image upload order

Upload these 5 images as a document/carousel or inline images:
1. `docs/architecture/diagrams/01-two-layer-control.png`
2. `docs/architecture/diagrams/02-aws-infrastructure.png`
3. `docs/architecture/diagrams/03-gitops-control-plane.png`
4. `docs/architecture/diagrams/04-cicd-delivery.png`
5. `docs/architecture/diagrams/05-runtime-delivery.png`

---

## Engagement plan

- Post Tuesday or Wednesday around 9am ET (peak DevOps/cloud audience)
- Stay active for 90 minutes after posting: reply to every comment with a follow-up question
- Ask 2 engineering contacts to leave a real comment in the first 30 minutes
- The question at the end ("worst all-tests-pass-but-fails-deploy moment") is designed to trigger war stories in the comments, which drives dwell time
