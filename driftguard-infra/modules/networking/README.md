# Networking module

Creates one environment VPC with public and private subnets across at least two Availability Zones, an internet gateway, public/private route tables, and NAT gateway routing for private workloads.

## Inputs

- `environment`: `dev`, `staging`, or `prod`; production always receives one NAT gateway per selected AZ.
- `project` and `managed_by`: required tag identity.
- `vpc_cidr`, `availability_zones`, `public_subnet_cidrs`, and `private_subnet_cidrs`: topology inputs.
- `cluster_name`: EKS discovery tag source.
- `nat_per_az`: explicit non-production high-availability/cost choice.

Public subnet CIDRs and private subnet CIDRs must each cover the selected AZ set. Worker nodes consume only `private_subnet_ids`; public subnets are intended for internet-facing load balancers.

## Outputs

`vpc_id`, `vpc_cidr_block`, `availability_zones`, `public_subnet_ids`, `private_subnet_ids`, and `nat_gateway_ids`.

## Safety and cost

NAT gateways are billable. Non-production defaults to one NAT gateway unless `nat_per_az` is enabled; production is forced to NAT-per-AZ for availability. Review CIDR overlap before apply and never place EKS worker nodes in public subnets.

## Validation

Run the basic example, Terraform validation, networking static tests, tag conformance, and security scans. Confirm public routes target the IGW, private routes target NAT, and every taggable resource carries the three required tags.
