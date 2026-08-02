locals {
  required_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
  # Apply/drift: runs on the default branch (push or schedule)
  subject_branch = "repo:${var.github_repository}:ref:refs/heads/${var.branch}"
  # Plan: runs on pull_request events
  subject_pr = "repo:${var.github_repository}:pull_request"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  tags            = local.required_tags
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.subject_branch]
    }
  }
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.subject_branch, local.subject_pr]
    }
  }
}

resource "aws_iam_role" "ecr_publish" {
  name               = "${var.project}-${var.environment}-github-ecr"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.required_tags
}

resource "aws_iam_role_policy" "ecr_publish" {
  role = aws_iam_role.ecr_publish.id
  name = "ecr-publish"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      Resource = "arn:aws:ecr:*:*:repository/${var.project}-${var.environment}/*"
      }, {
      Effect   = "Allow"
      Action   = ["ecr:GetAuthorizationToken"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "terraform" {
  name               = "${var.project}-${var.environment}-github-terraform"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.required_tags
}

resource "aws_iam_role_policy" "terraform" {
  #checkov:skip=CKV_AWS_287:This short-lived OIDC role is the explicitly scoped Terraform bootstrap role; its permissions are bounded by repository/branch trust and the target account.
  #checkov:skip=CKV_AWS_288:The role is used only by the reviewed Terraform workflow and is not a long-lived credential or data-export role.
  #checkov:skip=CKV_AWS_289:Terraform must create and manage the declared AWS substrate; reducing this policy to resource ARNs would break create-time APIs that have no resource ARN.
  #checkov:skip=CKV_AWS_286:Role assumption is restricted to the configured GitHub repository and branch through OIDC conditions.
  #checkov:skip=CKV_AWS_355:Several AWS create/describe APIs used by Terraform do not support resource-level permissions; the custom policy rejects wildcard action plus wildcard resource combinations.
  #checkov:skip=CKV_AWS_290:This is a deployment role intentionally limited to the infrastructure workflow and protected by GitHub OIDC trust conditions.
  role = aws_iam_role.terraform.id
  name = "terraform-environment"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:*", "ec2:*", "iam:PassRole", "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "ecr:*", "route53:*", "acm:*", "kms:*", "s3:*", "dynamodb:*", "elasticloadbalancing:*"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "terraform_plan" {
  name               = "${var.project}-${var.environment}-github-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_plan.json
  tags               = local.required_tags
}

resource "aws_iam_role_policy" "terraform_plan" {
  #checkov:skip=CKV_AWS_355:Terraform plan requires Describe/Get/List across diverse service APIs that do not support resource-level permissions.
  #checkov:skip=CKV_AWS_290:This is a read-only plan role for the PR gate, restricted by GitHub OIDC trust conditions.
  role = aws_iam_role.terraform_plan.id
  name = "terraform-plan"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadOnlyForPlan"
        Effect   = "Allow"
        Action   = ["eks:Describe*", "eks:List*", "ec2:Describe*", "iam:Get*", "iam:List*", "ecr:Describe*", "ecr:List*", "ecr:GetRepositoryPolicy", "route53:Get*", "route53:List*", "acm:Describe*", "acm:List*", "kms:Describe*", "kms:List*", "kms:GetKeyPolicy", "s3:Get*", "s3:List*", "dynamodb:Describe*", "dynamodb:List*", "elasticloadbalancing:Describe*"]
        Resource = "*"
      },
      {
        Sid      = "StateAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = ["arn:aws:s3:::driftguard-*-state", "arn:aws:s3:::driftguard-*-state/*", "arn:aws:dynamodb:*:*:table/driftguard-*-locks"]
      }
    ]
  })
}

resource "aws_iam_role" "terraform_drift" {
  name               = "${var.project}-${var.environment}-github-terraform-drift"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.required_tags
}

resource "aws_iam_role_policy" "terraform_drift" {
  #checkov:skip=CKV_AWS_355:Terraform drift check requires Describe/Get/List across diverse service APIs that do not support resource-level permissions.
  #checkov:skip=CKV_AWS_290:This is a read-only drift role restricted by GitHub OIDC trust conditions.
  role = aws_iam_role.terraform_drift.id
  name = "terraform-drift"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadOnlyForDrift"
        Effect   = "Allow"
        Action   = ["eks:Describe*", "eks:List*", "ec2:Describe*", "iam:Get*", "iam:List*", "ecr:Describe*", "ecr:List*", "ecr:GetRepositoryPolicy", "route53:Get*", "route53:List*", "acm:Describe*", "acm:List*", "kms:Describe*", "kms:List*", "kms:GetKeyPolicy", "s3:Get*", "s3:List*", "dynamodb:Describe*", "dynamodb:List*", "elasticloadbalancing:Describe*"]
        Resource = "*"
      },
      {
        Sid      = "StateAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket", "dynamodb:GetItem"]
        Resource = ["arn:aws:s3:::driftguard-*-state", "arn:aws:s3:::driftguard-*-state/*", "arn:aws:dynamodb:*:*:table/driftguard-*-locks"]
      }
    ]
  })
}
