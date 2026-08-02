"""Pure decision logic mirrored by CI workflow stage gates."""


def stage_plan(test_passed: bool, high_or_critical_findings: int, push_succeeded: bool) -> list[str]:
    """Return the stages that are allowed to run in order."""
    stages = ["build", "test"]
    if not test_passed:
        return stages
    stages.append("scan")
    if high_or_critical_findings:
        return stages
    stages.append("publish")
    if push_succeeded:
        stages.append("gitops-update")
    return stages


def drift_status(exit_code: int) -> str:
    """Map Terraform detailed exit codes without treating errors as drift-free."""
    return {0: "no-drift", 2: "drift-detected"}.get(exit_code, "check-failed")
