# oidc/remote_state.tf
data "terraform_remote_state" "iac_state" {
  backend = "s3"

  # Use the SAME backend location where your iac-state module stores ITS state.
  # If your iac-state is still local, first migrate that to S3 (recommended).
  config = {
    bucket         = "tfstate-1178da"      # e.g., tfstate-1178da
    key            = "org/harness-idp-sandbox/iac-state/terraform.tfstate"  # <-- whatever key you used for iac-state
    region         = "us-east-1"           # e.g., us-east-1
    dynamodb_table = "tfstate-locks"       # e.g., tfstate-locks
    encrypt        = true
  }
}