---
inclusion: always
---

# DriftGuard engineering contract

## Mission
DriftGuard is a GitOps infrastructure platform on AWS EKS. Its defining behavior is controlled convergence: Terraform creates the AWS substrate and performs the one-time ArgoCD handoff; ArgoCD owns the Kubernetes day-2 state and continuously reconciles it from Git.

## Non-negotiable control boundary
- Terraform owns VPC, subnets, NAT, EKS, IAM/IRSA, ECR, DNS/ACM, remote state, and the initial ArgoCD installation.
- ArgoCD owns platform add-ons, policies, observability, secrets references, workloads, and progressive delivery.
- CI changes Git and publishes artifacts. CI must not use cluster credentials or run `kubectl apply` for normal delivery.
- Direct cluster mutations are permitted only inside explicitly named, destructive-safe integration or teardown scripts.

## Change discipline
1. Read the applicable specification in `.kiro/specs/gitops-platform/` before editing implementation.
2. Inspect neighboring code, README guidance, tests, and pinned versions before inventing a pattern.
3. Make the smallest coherent change; do not opportunistically reformat unrelated files.
4. Prefer pinned versions, explicit dependencies, least privilege, immutable artifacts, and reversible operations.
5. Never commit credentials, access keys, private keys, copied tokens, real account secrets, or plaintext secret values.
6. Treat placeholders such as `your-org`, `example.invalid`, and example account IDs as deployment blockers, not production defaults.

## Definition of done
A change is complete only when implementation, documentation, validation, and failure behavior agree. Run the narrowest relevant tests first, then the repository validation suite. If a required tool, provider, cluster, or AWS account is unavailable, report the exact blocked check and leave its task unchecked; never convert an authored-but-unverified integration into a claimed runtime result.

## Safety gates
- No `terraform apply`, `terraform destroy`, cloud provisioning, or cluster mutation against production without explicit confirmation and an identified target.
- Teardown must remove ingress/load-balancer dependencies first and stop on failure.
- Crossplane and other billable-resource features remain disabled until deliberately enabled in a reviewed change.
- Changes to IAM trust, security policies, admission failure behavior, pruning, deletion policies, or state backends require an explicit impact review.

## Documentation contract
Every new operational boundary needs a README or an update to the nearest README. Document purpose, ownership, inputs, outputs, prerequisites, commands, expected success, failure modes, rollback/cleanup, and validation. Keep terminology consistent: Config_Repo, Root_Application, Environment, IRSA, Self_Heal, and opt-in pruning are canonical terms.
