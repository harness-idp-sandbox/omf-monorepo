# terraform.tfvars - Default values for iac-state module
region                             = "us-east-1"
bucket_prefix                      = "tfstate"
bucket_name_override               = ""
lock_table_name                    = "tfstate-locks"
use_kms                            = false
kms_key_arn                        = ""
state_key_prefix                   = "repos/harness-idp-sandbox/omf-monorepo"
noncurrent_version_expiration_days = 30
abort_multipart_days               = 7
bucket_force_destroy               = false
tags = {
  Project = "terraform-backend"
  Owner   = "HarnessPOV"
}
