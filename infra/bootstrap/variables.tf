# infra/bootstrap/variables.tf
variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "tfstate"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "tfstate-locks"
}

variable "state_key_prefix" {
  description = "Prefix for state keys in the bucket"
  type        = string
  default     = "repos/your-org/your-repo"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (empty for any repo in the org)"
  type        = string
  default     = ""
}

variable "allowed_refs" {
  description = "List of GitHub refs that can assume the role"
  type        = list(string)
  default     = ["refs/heads/main"]
}

variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "gha-oidc-role"
}

variable "session_duration_seconds" {
  description = "Maximum session duration for the role"
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
