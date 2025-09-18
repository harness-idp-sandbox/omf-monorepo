#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${ROOT}/terraform"

: "${AWS_REGION:=us-east-1}"
: "${USE_KMS:=false}"

pushd "${TF_DIR}" >/dev/null
  terraform init
  terraform apply -auto-approve \
    -var "region=${AWS_REGION}" \
    -var "use_kms=${USE_KMS}"
  BUCKET=$(terraform output -raw bucket)
  TABLE=$(terraform output -raw dynamodb_table)
  REGION=$(terraform output -raw region)
  BACKEND_EXAMPLE=$(terraform output -raw backend_hcl_example)
popd >/dev/null

# Write a reusable template next to bootstrap/state/
cat > "${ROOT}/backend.hcl.tpl" <<EOF
${BACKEND_EXAMPLE}
EOF

# Convenience .env (handy for GH Actions repo secrets)
cat > "${ROOT}/backend.env" <<EOF
TFSTATE_BUCKET=${BUCKET}
TF_LOCK_TABLE=${TABLE}
AWS_REGION=${REGION}
EOF

echo
echo "✔ Remote state bootstrap complete."
echo "  S3 bucket:        ${BUCKET}"
echo "  DynamoDB table:   ${TABLE}"
echo "  Region:           ${REGION}"
echo
echo "Wrote:"
echo "  - ${ROOT}/backend.hcl.tpl   (replace <project_slug> per app)"
echo "  - ${ROOT}/backend.env       (values you can copy into GH repo secrets)"
