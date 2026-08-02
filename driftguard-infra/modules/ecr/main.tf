locals {
  required_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = var.managed_by
  }
}

resource "aws_ecr_repository" "service" {
  #checkov:skip=CKV_AWS_136:AES256 encryption at rest is an explicit supported module mode and satisfies the ECR requirement without requiring a caller-managed CMK.
  for_each = var.services

  name                 = "${var.name_prefix}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  dynamic "encryption_configuration" {
    for_each = var.encryption_type == "KMS" ? [1] : []
    content {
      encryption_type = var.encryption_type
      kms_key         = var.kms_key_arn
    }
  }

  dynamic "encryption_configuration" {
    for_each = var.encryption_type == "AES256" ? [1] : []
    content {
      encryption_type = "AES256"
    }
  }

  tags = local.required_tags
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each = var.services

  repository = aws_ecr_repository.service[each.key].name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after ${var.untagged_image_retention_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.untagged_image_retention_days
      }
      action = {
        type = "expire"
      }
    }]
  })

  depends_on = [aws_ecr_repository.service]
}
