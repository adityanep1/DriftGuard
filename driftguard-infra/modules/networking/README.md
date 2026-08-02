# Networking Module

This module creates the network foundation for one DriftGuard environment: a VPC with public and private subnets across at least two Availability Zones, an internet gateway, public and private route tables, and NAT gateway routing so private workloads can reach the internet without being directly exposed.

## Inputs

| Variable | What it controls |
|---|---|
| `environment` | `dev`, `staging`, or `prod` (production forces NAT-per-AZ for availability) |
| `project` and `managed_by` | Required tag values for resource identification |
| `vpc_cidr` | The overall VPC address space |
| `availability_zones` | Which AZs to use (minimum 2) |
| `public_subnet_cidrs` | CIDR blocks for public subnets (one per AZ) |
| `private_subnet_cidrs` | CIDR blocks for private subnets (one per AZ) |
| `cluster_name` | Used for EKS subnet discovery tags |
| `nat_per_az` | Whether non-production environments get high-availability NAT |

Public and private subnet CIDR lists must each cover the selected AZ set. Worker nodes go in private subnets only; public subnets are intended for internet-facing load balancers.

## Outputs

`vpc_id`, `vpc_cidr_block`, `availability_zones`, `public_subnet_ids`, `private_subnet_ids`, and `nat_gateway_ids`.

## Cost and availability trade-off

NAT gateways are billable per hour and per GB of data processed. Non-production environments default to a single NAT gateway (cheaper but creates a single point of failure for outbound traffic). Production is forced to NAT-per-AZ regardless of the `nat_per_az` setting, because availability matters more than cost in prod.

## Validation

Run the basic example, Terraform validation, networking static tests, tag conformance, and security scans. Confirm that public routes target the internet gateway, private routes target NAT, and every taggable resource carries the three required tags (`Environment`, `Project`, `ManagedBy`). Review CIDR overlap before apply and never place EKS worker nodes in public subnets.
