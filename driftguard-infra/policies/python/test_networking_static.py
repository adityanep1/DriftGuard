"""Offline static checks for the networking module's safety-critical shape."""

from pathlib import Path


MODULE = Path(__file__).parents[2] / "modules" / "networking"
MAIN = (MODULE / "main.tf").read_text(encoding="utf-8")
OUTPUTS = (MODULE / "outputs.tf").read_text(encoding="utf-8")


def test_networking_has_two_tier_route_topology():
    for resource in (
        'resource "aws_vpc"',
        'resource "aws_internet_gateway"',
        'resource "aws_subnet" "public"',
        'resource "aws_subnet" "private"',
        'resource "aws_route_table" "public"',
        'resource "aws_route_table" "private"',
        'resource "aws_nat_gateway" "nat"',
        'resource "aws_route" "public_default"',
        'resource "aws_route" "private_default"',
    ):
        assert resource in MAIN


def test_prod_nat_shape_and_private_node_contract_are_declared():
    # Prod (or nat_per_az) creates one NAT per AZ; otherwise a single NAT keyed "0".
    # for_each requires a set of strings, so the indices are stringified.
    assert '(var.environment == "prod" || var.nat_per_az) ? toset([for index in range(length(local.selected_azs)) : tostring(index)]) : toset(["0"])' in MAIN
    assert '"kubernetes.io/role/internal-elb"' in MAIN
    assert 'private_subnet_ids' in OUTPUTS
    assert 'public_subnet_ids' in OUTPUTS


def test_required_tags_are_applied_to_network_resources():
    assert "required_tags =" in MAIN
    assert "Environment = var.environment" in MAIN
    assert "Project     = var.project" in MAIN
    assert "ManagedBy   = var.managed_by" in MAIN
