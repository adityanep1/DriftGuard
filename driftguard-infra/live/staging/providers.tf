variable "aws_region" {
  description = "AWS region for the staging environment."
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "driftguard"
      ManagedBy   = "terraform"
    }
  }
}
