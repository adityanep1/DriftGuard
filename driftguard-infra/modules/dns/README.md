# DNS module

Creates a public Route53 hosted zone, a DNS-validated ACM certificate covering every
`external_hostnames` entry, and optional ALB alias records. ACM validation has a ten-minute
create timeout; a timeout fails the certificate validation and therefore does not expose a
validated HTTPS certificate. Pass `alb_dns_name` and `alb_zone_id` after the AWS Load Balancer
Controller has provisioned the ALB.
