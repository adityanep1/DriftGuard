"""Property and offline shape tests for EKS API and IRSA safety rules."""

import ipaddress
import itertools
from pathlib import Path

from policies.python.conformance import (
    eks_api_allowlist_is_safe,
    has_complete_required_tags,
    iam_statement_is_safe,
    irsa_trust_is_scoped,
)

try:
    from hypothesis import given, settings, strategies as st
except ImportError:  # pragma: no cover - exercised on minimal toolchains
    given = None


if given:
    @settings(max_examples=100, deadline=None)
    @given(st.lists(st.sampled_from([
        "10.0.0.0/8", "192.0.2.0/24", "2001:db8::/32", "0.0.0.0/0", "::/0", "not-a-cidr"
    ]), max_size=4))
    def test_property_4_eks_api_allowlist_excludes_unrestricted_cidrs(cidrs):
        """Feature: gitops-platform, Property 4: EKS API allowlist excludes unrestricted CIDRs"""
        expected = bool(cidrs)
        try:
            networks = [ipaddress.ip_network(cidr, strict=False) for cidr in cidrs]
            expected = expected and all(str(network) not in {"0.0.0.0/0", "::/0"} for network in networks)
        except ValueError:
            expected = False
        assert eks_api_allowlist_is_safe(cidrs) is expected

    @settings(max_examples=100, deadline=None)
    @given(
        st.lists(st.sampled_from(["s3:GetObject", "ecr:GetAuthorizationToken", "*"]), min_size=0, max_size=3),
        st.lists(st.sampled_from(["arn:aws:s3:::example/*", "arn:aws:ecr:us-east-1:123456789012:repository/example", "*"]), min_size=0, max_size=3),
    )
    def test_property_2_iam_statements_never_use_wildcards(actions, resources):
        """Feature: gitops-platform, Property 2: IAM statements never combine wildcard action with wildcard resource"""
        statement = {"actions": actions, "resources": resources}
        expected = bool(set(actions)) and bool(set(resources)) and not ("*" in actions and "*" in resources)
        assert iam_statement_is_safe(statement) is expected

    @settings(max_examples=100, deadline=None)
    @given(
        st.lists(st.sampled_from([
            "system:serviceaccount:platform:demo",
            "system:serviceaccount:platform:other",
            "system:serviceaccount:other:demo",
            "system:serviceaccount:*:*",
            "not-a-service-account",
        ]), min_size=0, max_size=3)
    )
    def test_property_3_irsa_trust_binds_exactly_one_service_account(subjects):
        """Feature: gitops-platform, Property 3: IRSA trust policy binds exactly one namespace and service account"""
        expected = len(subjects) == 1 and subjects[0].startswith("system:serviceaccount:")
        if expected:
            parts = subjects[0].removeprefix("system:serviceaccount:").split(":")
            expected = len(parts) == 2 and all(
                part and part != "*" and not any(character.isspace() for character in part)
                for part in parts
            )
        assert irsa_trust_is_scoped({"subjects": subjects}) is expected
