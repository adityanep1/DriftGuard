# DriftGuard GitOps Platform specification

This directory is the authoritative planning package for the DriftGuard GitOps Infrastructure Automation Platform.

## Specification artifacts

- `requirements.md` — user stories and acceptance criteria, including negative/security constraints.
- `design.md` — architecture, ownership boundaries, component interfaces, workflows, decisions, and test strategy.
- `tasks.md` — implementation sequence, property-test obligations, checkpoints, and task status.
- `.config.kiro` — Kiro specification metadata.

## Reading order

Read `requirements.md` first to understand the behavior being promised. Read `design.md` second to understand why Terraform, ArgoCD, CI, policies, observability, and workload repositories are separated. Use `tasks.md` to identify the smallest implementable change and its required evidence.

## Status rules

A task may be marked complete only when its stated implementation and validation have actually run. Authored manifests do not prove controller health; a script does not prove runtime behavior; a source-shape test does not replace Terraform plan conformance; and a passing local test does not prove AWS or cluster integration.

Leave tasks unchecked when they require unavailable providers, tools, AWS resources, or a Kubernetes cluster. Record the exact blocker and the next safe validation command in the relevant README or completion report.

## Property-test rule

Every property test must run at least 100 cases and include the exact feature/property label required by `tasks.md`:

```text
Feature: gitops-platform, Property N: <property text>
```

## Change workflow

1. Link the change to one or more requirements and tasks.
2. Preserve the Terraform-to-ArgoCD ownership boundary.
3. Add or update tests and the nearest operational README.
4. Run focused validation, then the applicable repository suite.
5. Report modified paths, commands, results, warnings, and blocked runtime checks.
