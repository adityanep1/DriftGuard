from pathlib import Path

import yaml


ROOT = Path(__file__).parents[1]


def load_documents(path):
    return [doc for doc in yaml.safe_load_all(path.read_text(encoding="utf-8")) if doc]


def test_rollout_has_required_canary_steps_and_analysis():
    rollout = yaml.safe_load((ROOT / "workloads/demo-service/base/rollout.yaml").read_text(encoding="utf-8"))
    steps = rollout["spec"]["strategy"]["canary"]["steps"]
    weights = [step["setWeight"] for step in steps if "setWeight" in step]
    pauses = [step["pause"]["duration"] for step in steps if "pause" in step]
    assert weights == [20, 40, 60, 80, 100]
    assert pauses == ["300s"] * 5
    analyses = [step["analysis"] for step in steps if "analysis" in step]
    assert len(analyses) == 5
    assert all(analysis["templates"] for analysis in analyses)


def test_analysis_templates_fail_on_breach_or_unavailable_metrics():
    docs = load_documents(ROOT / "rollouts/analysis-templates.yaml")
    assert {doc["metadata"]["name"] for doc in docs} == {"demo-service-error-rate", "demo-service-p95-latency"}
    for doc in docs:
        metric = doc["spec"]["metrics"][0]
        assert metric["timeout"] == "60s"
        assert metric["failureLimit"] == 1
        assert metric["provider"]["prometheus"]["address"].startswith("http://")
