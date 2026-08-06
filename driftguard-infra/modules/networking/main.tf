data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs   = length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, 2) : var.availability_zones
  subnet_indices = { for index, az in local.selected_azs : tostring(index) => az }
  nat_indices    = (var.environment == "prod" || var.nat_per_az) ? toset([for index in range(length(local.selected_azs)) : tostring(index)]) : toset(["0"])
  required_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = var.managed_by
  }
}

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:VPC flow logs require an account-level destination and retention design; they are not part of this module's declared contract.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.required_tags

  lifecycle {
    precondition {
      condition     = length(var.public_subnet_cidrs) == length(local.selected_azs) && length(var.private_subnet_cidrs) == length(local.selected_azs)
      error_message = "public_subnet_cidrs and private_subnet_cidrs must have one CIDR per selected AZ."
    }
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = local.required_tags
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []
  tags    = local.required_tags
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:These are intentionally public ALB subnets; worker nodes use the private subnet resource below.
  for_each = local.subnet_indices

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = var.public_subnet_cidrs[each.key]
  map_public_ip_on_launch = true
  tags = merge(local.required_tags, {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  for_each = local.subnet_indices

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = var.private_subnet_cidrs[each.key]
  tags = merge(local.required_tags, {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    # Karpenter discovers node subnets by this tag; value is unique per cluster.
    "karpenter.sh/discovery" = var.cluster_name
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = local.required_tags
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = local.subnet_indices

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = local.nat_indices
  domain   = "vpc"
  tags     = local.required_tags
}

resource "aws_nat_gateway" "nat" {
  for_each = local.nat_indices

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.this]
  tags          = local.required_tags
}

resource "aws_route_table" "private" {
  for_each = local.subnet_indices
  vpc_id   = aws_vpc.this.id
  tags     = local.required_tags
}

resource "aws_route" "private_default" {
  for_each = local.subnet_indices

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[(var.environment == "prod" || var.nat_per_az) ? each.key : "0"].id
}

resource "aws_route_table_association" "private" {
  for_each = local.subnet_indices

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
