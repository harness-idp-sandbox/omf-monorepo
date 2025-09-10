# data to help build ARNs/IDs
data "aws_caller_identity" "me" {}

# Reuse existing GitHub OIDC provider if present; if not, uncomment the resource below.
# data "aws_iam_openid_connect_provider" "github" {
#   arn = "arn:aws:iam::${data.aws_caller_identity.me.account_id}:oidc-provider/token.actions.githubusercontent.com"
# }

# If your account does NOT have the provider yet, use this instead of the data source above:
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # current GitHub IdP root
}

locals {
  # Change these to your GitHub org/repo
  github_org  = "harness-idp-sandbox"
  github_repo = "monorepo-idp-example"
}

# Trust policy: allow this repo's workflows to assume the role
data "aws_iam_policy_document" "gha_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [
        # swap to aws_iam_openid_connect_provider.github.arn if you created it via resource
        data.aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Allow any ref in this repo; tighten if you want (e.g., main only)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_org}/${local.github_repo}:*"]
    }
  }
}

# Permissions policy
# For quick POCs, attach PowerUserAccess. For least-priv, see the two examples below.
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-${local.github_org}-${local.github_repo}"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_role.json
  description        = "OIDC role for GitHub Actions (${local.github_org}/${local.github_repo})"
}

# EITHER: broad POC access (easy)
resource "aws_iam_role_policy_attachment" "poc_poweruser" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# OR: split policies (safer) — uncomment and remove PowerUserAccess above once happy.

# resource "aws_iam_policy" "deploy_site" {
#   name        = "gh-${local.github_org}-${local.github_repo}-deploy-site"
#   description = "Allow s3 sync to bucket + CloudFront invalidation"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = ["s3:ListBucket"]
#         Resource = "arn:aws:s3:::*"
#       },
#       {
#         Effect   = "Allow"
#         Action   = ["s3:GetObject","s3:PutObject","s3:DeleteObject"]
#         Resource = "arn:aws:s3:::*/*"
#       },
#       {
#         Effect   = "Allow"
#         Action   = ["cloudfront:CreateInvalidation","cloudfront:GetDistribution","cloudfront:ListDistributions"]
#         Resource = "*"
#       }
#     ]
#   })
# }
# resource "aws_iam_role_policy_attachment" "deploy_site_attach" {
#   role       = aws_iam_role.github_actions.name
#   policy_arn = aws_iam_policy.deploy_site.arn
# }

# resource "aws_iam_policy" "terraform_infra" {
#   name        = "gh-${local.github_org}-${local.github_repo}-terraform-infra"
#   description = "Allow Terraform to manage S3 bucket & CloudFront distribution"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:CreateBucket","s3:DeleteBucket","s3:PutBucketPolicy","s3:GetBucketPolicy",
#           "s3:PutBucketPublicAccessBlock","s3:GetBucketPublicAccessBlock",
#           "s3:PutBucketOwnershipControls","s3:GetBucketOwnershipControls",
#           "s3:PutBucketTagging","s3:GetBucketTagging",
#           "s3:GetBucketLocation","s3:ListBucket"
#         ]
#         Resource = "arn:aws:s3:::*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "cloudfront:CreateDistribution","cloudfront:UpdateDistribution","cloudfront:DeleteDistribution",
#           "cloudfront:TagResource","cloudfront:UntagResource","cloudfront:GetDistribution",
#           "cloudfront:ListTagsForResource","cloudfront:CreateInvalidation"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }
# resource "aws_iam_role_policy_attachment" "terraform_infra_attach" {
#   role       = aws_iam_role.github_actions.name
#   policy_arn = aws_iam_policy.terraform_infra.arn
# }
