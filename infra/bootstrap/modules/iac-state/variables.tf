#variables.tf
variable "region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Prefix for the state bucket; a random suffix is added if no override is supplied."
  type        = string
  default     = "tfstate"

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.bucket_prefix)) && length(var.bucket_prefix) >= 3 && length(var.bucket_prefix) <= 50
    error_message = "bucket_prefix must be 3-50 chars, lowercase letters, numbers, dots, or hyphens."
  }
}

variable "bucket_name_override" {
  description = "Optional: exact bucket name to use (skips random suffix). Leave empty to use prefix+random."
  type        = string
  default     = ""
}

variable "bucket_force_destroy" {
  description = "If true, allow bucket deletes to also delete all objects. Keep false for safety."
  type        = bool
  default     = false
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locks."
  type        = string
  default     = "tfstate-locks"
}

variable "use_kms" {
  description = "Use SSE-KMS for S3 bucket encryption (instead of SSE-S3)."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN to use when use_kms = true. If empty, a new key is created."
  type        = string
  default     = ""
}

variable "kms_alias" {
  description = "Alias to assign to the created KMS key when use_kms = true and no kms_key_arn is provided."
  type        = string
  default     = "alias/tfstate"
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep noncurrent object versions (cost control for versioned state)."
  type        = number
  default     = 30
}

variable "abort_multipart_days" {
  description = "Abort incomplete multipart uploads after N days."
  type        = number
  default     = 7
}

variable "state_key_prefix" {
  description = "Prefix used in backend key examples, e.g., 'repos/<org>/<repo>' or 'repos/<org>/<repo>/<env>'."
  type        = string
  default     = "repos/harness-idp-sandbox/harness-monorepo"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project = "terraform-backend"
    Owner   = "HarnessPOV"
  }
}
