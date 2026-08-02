from policies.python.ci_logic import drift_status, stage_plan


def test_ci_stops_before_scan_when_tests_fail():
    assert stage_plan(test_passed=False, high_or_critical_findings=0, push_succeeded=False) == ["build", "test"]


def test_ci_stops_before_publish_on_high_or_critical_findings():
    assert stage_plan(test_passed=True, high_or_critical_findings=1, push_succeeded=False) == ["build", "test", "scan"]


def test_ci_updates_gitops_only_after_successful_push():
    assert stage_plan(test_passed=True, high_or_critical_findings=0, push_succeeded=False) == ["build", "test", "scan", "publish"]
    assert stage_plan(test_passed=True, high_or_critical_findings=0, push_succeeded=True) == ["build", "test", "scan", "publish", "gitops-update"]


def test_drift_exit_codes_are_fail_closed():
    assert drift_status(0) == "no-drift"
    assert drift_status(2) == "drift-detected"
    assert drift_status(1) == "check-failed"
    assert drift_status(99) == "check-failed"
