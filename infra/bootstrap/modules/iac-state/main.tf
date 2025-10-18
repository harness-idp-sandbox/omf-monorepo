# terramain.t
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  # Region the backend lives in (S3 bucket + DynamoDB table)
  region = var.region
}

# Stable-but-unique bucket naming: allow an override; otherwise prefix + random suffix
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  # Choose a bucket name: explicit override wins; else prefix + random suffix
  bucket_name_random    = "${var.bucket_prefix}-${random_id.suffix.hex}"
  bucket_name_effective = length(trimspace(var.bucket_name_override)) > 0 ? trimspace(var.bucket_name_override) : local.bucket_name_random
}

# ---------------------------------------------------------------------------
# Optional KMS key creation (only if use_kms=true and kms_key_arn not provided)
# ---------------------------------------------------------------------------
resource "aws_kms_key" "tfstate" {
  count                   = local.create_kms_key ? 1 : 0
  description             = "KMS key for Terraform state bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "tfstate" {
  count         = local.create_kms_key ? 1 : 0
  name          = var.kms_alias
  target_key_id = aws_kms_key.tfstate[0].key_id
}

# Resolve the KMS key ARN that SSE-KMS should use (created or provided)
locals {
  # Create a KMS key only when KMS is requested and no ARN was provided
  create_kms_key = var.use_kms && length(trimspace(var.kms_key_arn)) == 0

  # Did the caller give us a non-empty KMS ARN?
  kms_key_provided = var.use_kms && length(trimspace(var.kms_key_arn)) > 0

  # Effective KMS ARN to use for SSE-KMS:
  # - If provided, use it
  # - Else if we created one (count = 1), use that arn
  # - Else empty string (will translate to null in the SSE block)
  kms_key_arn_effective = local.kms_key_provided ? trimspace(var.kms_key_arn) : (local.create_kms_key ? try(aws_kms_key.tfstate[0].arn, "") : "")
}


# -----------------------------------------
# S3 bucket for Terraform remote state
# -----------------------------------------
resource "aws_s3_bucket" "tf" {
  bucket        = local.bucket_name_effective

  # Safety: keep OFF by default so you don't accidentally delete state objects.
  # To teardown quickly, temporarily set this to true and remove prevent_destroy.
  force_destroy = var.bucket_force_destroy

  tags = var.tags

  lifecycle {
    # Protect the state bucket from accidental destroy (recommended for shared backends).
    # For teardown, comment this block out (or set via a variable gate in your own fork).
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "tf" {
  bucket = aws_s3_bucket.tf.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "tf" {
  bucket = aws_s3_bucket.tf.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tf" {
  bucket = aws_s3_bucket.tf.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption default: SSE-S3 (AES256) or SSE-KMS with your key
resource "aws_s3_bucket_server_side_encryption_configuration" "tf" {
  bucket = aws_s3_bucket.tf.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_kms && length(local.kms_key_arn_effective) > 0 ? "aws:kms" : "AES256"
      # Provider v5 uses kms_master_key_id on this resource
      kms_master_key_id = var.use_kms && length(local.kms_key_arn_effective) > 0 ? local.kms_key_arn_effective : null
    }

    # Cheaper KMS charges when enabled; OK to leave false if you're not using KMS
    bucket_key_enabled = var.use_kms
  }
}

# Lifecycle rules keep version churn under control (cost-control)
resource "aws_s3_bucket_lifecycle_configuration" "tf" {
  bucket = aws_s3_bucket.tf.id

  rule {
    id     = "cleanup-noncurrent"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_multipart_days
    }
  }
}

# Bucket policy: enforce TLS-only access
data "aws_iam_policy_document" "bucket_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.tf.arn,
      "${aws_s3_bucket.tf.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf" {
  bucket = aws_s3_bucket.tf.id
  policy = data.aws_iam_policy_document.bucket_tls_only.json
}

# -----------------------------------------
# DynamoDB table for Terraform state lock
# -----------------------------------------
resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Policy JSON: grant just enough for TF backend (S3 objects + DDB CRUD)
# Your OIDC role can attach this document verbatim.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "backend_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.tf.arn}/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.locks.arn
    ]
  }
}
