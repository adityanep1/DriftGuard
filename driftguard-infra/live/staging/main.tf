module "networking" {
  source = "../../modules/networking"

  environment          = "staging"
  project              = "driftguard"
  cluster_name         = "driftguard-staging"
  nat_per_az           = var.nat_per_az
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks" {
  source = "../../modules/eks"

  name                = "driftguard-staging"
  environment         = "staging"
  project             = "driftguard"
  kubernetes_version  = var.kubernetes_version
  private_subnet_ids  = module.networking.private_subnet_ids
  public_access_cidrs = var.public_access_cidrs
  max_node_count      = var.max_node_count
  node_groups         = var.node_groups
}

module "iam" {
  source = "../../modules/iam"

  name_prefix               = "driftguard-staging"
  environment               = "staging"
  project                   = "driftguard"
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url           = module.eks.oidc_issuer_url
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = "driftguard-staging"
  environment = "staging"
  project     = "driftguard"
  services    = var.ecr_services
}

module "dns" {
  count  = var.enable_dns ? 1 : 0
  source = "../../modules/dns"

  zone_name          = var.dns_zone_name
  external_hostnames = var.external_hostnames
  environment        = "staging"
  project            = "driftguard"
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  environment       = "staging"
  project           = "driftguard"
  github_repository = var.github_repository
  branch            = "main"
}

output "vpc_id" {
  description = "Environment VPC ID."
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private-only subnet IDs used by EKS worker nodes."
  value       = module.networking.private_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "ecr_repository_urls" {
  description = "Private ECR repository URLs keyed by service."
  value       = module.ecr.repository_urls
}

output "max_node_count" {
  description = "Environment-wide worker-node cap."
  value       = var.max_node_count
}

output "dns_certificate_arn" {
  description = "Validated ACM certificate ARN when DNS is enabled."
  value       = var.enable_dns ? module.dns[0].certificate_arn : null
}

output "ecr_publish_role_arn" {
  description = "GitHub Actions role ARN for ECR image publishing."
  value       = module.github_oidc.ecr_publish_role_arn
}

output "terraform_apply_role_arn" {
  description = "GitHub Actions role ARN for Terraform apply (branch-only trust)."
  value       = module.github_oidc.terraform_role_arn
}

output "terraform_plan_role_arn" {
  description = "GitHub Actions role ARN for Terraform plan (branch + PR trust)."
  value       = module.github_oidc.terraform_plan_role_arn
}

output "terraform_drift_role_arn" {
  description = "GitHub Actions role ARN for Terraform drift-check (branch-only trust)."
  value       = module.github_oidc.terraform_drift_role_arn
}
