---
inclusion: fileMatch
fileMatchPattern: '**/*.md'
---

# DriftGuard documentation standards

## Audience and purpose
Write for platform engineers who must safely provision, operate, validate, troubleshoot, and tear down the platform. Documentation is an operational control, not marketing copy. Prefer precise commands, explicit prerequisites, observable completion criteria, and failure remediation.

## Required README sections
For a repository, module, environment, script family, or operational subsystem, cover: purpose; ownership boundary; directory map; prerequisites; inputs and outputs; normal workflow; validation commands; failure modes; recovery/rollback; security and cost notes; references to adjacent documentation.

## Command quality
- Use PowerShell examples for the Windows workstation and POSIX examples only where the repository provides a shell script.
- State the working directory for every non-trivial command.
- Use placeholders for account IDs, repository URLs, domains, ARNs, and secrets.
- Label commands as read-only, mutating, destructive, or cluster-dependent.
- Never present `terraform apply`, `terraform destroy`, `kubectl delete`, or Crossplane deletion as harmless copy-paste actions.

## Accuracy and maintenance
- Treat pinned versions and paths as testable facts. Update documentation in the same change as code.
- Explain what is intentionally not automated, especially bootstrap, teardown, optional Crossplane, and unavailable validation tools.
- Link to the authoritative spec instead of copying requirements that will drift.
- Remove stale placeholders from deployment instructions before calling a runbook production-ready.
- Include expected output or status for important commands and state what failure means.

## Style
Use active voice, concrete nouns, canonical project terms, short paragraphs, tables for inventories, and fenced code blocks with language identifiers. Define acronyms on first use. Avoid vague phrases such as “set up the environment” or “ensure it works”; name the command, resource, timeout, and success condition.

## Review checklist
Before finishing documentation, verify paths, commands, version pins, safety warnings, links, environment names, ownership boundaries, secret handling, cost implications, and the distinction between authored configuration and executed runtime evidence.
