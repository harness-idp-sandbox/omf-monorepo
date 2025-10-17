terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  bucket_name = "${var.bucket_prefix}-${random_id.suffix.hex}"
}

data "aws_iam_policy_document" "backend_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.tf[0].arn}/*"
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

resource "aws_s3_bucket" "tf" {
  count         = var.force_destroy ? 0 : 1
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf" {
  count  = var.force_destroy ? 0 : 1
  bucket = aws_s3_bucket.tf[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf" {
  count  = var.force_destroy ? 0 : 1
  bucket = aws_s3_bucket.tf[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_kms && var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.use_kms && var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf" {
  count                   = var.force_destroy ? 0 : 1
  bucket                  = aws_s3_bucket.tf[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "bucket_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tf[0].arn,
      "${aws_s3_bucket.tf[0].arn}/*",
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
  count  = var.force_destroy ? 0 : 1
  bucket = aws_s3_bucket.tf[0].id
  policy = data.aws_iam_policy_document.bucket_tls_only.json
}

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