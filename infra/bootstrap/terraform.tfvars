# infra/bootstrap/terraform.tfvars
region                   = "us-east-1"
bucket_name_prefix       = "tfstate"
lock_table_name          = "tfstate-locks"
github_org               = "harness-idp-sandbox"
github_repo              = "" # Empty means any repo in the org
allowed_refs             = ["refs/heads/main"]
role_name                = "gha-oidc-role"
session_duration_seconds = 3600
tags = {
  Project = "terraform-backend"
  Owner   = "HarnessPOV-omf"
}
