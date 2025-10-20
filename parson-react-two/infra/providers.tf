# providers.tf
terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_slug
      Environment = var.environment
      CreatedFor  = "HarnessPOV"
      ManagedBy   = "TerraformByHarness"
    }
  }
}
