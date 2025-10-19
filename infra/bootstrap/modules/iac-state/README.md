# GitHub OIDC Role Module (Terraform)

This module provisions an **IAM Role** and optional **OIDC Provider** for use with **GitHub Actions**.  
It allows workflows in specified organizations, repositories, and branches (or tags, PRs, environments) to assume an AWS role using the OIDC federation trust.

---

## 📦 Module Overview

| Capability | Description |
|-------------|-------------|
| **IAM Role** | Role trusted by GitHub's OIDC provider (`token.actions.githubusercontent.com`) |
| **OIDC Provider** | Can create or reuse an existing provider |
| **Scoped Trust** | Restricts allowed subjects to specific orgs, repos, branches, tags, or environments |
| **Backend Policy (optional)** | Attaches path-scoped S3 + DynamoDB access for Terraform remote state |
| **Least Privilege Ready** | Accepts JSON from `iac-state` module to restrict state access |

---

## 🧩 Inputs

| Variable | Description | Default |
|-----------|-------------|----------|
| `region` | AWS region for IAM operations | `us-east-1` |
| `github_org` | GitHub organization name | *(required)* |
| `github_repo` | Repository name (optional, empty = all repos in org) | `""` |
| `allowed_subjects` | List of allowed refs or subjects (branches, tags, pull_request, environment:dev) | `["refs/heads/main"]` |
| `role_name` | Name of the IAM Role | `gha-oidc-role` |
| `session_duration_seconds` | Max STS session duration | `3600` |
| `create_oidc_provider` | Whether to create the OIDC provider | `false` |
| `existing_oidc_provider_arn` | ARN of an existing OIDC provider | `""` |
| `oidc_thumbprint_list` | List of provider thumbprints | `[6938fd4d98ba…]` |
| `attach_backend_access` | Attach backend access policy to role | `false` |
| `backend_access_policy_json` | JSON policy (preferred, from iac-state output) | `""` |
| `tfstate_bucket_arn` | Fallback: S3 bucket ARN for Terraform state | `""` |
| `lock_table_arn` | Fallback: DynamoDB table ARN for locks | `""` |
| `tags` | Map of resource tags | `{}` |

---

## 🚀 How to Run It

### Using the Helper Scripts (Recommended)

The module includes helper scripts for easier setup:

```bash
# Run the apply script (interactive setup)
./apply.sh

# To destroy (use with caution!)
./destroy.sh
```

The `apply.sh` script will:

- Read configuration from your `terraform.tfvars` file  
- Prompt for key variables with defaults from your tfvars  
- Apply the Terraform configuration  
- Generate an `oidc.env` file with the role ARN for GitHub Actions  

---

### Manual Setup

From the module directory:

```bash
# Create terraform.tfvars if you don't have one
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars as needed

# Apply the configuration
terraform fmt
terraform init
terraform plan
terraform apply -auto-approve
```

Example `terraform.tfvars`:

```hcl
region                     = "us-east-1"
github_org                 = "harness-idp-sandbox"
github_repo                = "customer-monorepo"
allowed_subjects           = ["refs/heads/main", "pull_request", "environment:dev"]
role_name                  = "gha-oidc-role"
create_oidc_provider       = false
existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
attach_backend_access      = true
backend_access_policy_json = "..." # From iac-state module output
```

---

## 🧩 Outputs

| Output | Description |
|---------|-------------|
| `role_arn` | ARN of the IAM Role for GitHub Actions |
| `oidc_provider_arn` | ARN of the created or existing OIDC provider |

---

## 🧱 Integration with iac-state

Pass the JSON output from your Terraform state backend module:

```hcl
backend_access_policy_json = module.iac_state.backend_access_policy_json
```

This ensures your OIDC role has least-privilege access to the correct S3 prefix and DynamoDB table for state locking.

---

## ✅ How to Tell If It's Been Run (Verification)

**Check for helper files:**  
If `oidc.env` exists in the module directory, the module has likely been applied.

**Verify Terraform outputs:**

```bash
terraform output role_arn
# => arn:aws:iam::123456789012:role/gha-oidc-role
```

**Check IAM role:**

```bash
aws iam get-role --role-name gha-oidc-role
```

**Check trust relationship:**

```bash
aws iam get-role --role-name gha-oidc-role --query "Role.AssumeRolePolicyDocument" --output json
```

---

## 🧩 GitHub Actions Example

```yaml
jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_GHA_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Terraform Init
        run: terraform init -backend-config=backend.hcl
      
      - name: Terraform Plan
        run: terraform plan -out=tfplan
```

---

## 🧠 Notes for Sales Engineers

- SEs should **never modify IAM trust logic manually** — use input variables or environment overrides in `apply.sh`.  
- Always test with a **sandbox AWS account first**.  
- Set `CREATE_OIDC_PROVIDER=true` only if the account has **no provider yet**.  
- Use the `oidc.env` file to populate repo/org secrets automatically in Harness IDP pipelines.  
- For secure operations, always **scope the role** to specific repositories and branches.

---
