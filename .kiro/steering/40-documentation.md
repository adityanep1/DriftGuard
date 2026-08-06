---
inclusion: fileMatch
fileMatchPattern: '**/*.md'
---

# DriftGuard Documentation Standards

This guide establishes the structure, quality, accuracy, and tone expected from every piece of documentation in DriftGuard. It activates whenever you create or modify a Markdown file anywhere in the repository.

## Audience

Write for platform engineers who must safely provision, operate, validate, troubleshoot, and tear down the platform. Documentation is an operational control, not marketing copy. Every README should give a reader enough context to understand what they are looking at, why it exists, what it depends on, and how to validate it.

## Writing Style

Use active voice, concrete nouns, short paragraphs, and a warm but precise professional tone. Write like a knowledgeable colleague explaining how things work, not like a reference manual listing facts without context.

Specific conventions:
- Define acronyms on first use (IRSA, OIDC, LGTM, etc.)
- Use canonical project terms consistently: Config_Repo, Root_Application, Environment, IRSA, Self_Heal
- Use fenced code blocks with language identifiers for all commands and configuration samples
- Use tables for inventories, version lists, and directory maps
- Avoid vague phrases such as "set up the environment" or "ensure it works"; name the command, resource, timeout, and success condition

**The no-em-dash rule:** Never use the em dash character (the long dash). Use commas, colons, semicolons, parentheses, or rephrase the sentence instead. This applies to all Markdown files in the repository without exception.

## Required README Sections

For a module, environment, script family, or operational subsystem, cover these areas (adjust headings to fit naturally):

1. **Purpose:** What this component does and why it exists
2. **Ownership boundary:** What it owns and what it explicitly does not own
3. **Directory map:** What the subdirectories and key files contain
4. **Prerequisites:** What must exist before this component works
5. **Inputs and outputs:** Variables, configuration, produced artifacts
6. **Normal workflow:** How to use it in day-to-day operations
7. **Validation commands:** How to verify correctness (with working directory stated)
8. **Failure modes:** What can go wrong and how to detect it
9. **Recovery/rollback:** How to get back to a known-good state
10. **Security and cost notes:** Any IAM, credential, or billing implications
11. **References:** Links to adjacent documentation, specs, and related steering files

## Linking Conventions

All internal links use relative paths from the file's location. This keeps links valid regardless of where the repository is cloned or how it is rendered.

From `.kiro/steering/` files, the path to the project root is `../../`. From sub-project directories, use `../` to reach sibling directories. Examples:

```markdown
<!-- From .kiro/steering/10-terraform-aws.md -->
[networking module](../../driftguard-infra/modules/networking/README.md)
[versions.yaml](../../driftguard-gitops/versions.yaml)

<!-- From driftguard-infra/modules/eks/README.md -->
[networking module](../networking/README.md)
[live environments](../../live/README.md)
```

Never use absolute filesystem paths or GitHub URLs for internal links. External links (to AWS docs, Terraform registry, etc.) use full HTTPS URLs.

## Version Accuracy

The single source of truth for all pinned versions is [versions.yaml](../../driftguard-gitops/versions.yaml). When a README mentions a specific version (Terraform 1.9.8, ArgoCD chart 7.7.16, conftest 0.56.0), it must match what versions.yaml declares. Update documentation in the same commit as version changes.

Treat pinned versions and file paths as testable facts. If a README says "run `python3 -m pytest policies/python/ -q`", that command must actually work from the stated directory.

## Command Quality

Commands in documentation must be safe, reproducible, and unambiguous:

- State the working directory for every non-trivial command
- Use placeholders for account IDs, repository URLs, domains, ARNs, and secrets (e.g., `<AWS_ACCOUNT_ID>`, `<CLUSTER_NAME>`)
- Label commands as read-only, mutating, destructive, or cluster-dependent
- Never present `terraform apply`, `terraform destroy`, `kubectl delete`, or Crossplane deletion as harmless copy-paste actions
- Include expected output or status for important commands
- State what failure means and what to do about it

## Repository README Map

DriftGuard contains documentation across all sub-projects. Here is the complete inventory of READMEs:

