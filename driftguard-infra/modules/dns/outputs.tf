output "zone_id" {
  description = "Public Route53 hosted-zone ID."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name_servers" {
  description = "Authoritative nameservers for the public zone."
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "Validated ACM certificate ARN covering every external hostname."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "hostname_records" {
  description = "Route53 records created for external hostnames."
  value       = { for hostname, record in aws_route53_record.alb : hostname => record.fqdn }
}
