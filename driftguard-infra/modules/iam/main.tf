locals {
  required_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = var.managed_by
  }
  oidc_issuer_host = trimprefix(var.oidc_issuer_url, "https://")
}

data "aws_iam_policy_document" "trust" {
  for_each = var.workloads

  statement {
    sid     = "AllowOnlyMappedServiceAccount"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.cluster_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  for_each = var.workloads

  dynamic "statement" {
    for_each = each.value.policy_statements
    content {
      effect    = "Allow"
      actions   = sort(tolist(statement.value.actions))
      resources = sort(tolist(statement.value.resources))
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = var.workloads

  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.trust[each.key].json
  description        = "IRSA role for ${each.value.namespace}/${each.value.service_account}"
  tags               = local.required_tags

  lifecycle {
    precondition {
      condition     = length("${var.name_prefix}-${each.key}") <= 64
      error_message = "IRSA role names must be at most 64 characters."
    }
  }
}

resource "aws_iam_role_policy" "permissions" {
  for_each = var.workloads

  name   = "${each.key}-permissions"
  role   = aws_iam_role.irsa[each.key].id
  policy = data.aws_iam_policy_document.permissions[each.key].json

  depends_on = [aws_iam_role.irsa]
}
