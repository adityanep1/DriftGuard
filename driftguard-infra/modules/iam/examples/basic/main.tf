provider "aws" {
  region = "us-east-1"
}

module "iam" {
  source = "../.."

  name_prefix               = "driftguard-dev"
  environment               = "dev"
  project                   = "driftguard"
  cluster_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  oidc_issuer_url           = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  workloads = {
    demo-service = {
      namespace       = "demo"
      service_account = "demo-service"
      policy_statements = [{
        actions   = ["s3:GetObject"]
        resources = ["arn:aws:s3:::driftguard-dev-demo/*"]
      }]
    }
  }
}
