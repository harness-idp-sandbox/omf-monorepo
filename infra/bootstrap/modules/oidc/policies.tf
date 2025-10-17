############################
# Backend access policies
############################

# Drive intent with booleans (easier to read & reuse)
locals {
  backend_policy_json_provided = var.attach_backend_access && trim(var.backend_access_policy_json) != ""
  backend_fallback_needed      = var.attach_backend_access && trim(var.backend_access_policy_json) == "" && trim(var.tfstate_bucket_arn) != "" && trim(var.lock_table_arn) != ""
}

# If caller provides policy JSON, attach it directly (preferred).
resource "aws_iam_policy" "backend_access_from_json" {
  count  = local.backend_policy_json_provided ? 1 : 0
  name   = "${var.role_name}-tf-backend"
  policy = var.backend_access_policy_json
  tags   = var.tags
}

# Fallback: synthesize minimal bucket-wide policy (less strict).
data "aws_iam_policy_document" "backend_fallback" {
  count = local.backend_fallback_needed ? 1 : 0

  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.tfstate_bucket_arn]
  }

  statement {
    sid       = "RWStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.tfstate_bucket_arn}/*"]
  }

  statement {
    sid       = "LockTable"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem", "dynamodb:UpdateItem"]
    resources = [var.lock_table_arn]
  }
}

resource "aws_iam_policy" "backend_access_fallback" {
  count  = local.backend_fallback_needed ? 1 : 0
  name   = "${var.role_name}-tf-backend"
  policy = data.aws_iam_policy_document.backend_fallback[0].json
  tags   = var.tags
}

# Choose whichever policy exists; otherwise attach nothing.
locals {
  backend_from_json_arn = try(aws_iam_policy.backend_access_from_json[0].arn, null)
  backend_fallback_arn  = try(aws_iam_policy.backend_access_fallback[0].arn, null)

  # Choose whichever exists; may be null if neither is created
  backend_policy_arn = local.backend_from_json_arn != null ? local.backend_from_json_arn : local.backend_fallback_arn
}

resource "aws_iam_role_policy_attachment" "backend_access" {
  count      = local.backend_policy_arn != null ? 1 : 0
  role       = aws_iam_role.gha_oidc.name
  policy_arn = local.backend_policy_arn
}
