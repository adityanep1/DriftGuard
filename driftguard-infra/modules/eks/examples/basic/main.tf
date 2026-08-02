provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source = "../.."

  name                = "driftguard-dev"
  environment         = "dev"
  project             = "driftguard"
  private_subnet_ids  = ["subnet-private-a", "subnet-private-b"]
  public_access_cidrs = ["198.51.100.10/32"]
  # SHA-1-shaped offline example only; not a production certificate thumbprint.
  oidc_thumbprint            = "0123456789abcdef0123456789abcdef01234567"
  cluster_security_group_ids = []

  node_groups = {
    default = {
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.medium"]
      disk_size      = 50
      capacity_type  = "ON_DEMAND"
      labels         = { Environment = "dev" }
    }
  }
}
