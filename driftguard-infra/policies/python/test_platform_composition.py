"""Offline static checks for the infrastructure and GitOps composition gates."""

from pathlib import Path


ROOT = Path(__file__).parents[2]


def test_dns_module_has_validation_timeout_and_optional_alb_records():
    main = (ROOT / "modules" / "dns" / "main.tf").read_text(encoding="utf-8")
    assert 'resource "aws_route53_zone"' in main
    assert 'resource "aws_acm_certificate"' in main
    assert 'resource "aws_acm_certificate_validation"' in main
    assert 'create = "10m"' in main
    assert 'resource "aws_route53_record" "alb"' in main


def test_argocd_bootstrap_waits_before_seeding_root_application():
    main = (ROOT / "modules" / "addons-bootstrap" / "main.tf").read_text(encoding="utf-8")
    assert "atomic           = true" in main
    assert "wait             = true" in main
    assert "timeout          = var.installation_timeout_seconds" in main
    assert "depends_on = [helm_release.argocd]" in main
    assert "prune    = false" in main


def test_each_environment_composes_eks_iam_and_ecr_with_distinct_backend():
    for environment in ("dev", "staging", "prod"):
        root = ROOT / "live" / environment
        main = (root / "main.tf").read_text(encoding="utf-8")
        backend = (root / "backend.tf").read_text(encoding="utf-8")
        for module in ('module "networking"', 'module "eks"', 'module "iam"', 'module "ecr"'):
            assert module in main
        assert f"env/{environment}/terraform.tfstate" in backend
        assert "max_node_count" in main
