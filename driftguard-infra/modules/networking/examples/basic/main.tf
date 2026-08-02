module "networking" {
  source = "../.."

  environment          = "dev"
  project              = "driftguard"
  cluster_name         = "driftguard-dev"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.40.0.0/20", "10.40.16.0/20"]
  private_subnet_cidrs = ["10.40.128.0/20", "10.40.144.0/20"]
}
