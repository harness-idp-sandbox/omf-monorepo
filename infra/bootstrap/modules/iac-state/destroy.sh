#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${ROOT}/terraform"

# --- Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Helper function to derive GitHub slug from git remote
derive_slug() {
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    local remote_url
    remote_url=$(git config --get remote.origin.url || echo "")
    if [[ $remote_url =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
      echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
  fi
}

# --- Check if terraform.tfvars exists
TFVARS_FILE="${ROOT}/terraform.tfvars"
if [[ ! -f "$TFVARS_FILE" ]]; then
  echo -e "${RED}Error: terraform.tfvars not found.${NC}"
  exit 1
fi

# --- Configuration variables with helpful descriptions
echo -e "${BLUE}======= Harness POV Terraform State Bootstrap =======${NC}"
echo -e "${YELLOW}This script will destroy the S3 bucket and DynamoDB table for Terraform state management.${NC}"
echo ""

# --- Load values from terraform.tfvars
echo -e "${BLUE}Loading configuration from terraform.tfvars...${NC}"

# Read values from terraform.tfvars with defaults
AWS_REGION=$(grep -E '^region\s*=' "$TFVARS_FILE" | sed -E 's/^region\s*=\s*"([^"]+)".*/\1/' || echo "us-east-1")
BUCKET_PREFIX=$(grep -E '^bucket_prefix\s*=' "$TFVARS_FILE" | sed -E 's/^bucket_prefix\s*=\s*"([^"]+)".*/\1/' || echo "tfstate")
LOCK_TABLE=$(grep -E '^lock_table_name\s*=' "$TFVARS_FILE" | sed -E 's/^lock_table_name\s*=\s*"([^"]+)".*/\1/' || echo "tfstate-locks")
echo ""
echo -e "${YELLOW}Destroying Terraform state infrastructure...${NC}"
echo ""

# --- Destroy Terraform state infrastructure
terraform destroy \
  -var "region=$AWS_REGION" \
  -var "bucket_prefix=$BUCKET_PREFIX" \
  -var "lock_table_name=$LOCK_TABLE" \
  -auto-approve

echo -e "${GREEN}✓ Destroyed Terraform state infrastructure${NC}"
echo -e "${YELLOW}Please review and edit terraform.tfvars if needed before continuing.${NC}"
echo -e "${YELLOW}If you want to recreate the infrastructure, run apply.sh.${NC}"