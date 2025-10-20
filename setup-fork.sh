#!/bin/bash
set -euo pipefail

# --- Validate input ---
if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "❌ Usage: $0 <CUSTOMER_NAME>"
  echo "Example: $0 omf"
  exit 1
fi

CUSTOMER_NAME="$1"

# --- Define repository and org values ---
OLD_REPO="harness-monorepo"
NEW_REPO="${CUSTOMER_NAME}-monorepo"
OLD_ORG="harness-idp-sandbox"
NEW_ORG="harness-idp-sandbox"

# --- Detect OS for sed compatibility ---
SED_CMD="sed -i"
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires a backup suffix (even if empty)
  SED_CMD="sed -i ''"
fi

# --- Function to replace text in files ---
replace_in_files() {
  local old="$1"
  local new="$2"
  echo "Replacing '$old' → '$new'..."
  # Skip this script and binary files
  find . -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -name "$(basename "$0")" \
    -exec grep -Il "$old" {} \; | while read -r file; do
      eval "$SED_CMD 's|$old|$new|g' \"$file\""
    done
}

# --- Replace repository name in all files ---
echo "Replacing repository name in files..."
replace_in_files "$OLD_REPO" "$NEW_REPO"

# --- Replace organization name if needed ---
if [ "$OLD_ORG" != "$NEW_ORG" ]; then
  echo "Replacing organization name in files..."
  replace_in_files "$OLD_ORG" "$NEW_ORG"
fi

# --- Update specific Terraform variable files ---
echo "Updating Terraform variable files..."
if [ -f "infra/bootstrap/modules/iac-state/terraform.tfvars" ]; then
  eval "$SED_CMD 's|state_key_prefix = .*|state_key_prefix = \"repos/$NEW_ORG/$NEW_REPO\"|' infra/bootstrap/modules/iac-state/terraform.tfvars"
fi

if [ -f "infra/bootstrap/terraform.tfvars" ]; then
  eval "$SED_CMD 's|github_repo = .*|github_repo = \"$NEW_REPO\"|' infra/bootstrap/terraform.tfvars"
fi

echo "✅ Replacement complete for customer: $CUSTOMER_NAME"
