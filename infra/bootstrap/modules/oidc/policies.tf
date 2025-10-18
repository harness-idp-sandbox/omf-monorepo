# policies.tf (top)
locals {
  # Prefer the iac-state output (remote), else the explicit var, else empty
  policy_json_from_remote       = try(data.terraform_remote_state.iac_state.outputs.backend_access_policy_json, "")
  backend_policy_json_effective = length(trimspace(local.policy_json_from_remote)) > 0 ? local.policy_json_from_remote : trimspace(var.backend_access_policy_json)

  # Whether we have JSON to attach directly
  backend_policy_json_provided = var.attach_backend_access && length(trimspace(local.backend_policy_json_effective)) > 0

  # Synthesize a fallback policy from explicit ARNs only if no JSON was provided
  backend_fallback_needed = var.attach_backend_access && !local.backend_policy_json_provided && length(trimspace(var.tfstate_bucket_arn)) > 0 && length(trimspace(var.lock_table_arn)) > 0
}

resource "aws_iam_policy" "backend_access_from_json" {
  count  = local.backend_policy_json_provided ? 1 : 0
  name   = "${var.role_name}-tf-backend"
  policy = local.backend_policy_json_effective
  tags   = var.tags
}

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

locals {
  backend_from_json_arn = try(aws_iam_policy.backend_access_from_json[0].arn, null)
  backend_fallback_arn  = try(aws_iam_policy.backend_access_fallback[0].arn, null)
  backend_policy_arn    = local.backend_from_json_arn != null ? local.backend_from_json_arn : local.backend_fallback_arn
}

resource "aws_iam_role_policy_attachment" "backend_access_json" {
  count      = length(aws_iam_policy.backend_access_from_json) # 0 or 1, known at plan
  role       = aws_iam_role.gha_oidc.name
  policy_arn = aws_iam_policy.backend_access_from_json[0].arn
}

resource "aws_iam_role_policy_attachment" "backend_access_fallback" {
  count      = length(aws_iam_policy.backend_access_fallback) # 0 or 1, known at plan
  role       = aws_iam_role.gha_oidc.name
  policy_arn = aws_iam_policy.backend_access_fallback[0].arn
}
