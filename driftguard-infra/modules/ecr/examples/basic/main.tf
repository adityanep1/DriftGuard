provider "aws" {
  region = "us-east-1"
}

module "ecr" {
  source = "../.."

  name_prefix = "driftguard-dev"
  environment = "dev"
  project     = "driftguard"
  services    = ["demo-service"]
}
