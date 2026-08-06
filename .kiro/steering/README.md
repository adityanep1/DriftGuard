# DriftGuard Steering Files

Welcome to the steering directory. These files are workspace guidance that shapes how Kiro investigates, edits, validates, documents, and reports work across the DriftGuard monorepo. They are not runtime configuration and do not affect the deployed platform; they exist to keep development consistent, safe, and well-documented.

## How Steering Files Work

Each steering file uses YAML frontmatter to declare when it activates:

- **`inclusion: always`** means the file loads for every interaction, regardless of what files you are working on. This is reserved for the master engineering contract.
- **`inclusion: fileMatch`** with a `fileMatchPattern` means the file loads only when you are editing files that match the glob pattern. This keeps context focused and relevant.

## File Index

| File | Inclusion | Activates when you touch... | Purpose |
|---|---|---|---|
| [00-driftguard-engineering.md](00-driftguard-engineering.md) | Always | Everything | Master engineering contract: architecture boundary, safety gates, definition of done, CI workflows, and documentation obligations |
| [10-terraform-aws.md](10-terraform-aws.md) | fileMatch: `driftguard-infra/**/*.tf` | Terraform files | Module boundaries, provider/state rules, AWS security invariants, version pins, and validation workflow |
| [20-gitops-kubernetes.md](20-gitops-kubernetes.md) | fileMatch: `driftguard-gitops/**` | GitOps configuration | ArgoCD safety, Kubernetes resource quality, progressive delivery, Karpenter overlays, and kustomize conventions |
| [30-security-validation.md](30-security-validation.md) | fileMatch: policies, conformance, secrets, IAM, scripts | Security-related files | Rego policies, IAM review, secret scanning, CI security, evidence standards, and fail-closed posture |
| [40-documentation.md](40-documentation.md) | fileMatch: `**/*.md` | Any Markdown file | README structure, writing style, linking conventions, version accuracy, and the no-em-dash rule |

## Relationship to Specs

The steering files complement the specification documents in [.kiro/specs/gitops-platform/](../specs/gitops-platform/README.md). The specs define what the platform should be (requirements, design, tasks); the steering files define how to work on it (conventions, safety rules, quality gates). When the spec and steering disagree, the spec is the source of truth for requirements, and steering is the source of truth for process.

Key spec files:
- [requirements.md](../specs/gitops-platform/requirements.md): Full platform requirements
- [design.md](../specs/gitops-platform/design.md): Architecture and design decisions
- [tasks.md](../specs/gitops-platform/tasks.md): Implementation task breakdown

## When to Update Steering Files

Update these files when any of the following changes:

- **Architecture boundary shifts** (a new module, a new sub-project, or a change in what Terraform vs. ArgoCD owns)
- **Validation toolchain changes** (new tool added, version bump, new policy file)
- **Secret model changes** (new secret provider, new scanning rules)
- **Deployment contract changes** (new environment, new sync strategy, new rollout pattern)
- **Documentation standards evolve** (new section requirements, new linking patterns)
- **Version pins update** (always check that steering references match [versions.yaml](../../driftguard-gitops/versions.yaml))

## Maintenance Rules

A few ground rules for keeping steering files healthy:

1. **No credentials or secrets:** Never place AWS keys, tokens, real account IDs, or personal machine paths in steering files.
2. **Keep links valid:** All internal links use relative paths. After renaming or moving files, check that steering links still resolve.
3. **Stay in sync with reality:** If a command or path mentioned in steering no longer works, fix the steering file in the same PR that changed the underlying code.
4. **Warm, precise tone:** Write like a helpful colleague, not a legal document. Be specific enough to prevent mistakes but readable enough that someone actually reads it.
5. **No em dashes:** Use commas, colons, semicolons, or parentheses instead. This rule applies to all Markdown in the repository.

## Quick Reference: Where Things Live

For orientation, here is how the monorepo is organized:

```
DriftGuard/
  .github/workflows/       Root CI workflows for the monorepo
  .kiro/
    specs/gitops-platform/  Requirements, design, and tasks
    steering/               This directory (you are here)
  driftguard-infra/         Terraform modules, live envs, policies, scripts
  driftguard-gitops/        ArgoCD apps, addons, conformance, workloads, tests
  demo-service/             FastAPI application with Dockerfile
  README.md                 Project root README
```

Each sub-project has its own README, and most directories within them do as well. The full README inventory is documented in [40-documentation.md](40-documentation.md).