else:
    def test_property_4_eks_api_allowlist_excludes_unrestricted_cidrs():
        """Feature: gitops-platform, Property 4: EKS API allowlist excludes unrestricted CIDRs"""
        # Keep a deterministic fallback with more than the required 100 cases.
        cidr_cases = [[], ["10.0.0.0/8"], ["0.0.0.0/0"], ["::/0"], ["not-a-cidr"], ["2001:db8::/32"]] * 30
        for cidrs in cidr_cases[:150]:
            expected = bool(cidrs)
            try:
                networks = [ipaddress.ip_network(cidr, strict=False) for cidr in cidrs]
                expected = expected and all(str(network) not in {"0.0.0.0/0", "::/0"} for network in networks)
            except ValueError:
                expected = False
            assert eks_api_allowlist_is_safe(cidrs) is expected

    def test_property_2_iam_statements_never_use_wildcards():
        """Feature: gitops-platform, Property 2: IAM statements never combine wildcard action with wildcard resource"""
        cases = list(itertools.product(
            ([], ["s3:GetObject"], ["*"]),
            ([], ["arn:aws:s3:::example/*"], ["*"]),
        )) * 50
        for actions, resources in cases[:150]:
            expected = bool(set(actions)) and bool(set(resources)) and not ("*" in actions and "*" in resources)
            assert iam_statement_is_safe({"actions": actions, "resources": resources}) is expected

    def test_property_3_irsa_trust_binds_exactly_one_service_account():
        """Feature: gitops-platform, Property 3: IRSA trust policy binds exactly one namespace and service account"""
        cases = [
            [],
            ["system:serviceaccount:platform:demo"],
            ["system:serviceaccount:platform:demo", "system:serviceaccount:platform:other"],
            ["system:serviceaccount:*:*"] ,
            ["not-a-service-account"],
        ] * 30
        for subjects in cases[:150]:
            expected = len(subjects) == 1 and subjects[0].startswith("system:serviceaccount:")
            if expected:
                parts = subjects[0].removeprefix("system:serviceaccount:").split(":")
                expected = len(parts) == 2 and all(
                    part and part != "*" and not any(character.isspace() for character in part)
                    for part in parts
                )
            assert irsa_trust_is_scoped({"subjects": subjects}) is expected


MODULE_ROOT = Path(__file__).parents[2] / "modules"


def test_eks_module_declares_pinned_private_encrypted_cluster_shape():
    main = (MODULE_ROOT / "eks" / "main.tf").read_text(encoding="utf-8")
    assert "version  = var.kubernetes_version" in main
    assert "subnet_ids      = var.private_subnet_ids" in main
    assert 'resources = ["secrets"]' in main
    assert "public_access_cidrs" in main
    assert "var.public_access_cidrs" in main
    assert "aws_iam_openid_connect_provider" in main


def test_iam_allows_scoped_actions_with_wildcard_resource():
    """A specific action may use a wildcard resource under the approved rule."""
    assert iam_statement_is_safe({"actions": ["logs:CreateLogStream"], "resources": ["*"]}) is True
    assert iam_statement_is_safe({"actions": ["*"], "resources": ["arn:aws:s3:::driftguard/*"]}) is True
    assert iam_statement_is_safe({"actions": ["*"], "resources": ["*"]}) is False


def test_irsa_trust_rejects_wildcard_subject_components():
    assert irsa_trust_is_scoped({"subjects": ["system:serviceaccount:*:demo"]}) is False
    assert irsa_trust_is_scoped({"subjects": ["system:serviceaccount:platform:*"]}) is False


def test_iam_and_ecr_modules_declare_required_security_shape():
    iam_main = (MODULE_ROOT / "iam" / "main.tf").read_text(encoding="utf-8")
    iam_variables = (MODULE_ROOT / "iam" / "variables.tf").read_text(encoding="utf-8")
    ecr_main = (MODULE_ROOT / "ecr" / "main.tf").read_text(encoding="utf-8")
    ecr_variables = (MODULE_ROOT / "ecr" / "variables.tf").read_text(encoding="utf-8")

    assert "sts:AssumeRoleWithWebIdentity" in iam_main
    assert "exactly one namespace/service-account" in iam_variables
    assert "aws_iam_role.irsa" in iam_main
    assert "encryption_configuration" in ecr_main
    assert "scan_on_push = true" in ecr_main
    assert 'tagStatus   = "untagged"' in ecr_main
    assert "default     = 14" in ecr_variables
    assert "force_delete         = false" in ecr_main
    assert "tags = local.required_tags" in ecr_main


def test_ecr_conformance_shape_requires_encryption_and_required_tags():
    ecr_main = (MODULE_ROOT / "ecr" / "main.tf").read_text(encoding="utf-8")
    required_tags = {"Environment": "dev", "Project": "driftguard", "ManagedBy": "terraform"}

    assert has_complete_required_tags(required_tags)
    assert 'resource "aws_ecr_repository" "service"' in ecr_main
    assert "dynamic \"encryption_configuration\"" in ecr_main
    assert "tags = local.required_tags" in ecr_main
