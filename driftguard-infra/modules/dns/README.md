# DNS Module

This module creates a public Route53 hosted zone, a DNS-validated ACM certificate covering every entry in `external_hostnames`, and optional ALB alias records. It handles the full lifecycle of DNS-validated TLS: zone creation, certificate request, validation record creation, and certificate validation.

## Key behavior

ACM certificate validation has a 10-minute create timeout. If validation does not complete within that window, the operation fails and no validated HTTPS certificate is exposed. This is a safety measure: you never get a half-validated certificate that might cause confusion.

The optional ALB alias records should be created after the AWS Load Balancer Controller has provisioned the ALB. Pass `alb_dns_name` and `alb_zone_id` once the load balancer exists.

## Inputs

- `zone_name`: The DNS zone to create (e.g., `example.com`)
- `external_hostnames`: List of hostnames for the ACM certificate
- `alb_dns_name` and `alb_zone_id`: Optional, for creating alias records pointing to the ALB
- Standard tags: `environment`, `project`, `managed_by`

## Outputs

Zone ID, certificate ARN, and DNS validation records.

## Validation

Run the platform composition tests (`test_platform_composition.py`) to verify the module declares the expected structure: Route53 zone, ACM certificate, validation timeout, and optional ALB records. Also run Terraform formatting and validation checks.
