locals {
  zone_name = trimsuffix(var.zone_name, ".")
  required_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = var.managed_by
  }
}

resource "aws_route53_zone" "this" {
  #checkov:skip=CKV2_AWS_38:DNSSEC requires a separately managed KSK and signing workflow that is outside this module's certificate-validation contract.
  #checkov:skip=CKV2_AWS_39:Route53 query logging requires an account-level log destination and is outside this module's declared scope.
  name = local.zone_name
  tags = local.required_tags
}

resource "aws_acm_certificate" "this" {
  domain_name               = sort(tolist(var.external_hostnames))[0]
  subject_alternative_names = slice(sort(tolist(var.external_hostnames)), 1, length(var.external_hostnames))
  validation_method         = "DNS"
  tags                      = local.required_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for option in aws_acm_certificate.this.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      type   = option.resource_record_type
      record = option.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

resource "aws_route53_record" "alb" {
  for_each = var.alb_dns_name == null ? toset([]) : var.external_hostnames

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_acm_certificate_validation.this]
}
