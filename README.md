# DriftGuard

DriftGuard is a GitOps Infrastructure Automation Platform for AWS EKS. It demonstrates a strict two-layer control model:

- **Layer A — Terraform:** creates isolated AWS infrastructure, IAM/IRSA, ECR, DNS/ACM, remote state, and the initial ArgoCD installation.
- **Layer B — ArgoCD:** reconciles add-ons, policies, observability, secrets references, workloads, and progressive delivery from the Config_Repo.

## Repository map

| Path | Responsibility | Primary control plane |
|---|---|---|
| `driftguard-infra/` | Terraform modules, live environments, policies, CI, teardown | Terraform/AWS |
| `driftguard-gitops/` | ArgoCD Applications, Helm sources, policies, observability, workloads | ArgoCD/Kubernetes |
| `demo-service/` | FastAPI workload source, tests, image build, CI | GitHub Actions/ECR |
| `.kiro/specs/gitops-platform/` | Requirements, design, implementation tasks | Specification |
| `.kiro/steering/` | Persistent engineering and documentation rules | Kiro |

## Start here

1. Read `.kiro/specs/gitops-platform/requirements.md`, `design.md`, and `tasks.md`.
2. Read the applicable steering file before editing Terraform, Kubernetes YAML, policy code, or documentation.
3. Read `driftguard-infra/README.md` for provisioning order and safety gates.
4. Read `driftguard-gitops/README.md` for the ArgoCD ownership boundary.
5. Read `demo-service/README.md` for local application development.

## Safe local checks

From `driftguard-infra/`:

```powershell
terraform fmt -check -recursive
python -m pytest policies/python -q
```

From `driftguard-gitops/`:

```powershell
python scripts/scan_no_plaintext_secrets.py .
python -m pytest tests -q
```

From `demo-service/`:

```powershell
python -m pytest tests -q
```

These checks do not provision AWS or mutate a cluster. Full validation additionally requires pinned external tools and cached Terraform providers; runtime claims require a dedicated test cluster.

## Safety rules

Never commit credentials, plaintext secret values, provider lock-file changes without review, or deployment placeholders. CI changes Git and publishes artifacts; it does not run `kubectl apply`. Do not run Terraform apply/destroy or cluster integration scripts without an explicitly identified safe target.

## Documentation map

- Infrastructure operations: `driftguard-infra/README.md`
- Terraform module contracts: `driftguard-infra/modules/README.md`
- Environment isolation: `driftguard-infra/live/README.md`
- Validation and teardown scripts: `driftguard-infra/scripts/README.md`
- GitOps bootstrap: `driftguard-gitops/bootstrap/README.md`
- Policies and conformance: `driftguard-gitops/policies/README.md` and `conformance/README.md`
- Observability: `driftguard-gitops/observability/README.md`
- Demo workload delivery: `driftguard-gitops/workloads/demo-service/README.md`
