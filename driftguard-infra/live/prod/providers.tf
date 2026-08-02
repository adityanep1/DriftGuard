variable "aws_region" {
  description = "AWS region for the prod environment."
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "prod"
      Project     = "driftguard"
      ManagedBy   = "terraform"
    }
  }
}
