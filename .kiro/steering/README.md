# DriftGuard Kiro steering

These files are workspace guidance, not runtime configuration. They shape how Kiro investigates, edits, validates, documents, and reports work in DriftGuard.

## Files

- `00-driftguard-engineering.md`: always-included architecture boundary, safety contract, definition of done, and documentation obligations.
- `10-terraform-aws.md`: Terraform module boundaries, provider/state rules, AWS security invariants, and IaC review.
- `20-gitops-kubernetes.md`: ArgoCD ownership, Application safety, Kubernetes resource quality, progressive delivery, and observability.
- `30-security-validation.md`: fail-closed security gates, IAM/IRSA review, secret scanning, CI security, and evidence standards.
- `40-documentation.md`: README structure, command safety labels, accuracy, maintenance, and writing style.

## Inclusion

The engineering contract is always included. Domain-specific files use Kiro file-match inclusion so Terraform, GitOps, security, and Markdown work receives the most relevant additional rules. Keep these rules concise enough to be usable but strict enough to prevent false completion claims.

## Maintenance

Update steering rules when the architecture boundary, validation toolchain, secret model, deployment contract, or documentation standard changes. Do not place credentials, environment secrets, ephemeral cluster state, or personal machine paths in steering files. Validate steering Markdown after edits and keep examples aligned with the repository's actual commands.
