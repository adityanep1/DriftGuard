"""Property and fixture tests for ArgoCD safety invariants."""

from pathlib import Path

import yaml

APPROVED_PROJECTS = {"platform-addons", "observability", "security", "workloads"}
BOOTSTRAP_APPS = {"root-application", "argocd-projects", "driftguard-application-sets"}

try:
    from hypothesis import given, settings, strategies as st
except ImportError:  # pragma: no cover
    given = None


def pruning_is_safe(application: dict) -> bool:
    automated = application.get("spec", {}).get("syncPolicy", {}).get("automated", {})
    if automated.get("prune") is not True:
        return True
    return application.get("metadata", {}).get("annotations", {}).get("driftguard.io/prune-approved") == "true"


def project_binding_is_safe(application: dict) -> bool:
    name = application.get("metadata", {}).get("name")
    return name in BOOTSTRAP_APPS or application.get("spec", {}).get("project") in APPROVED_PROJECTS


if given:
    @settings(max_examples=100, deadline=None)
    @given(
        st.booleans(),
        st.booleans(),
        st.sampled_from(sorted(APPROVED_PROJECTS | {"default", "untrusted"})),
    )
    def test_property_7_pruning_is_opt_in(prune, approved, project):
        """Feature: gitops-platform, Property 7: Pruning is opt-in per Application and never global"""
        app = {
            "metadata": {"name": "generated"},
            "spec": {"project": project, "syncPolicy": {"automated": {"prune": prune}}},
        }
        if prune and approved:
            app["metadata"]["annotations"] = {"driftguard.io/prune-approved": "true"}
        assert pruning_is_safe(app) is (not prune or approved)

    @settings(max_examples=100, deadline=None)
    @given(st.sampled_from(sorted(APPROVED_PROJECTS | {"default", "untrusted"})))
    def test_property_8_every_application_uses_default_deny_project(project):
        """Feature: gitops-platform, Property 8: Every Application is bound to a default-deny Project"""
        app = {"metadata": {"name": "generated"}, "spec": {"project": project}}
        assert project_binding_is_safe(app) is (project in APPROVED_PROJECTS)
else:
    def test_property_7_pruning_is_opt_in():
        """Feature: gitops-platform, Property 7: Pruning is opt-in per Application and never global"""
        for prune in (False, True):
            for approved in (False, True):
                app = {"metadata": {"name": "generated"}, "spec": {"syncPolicy": {"automated": {"prune": prune}}}}
                if approved:
                    app["metadata"]["annotations"] = {"driftguard.io/prune-approved": "true"}
                assert pruning_is_safe(app) is (not prune or approved)

    def test_property_8_every_application_uses_default_deny_project():
        """Feature: gitops-platform, Property 8: Every Application is bound to a default-deny Project"""
        for project in APPROVED_PROJECTS | {"default", "untrusted"}:
            assert project_binding_is_safe({"metadata": {"name": "generated"}, "spec": {"project": project}}) is (project in APPROVED_PROJECTS)


def test_repository_applications_obey_invariants():
    for path in Path(__file__).parents[1].rglob("*.yaml"):
        for document in yaml.safe_load_all(path.read_text(encoding="utf-8")):
            if document and document.get("kind") == "Application":
                assert pruning_is_safe(document), path
                assert project_binding_is_safe(document), path
