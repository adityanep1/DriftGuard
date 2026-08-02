"""Property tests for authored conformance logic.

Hypothesis is used when already installed; the deterministic fallback keeps this
repository testable without introducing an unpinned dependency.
"""

import itertools

import pytest

from policies.python.conformance import has_complete_required_tags, security_group_rule_is_safe

try:
    from hypothesis import given, settings, strategies as st
except ImportError:  # pragma: no cover - exercised on minimal toolchains
    given = None


pytestmark = pytest.mark.filterwarnings("ignore::DeprecationWarning")


if given:
    @settings(max_examples=100, deadline=None)
    @given(st.dictionaries(st.sampled_from(["Environment", "Project", "ManagedBy", "extra"]), st.text(max_size=8), max_size=4))
    def test_property_1_universal_tag_completeness(tags):
        """Feature: gitops-platform, Property 1: Universal tag completeness"""
        assert has_complete_required_tags(tags) == all(
            isinstance(tags.get(key), str) and bool(tags[key].strip())
            for key in ("Environment", "Project", "ManagedBy")
        )

    @settings(max_examples=100, deadline=None)
    @given(
        st.integers(min_value=-1, max_value=4000),
        st.integers(min_value=-1, max_value=4000),
        st.lists(st.sampled_from(["0.0.0.0/0", "::/0", "10.0.0.0/8"]), max_size=2, unique=True),
    )
    def test_property_5_admin_ports_are_not_world_open(from_port, to_port, sources):
        """Feature: gitops-platform, Property 5: Security-group ingress never opens administrative ports to the world"""
        low, high = sorted((from_port, to_port))
        expected = not (set(sources) & {"0.0.0.0/0", "::/0"}) or not any(low <= port <= high for port in (22, 3389))
        assert security_group_rule_is_safe({"from_port": low, "to_port": high, "cidr_blocks": sources}) is expected
else:
    def test_property_1_universal_tag_completeness():
        """Feature: gitops-platform, Property 1: Universal tag completeness"""
        values = ("", "dev", "driftguard", "terraform")
        cases = itertools.islice(itertools.product(values, repeat=3), 150)
        for environment, project, managed_by in cases:
            tags = {"Environment": environment, "Project": project, "ManagedBy": managed_by}
            assert has_complete_required_tags(tags) is all((environment, project, managed_by))

    def test_property_5_admin_ports_are_not_world_open():
        """Feature: gitops-platform, Property 5: Security-group ingress never opens administrative ports to the world"""
        cases = itertools.product(range(0, 4000, 17), range(0, 4000, 19), ([], ["0.0.0.0/0"], ["::/0"], ["10.0.0.0/8"]))
        for from_port, to_port, sources in itertools.islice(cases, 250):
            low, high = sorted((from_port, to_port))
            expected = not (set(sources) & {"0.0.0.0/0", "::/0"}) or not any(low <= port <= high for port in (22, 3389))
            assert security_group_rule_is_safe({"from_port": low, "to_port": high, "cidr_blocks": sources}) is expected