**Root and configuration:**
- [README.md](../../README.md) (project root)
- [.kiro/specs/gitops-platform/README.md](../specs/gitops-platform/README.md)
- [.kiro/steering/README.md](README.md) (this directory's index)

**Infrastructure (driftguard-infra):**
- [driftguard-infra/README.md](../../driftguard-infra/README.md)
- [driftguard-infra/bootstrap/README.md](../../driftguard-infra/bootstrap/README.md)
- [driftguard-infra/live/README.md](../../driftguard-infra/live/README.md)
- [driftguard-infra/modules/README.md](../../driftguard-infra/modules/README.md)
- [driftguard-infra/modules/networking/README.md](../../driftguard-infra/modules/networking/README.md)
- [driftguard-infra/modules/eks/README.md](../../driftguard-infra/modules/eks/README.md)
- [driftguard-infra/modules/iam/README.md](../../driftguard-infra/modules/iam/README.md)
- [driftguard-infra/modules/ecr/README.md](../../driftguard-infra/modules/ecr/README.md)
- [driftguard-infra/modules/dns/README.md](../../driftguard-infra/modules/dns/README.md)
- [driftguard-infra/modules/addons-bootstrap/README.md](../../driftguard-infra/modules/addons-bootstrap/README.md)
- [driftguard-infra/modules/github-oidc/README.md](../../driftguard-infra/modules/github-oidc/README.md)
- [driftguard-infra/policies/README.md](../../driftguard-infra/policies/README.md)
- [driftguard-infra/policies/python/README.md](../../driftguard-infra/policies/python/README.md)
- [driftguard-infra/scripts/README.md](../../driftguard-infra/scripts/README.md)

**GitOps (driftguard-gitops):**
- [driftguard-gitops/README.md](../../driftguard-gitops/README.md)
- [driftguard-gitops/addons/README.md](../../driftguard-gitops/addons/README.md)
- [driftguard-gitops/applicationsets/README.md](../../driftguard-gitops/applicationsets/README.md)
- [driftguard-gitops/bootstrap/README.md](../../driftguard-gitops/bootstrap/README.md)
- [driftguard-gitops/conformance/README.md](../../driftguard-gitops/conformance/README.md)
- [driftguard-gitops/observability/README.md](../../driftguard-gitops/observability/README.md)
- [driftguard-gitops/observability/slo/README.md](../../driftguard-gitops/observability/slo/README.md)
- [driftguard-gitops/optional/crossplane/README.md](../../driftguard-gitops/optional/crossplane/README.md)
- [driftguard-gitops/policies/README.md](../../driftguard-gitops/policies/README.md)
- [driftguard-gitops/projects/README.md](../../driftguard-gitops/projects/README.md)
- [driftguard-gitops/rollouts/README.md](../../driftguard-gitops/rollouts/README.md)
- [driftguard-gitops/scripts/README.md](../../driftguard-gitops/scripts/README.md)
- [driftguard-gitops/secrets/README.md](../../driftguard-gitops/secrets/README.md)
- [driftguard-gitops/tests/README.md](../../driftguard-gitops/tests/README.md)
- [driftguard-gitops/workloads/demo-service/README.md](../../driftguard-gitops/workloads/demo-service/README.md)

**Demo service:**
- [demo-service/README.md](../../demo-service/README.md)

When creating a new directory with operational significance, add a README following the section structure described above.

## Accuracy and Maintenance

- Treat pinned versions and paths as testable facts; update documentation in the same change as code
- Explain what is intentionally not automated (bootstrap, teardown, optional Crossplane, unavailable validation tools)
- Link to the authoritative spec in [specs/](../specs/gitops-platform/README.md) instead of copying requirements that will drift
- Remove stale placeholders from deployment instructions before calling a runbook production-ready
- Include expected output or status for important commands and state what failure means

## Review Checklist

Before finishing documentation, verify:

- [ ] All file paths in links resolve to actual files in the repository
- [ ] Commands work from the stated working directory
- [ ] Version pins match [versions.yaml](../../driftguard-gitops/versions.yaml)
- [ ] Safety warnings are present for destructive operations
- [ ] Environment names match the actual directory structure (dev, staging, prod)
- [ ] No em dashes anywhere in the text
- [ ] No credentials, real account IDs, or private values
- [ ] Ownership boundaries are stated clearly
- [ ] Adjacent documentation is cross-referenced where relevant

## Related Steering Files

- [00-driftguard-engineering.md](00-driftguard-engineering.md): The documentation contract and definition of done
- [README.md](README.md): Index of all steering files and maintenance guidance
