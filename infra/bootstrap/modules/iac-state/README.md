# iac-state (Terraform backend bootstrap)

Bootstraps a **remote Terraform backend** for a new GitHub org’s infra POCs:
- **S3 bucket** (private, TLS-only, versioned, optionally SSE-KMS)
- **DynamoDB table** for state **locking**
- **Policy JSON output** you can attach to your **GitHub OIDC role** (just enough to read/write state + lock)

> **One-time per AWS account + GitHub org** is typical. You’ll reuse the same backend for multiple repos/stacks by choosing distinct S3 keys.

---

## When to use this

Use this module **before** you set up:
- A new **GitHub org** (e.g. `harness-idp-sandbox`) where you’ll scaffold `<customer>-admin-repo` and `<customer>-monorepo`.
- An **OIDC role** that GitHub Actions will assume to run Terraform.
- Any **cookiecutter**-generated repos that will store TF state in this shared backend.

> If your account already has a stable TF state bucket + lock table you want to reuse, you don’t need to run this. Just point your stacks to that existing backend.

---

## What it creates

- **S3** bucket: private, versioned, **TLS-only** (policy denies non-TLS), optional **SSE-KMS**
- **DynamoDB** table: `PAY_PER_REQUEST`, SSE enabled; used by Terraform for state locking
- **Outputs**:
  - `bucket_name`, `bucket_arn`, `dynamodb_table`, `dynamodb_table_arn`, `region`
  - `backend_access_policy_json` → attach to your OIDC role
  - `backend_hcl_example` → copy/paste for `terraform init -backend-config=backend.hcl`
  - `backend_metadata` → script-friendly map

---

## Inputs

| Variable | Description | Default |
|---|---|---|
| `region` | AWS region for the backend | `us-east-1` |
| `bucket_prefix` | Bucket name prefix; random suffix is appended if no override | `tfstate` |
| `bucket_name_override` | Use this exact bucket name (skips random suffix) | `""` |
| `bucket_force_destroy` | Allow deleting bucket **and objects** (normally `false`) | `false` |
| `lock_table_name` | DynamoDB lock table name | `tfstate-locks` |
| `use_kms` | Use SSE-KMS for the bucket (vs AES256) | `false` |
| `kms_key_arn` | Existing KMS key ARN (when `use_kms=true`) | `""` |
| `kms_alias` | Alias for a **new** KMS key if `use_kms=true` and no ARN | `alias/tfstate` |
| `noncurrent_version_expiration_days` | Keep noncurrent versions this many days | `30` |
| `abort_multipart_days` | Abort incomplete multipart uploads after N days | `7` |
| `state_key_prefix` | Base path for state keys (used in example output) | `repos/harness-idp-sandbox/harness-monorepo` |
| `tags` | Common tags | `{ Project="terraform-backend", Owner="HarnessPOV" }` |

> **Note:** The bucket has `prevent_destroy = true` by default to protect state. See **Teardown** if you ever need to nuke it.

---

## How to run it

From the module directory:

```bash
terraform fmt
terraform init
terraform plan
terraform apply -auto-approve
```

Optionally provide overrides via `terraform.tfvars`:

```hcl
region                = "us-east-1"
bucket_prefix         = "tfstate"
bucket_name_override  = ""        # or "my-shared-tf-backend"
lock_table_name       = "tfstate-locks"
use_kms               = false     # set true if you want SSE-KMS
kms_key_arn           = ""        # leave empty to create a new key when use_kms=true
state_key_prefix      = "repos/harness-idp-sandbox/harness-monorepo"
tags = {
  Project = "terraform-backend"
  Owner   = "HarnessPOV"
}
```

---

## What to do after running it

1) **Capture outputs**
   ```bash
   terraform output -raw bucket_name
   terraform output -raw dynamodb_table
   terraform output -raw region
   terraform output -raw backend_access_policy_json > backend-policy.json
   terraform output backend_hcl_example
   ```

2) **Attach backend access to your GitHub OIDC role**  
   - If you already created an OIDC role for GitHub Actions, attach a policy with the contents of `backend-policy.json`.  
   - If you’re using an OIDC **module**, feed `backend_access_policy_json` to that module so it creates/attaches the policy for you.

