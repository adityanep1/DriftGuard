import importlib.util
from pathlib import Path

import pytest

MODULE_PATH = Path(__file__).parents[1] / "scripts" / "scan_no_plaintext_secrets.py"
spec = importlib.util.spec_from_file_location("secret_scanner", MODULE_PATH)
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)

try:
    from hypothesis import assume, given, settings, strategies as st
except ImportError:  # pragma: no cover
    given = None


if given:
    @settings(max_examples=100, deadline=None)
    @given(st.sampled_from(["ENC[AES256,data:abc]", "${SECRET_REF}", "remoteRef: name", "REPLACE_WITH_COMMIT_SHA"]))
    def test_property_9_secret_references_and_ciphertext_are_accepted(value):
        """Feature: gitops-platform, Property 9: No plaintext secrets are committed to Git"""
        assert scanner.scan_text(f"token: {value}") == []
else:
    def test_property_9_secret_references_and_ciphertext_are_accepted():
        """Feature: gitops-platform, Property 9: No plaintext secrets are committed to Git"""
        values = ["ENC[AES256,data:abc]", "${SECRET_REF}", "remoteRef: name", "REPLACE_WITH_COMMIT_SHA"] * 30
        for value in values[:100]:
            assert scanner.scan_text(f"token: {value}") == []


def test_scanner_rejects_aws_key_and_pem():
    text = "AKIA" + "1234567890ABCDEF" + "\n" + "-" * 5 + "BEGIN PRIVATE KEY" + "-" * 5 + "\nsecret"
    assert scanner.scan_text(text)


def test_scanner_rejects_plaintext_assignment():
    key = "password"
    assert scanner.scan_text(f"{key}: 'this-is-a-real-password-value'")


def test_tree_scan_allows_repository_references(tmp_path):
    (tmp_path / "reference.yaml").write_text("remoteRef:\n  key: app/config\n", encoding="utf-8")
    assert scanner.scan_tree(tmp_path) == []


if given:
    @settings(max_examples=100, deadline=None)
    @given(st.text(alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", min_size=20, max_size=64))
    def test_property_9_plaintext_credential_assignments_are_rejected(value):
        """Feature: gitops-platform, Property 9: No plaintext secrets are committed to Git"""
        assume("\n" not in value)
        assert scanner.scan_text(f"password: {value}")
else:
    def test_property_9_plaintext_credential_assignments_are_rejected():
        """Feature: gitops-platform, Property 9: No plaintext secrets are committed to Git"""
        for index in range(100):
            assert scanner.scan_text(f"password: token-value-{index:020d}")
