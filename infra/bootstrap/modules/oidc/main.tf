#main.tf
# Create GitHub OIDC provider if your account doesn't have it yet
# Thumbprints are managed by AWS provider; update if ever needed.
# Optionally create the account-level GitHub OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.oidc_thumbprint_list
  tags            = var.tags
}

resource "aws_iam_role" "gha_oidc" {
  name                 = var.role_name
  description          = "Role assumed by GitHub Actions via OIDC for ${var.github_org}/${var.github_repo != "" ? var.github_repo : "*"}"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.session_duration_seconds
  tags                 = var.tags
}

# Choose provider ARN (created or pre-existing)
locals {
  # Split into two locals to avoid coalesce()
  created_oidc_arn   = try(aws_iam_openid_connect_provider.github[0].arn, null)
  existing_oidc_arn  = (
    var.existing_oidc_provider_arn != null && length(trimspace(var.existing_oidc_provider_arn)) > 0
    ? var.existing_oidc_provider_arn
    : null
  )

  # Final choice: created beats existing; may still be null (and that's OK)
  oidc_provider_arn = local.created_oidc_arn != null ? local.created_oidc_arn : local.existing_oidc_arn

  # Repo selector
  github_repo_effective = (
    length(trimspace(var.github_repo)) > 0 ? trimspace(var.github_repo) : "*"
  )
  repo_selector = "repo:${var.github_org}/${local.github_repo_effective}"

  subject_patterns = [
    for s in var.allowed_subjects :
    startswith(s, "refs/") ? "${local.repo_selector}:ref:${s}" : "${local.repo_selector}:${s}"
  ]
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "GitHubOIDCAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.subject_patterns
    }
  }
}

# Attach any extra managed policies you want (e.g., AmazonS3ReadOnlyAccess during testing)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.gha_oidc.name
  policy_arn = each.value
}