3) **Wire GitHub Actions to the backend**  
   In each repo that will run Terraform, create a `backend.hcl` using the example output (change the `key` per stack):
   ```hcl
   bucket         = "<bucket_name output>"
   key            = "repos/<org>/<repo>/<env>/<app>/terraform.tfstate"
   region         = "<region output>"
   dynamodb_table = "<dynamodb_table output>"
   encrypt        = true
   ```

   Then initialize your stacks with:
   ```bash
   terraform init -backend-config=backend.hcl
   ```

4) **Set repo secrets/variables** (if you prefer GH to compose backend.hcl at runtime):
   - Secrets: `TFSTATE_BUCKET`, `TF_LOCK_TABLE`, `AWS_REGION`
   - In workflows, write `backend.hcl` on the fly (you already have examples).

---

## How to tell if it’s been run (verification)

- **Terraform outputs** exist and look sane:
  ```bash
  terraform output backend_metadata
  # => { bucket = "...", dynamodb_table = "...", region = "..." }
  ```

- **S3**: the bucket exists, has versioning enabled, and TLS-only bucket policy:
  ```bash
  aws s3 ls "s3://<bucket_name>/"
  aws s3api get-bucket-versioning --bucket <bucket_name>
  aws s3api get-bucket-policy --bucket <bucket_name> | jq .
  ```

- **DynamoDB**: the table exists and has SSE:
  ```bash
  aws dynamodb describe-table --table-name <dynamodb_table> | jq '.Table.TableStatus,.Table.SSEDescription'
  ```

- **A stack can init against it**:
  ```bash
  cd some/stack
  terraform init -backend-config=../backend.hcl
  terraform state pull >/dev/null && echo "Remote backend reachable"
  ```

- **During a plan/apply**, you can see a lock appear:
  ```bash
  aws dynamodb scan --table-name <dynamodb_table> --query 'Items'
  ```

---

## Teardown (only if you truly need to)

1) Make sure **no stacks** are using this backend (migrate them off).
2) Temporarily allow deletion:
   - In the bucket resource, **remove** the `lifecycle { prevent_destroy = true }` block.
   - Set `bucket_force_destroy = true`.
3) `terraform apply`, then `terraform destroy -auto-approve`.

> Versioned buckets can have lots of noncurrent versions. `force_destroy = true` lets Terraform remove them automatically; otherwise, empty the bucket first.

---

## Typical repo workflow snippet

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: actions/checkout@v4

  - name: Configure AWS (OIDC)
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_GHA_ROLE_ARN }}
      aws-region:     ${{ secrets.AWS_REGION }}

  - name: Write backend.hcl
    run: |
      cat > backend.hcl <<'EOF'
      bucket         = "${{ secrets.TFSTATE_BUCKET }}"
      key            = "repos/${{ github.repository_owner }}/${{ github.event.repository.name }}/prod/appX/terraform.tfstate"
      region         = "${{ secrets.AWS_REGION }}"
      dynamodb_table = "${{ secrets.TF_LOCK_TABLE }}"
      encrypt        = true
      EOF

  - uses: hashicorp/setup-terraform@v3

  - name: Terraform init
    run: terraform init -backend-config=backend.hcl -input=false
```

---

## FAQ

**Q: Can I reuse this backend across many repos and environments?**  
Yes. Use a unique **`key`** per stack (e.g., `repos/<org>/<repo>/<env>/<app>/terraform.tfstate`).

**Q: Should I enable KMS?**  
If your org mandates KMS, set `use_kms = true`. Provide `kms_key_arn` to use an existing key, or leave it empty to let the module create one with alias `alias/tfstate`.

**Q: Why `prevent_destroy` on the bucket?**  
To protect shared state from accidental deletion. Temporarily remove it + set `bucket_force_destroy = true` if you must tear down.

**Q: How do I scope actions for my OIDC role?**  
Attach the `backend_access_policy_json` from this module to grant only S3 object access on this bucket + CRUD on the lock table. Add additional policies as needed for your infra.

---

## License / Ownership

- Tags default to `Project=terraform-backend` and `Owner=HarnessPOV`. Adjust as needed.
- Keep this module in a central infra repo; consume its outputs in downstream stacks and GH workflows.
