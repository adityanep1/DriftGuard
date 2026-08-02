"""Property tests for the environment-wide worker-node cap."""

import itertools

import pytest

from policies.python.conformance import (
    clamp_node_count,
    scaling_request_is_allowed,
    validate_max_node_count,
)

try:
    from hypothesis import given, settings, strategies as st
except ImportError:  # pragma: no cover
    given = None


if given:
    @settings(max_examples=100, deadline=None)
    @given(
        st.integers(min_value=1, max_value=1000),
        st.integers(min_value=0, max_value=2000),
    )
    def test_property_10_node_count_cap_validation(max_node_count, requested_node_count):
        """Feature: gitops-platform, Property 10: Node-count cap validation"""
        allowed = requested_node_count <= max_node_count
        assert scaling_request_is_allowed(requested_node_count, max_node_count) is allowed
        assert clamp_node_count(requested_node_count, max_node_count) <= max_node_count
else:
    def test_property_10_node_count_cap_validation():
        """Feature: gitops-platform, Property 10: Node-count cap validation"""
        cases = itertools.product((1, 2, 1000), range(0, 1201, 7))
        for max_node_count, requested_node_count in itertools.islice(cases, 150):
            allowed = requested_node_count <= max_node_count
            assert scaling_request_is_allowed(requested_node_count, max_node_count) is allowed
            assert clamp_node_count(requested_node_count, max_node_count) <= max_node_count


def test_node_cap_rejects_invalid_values():
    for value in (True, False, 0, 1001, 1.5, "10"):
        with pytest.raises(ValueError):
            validate_max_node_count(value)


def test_node_cap_rejects_negative_scale_requests():
    assert scaling_request_is_allowed(-1, 10) is False
    with pytest.raises(ValueError):
        clamp_node_count(-1, 10)


def test_node_cap_clamps_overflowing_results():
    assert clamp_node_count(1500, 1000) == 1000
    assert scaling_request_is_allowed(1500, 1000) is False
