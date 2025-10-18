#terraform.tfvars
# GitHub org and repo this role will trust
github_org  = "harness-idp-sandbox"
github_repo = ""

# Reuse the existing global OIDC provider in your AWS account
create_oidc_provider      = false
existing_oidc_provider_arn = "arn:aws:iam::759984737373:oidc-provider/token.actions.githubusercontent.com"

# Allow PRs, tags, and pushes to branches
allowed_subjects = [
  "pull_request",
  "refs/heads/*",
  "refs/tags/*"
]

# IAM role settings
role_name                = "gha-oidc-role"
session_duration_seconds = 3600

# Backend access — attach S3 + DDB policy for Terraform state
attach_backend_access       = true
backend_access_policy_json  = ""

# Optional managed policies for additional permissions
managed_policy_arns = [
  # Broad access for CI/CD and app provisioning (adjust later if desired)
  "arn:aws:iam::aws:policy/PowerUserAccess"
]

# Region and tags
region = "us-east-1"
tags = {
  Project = "HarnessPOV"
  Owner   = "Parson"
}