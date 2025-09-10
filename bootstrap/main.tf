locals {
  github_org  = "harness-idp-sandbox"
  github_repo = "monorepo-idp-example"
}

# Create the OIDC provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Trust both intermediates per GitHub guidance
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# Trust policy allowing your repo to assume the role via OIDC
data "aws_iam_policy_document" "gha_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_org}/${local.github_repo}:*"]
      # You can tighten later to: repo:ORG/REPO:ref:refs/heads/main
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-${local.github_org}-${local.github_repo}"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_role.json
  description        = "OIDC role for GitHub Actions (${local.github_org}/${local.github_repo})"
}

# For fast POCs, attach PowerUserAccess (tighten later)
resource "aws_iam_role_policy_attachment" "poc_poweruser" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
