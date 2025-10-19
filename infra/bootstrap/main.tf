# Add description comments
module "iac_state" {
  source = "./modules/iac-state"

  # Basic configuration
  region          = var.region
  bucket_prefix   = var.bucket_name_prefix # Fix variable name to match module
  lock_table_name = var.lock_table_name

  # Optional: Configure state key prefix for better organization
  state_key_prefix = var.state_key_prefix

  # Pass through all tags
  tags = var.tags
}

module "oidc" {
  source = "./modules/oidc"

  # Basic configuration
  region      = var.region
  github_org  = var.github_org
  github_repo = var.github_repo

  # Security settings
  allowed_subjects         = var.allowed_refs # Fix variable name to match module
  role_name                = var.role_name
  session_duration_seconds = var.session_duration_seconds

  # Connect to the state module
  attach_backend_access      = true
  backend_access_policy_json = module.iac_state.backend_access_policy_json

  # Pass through all tags
  tags = var.tags
}
