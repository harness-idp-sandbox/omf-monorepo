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

# --- Check if terraform.tfvars exists
TFVARS_FILE="${ROOT}/terraform.tfvars"
if [[ ! -f "$TFVARS_FILE" ]]; then
  echo -e "${RED}Error: terraform.tfvars not found.${NC}"
  exit 1
fi

# --- Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo -e "${RED}❌ No valid AWS credentials. Run 'aws sso login' and set AWS_PROFILE, or export keys.${NC}"
  exit 1
fi

# --- Load values from terraform.tfvars
echo -e "${BLUE}Loading configuration from terraform.tfvars...${NC}"

# Read common values from terraform.tfvars
GITHUB_ORG=$(grep -E '^github_org\s*=' "$TFVARS_FILE" | sed -E 's/^github_org\s*=\s*"([^"]+)".*/\1/' || echo "")
GITHUB_REPO=$(grep -E '^github_repo\s*=' "$TFVARS_FILE" | sed -E 's/^github_repo\s*=\s*"([^"]+)".*/\1/' || echo "")
ROLE_NAME=$(grep -E '^role_name\s*=' "$TFVARS_FILE" | sed -E 's/^role_name\s*=\s*"([^"]+)".*/\1/' || echo "gha-oidc-role")
AWS_REGION=$(grep -E '^region\s*=' "$TFVARS_FILE" | sed -E 's/^region\s*=\s*"([^"]+)".*/\1/' || echo "us-east-1")

# Allow overrides via command line
read -p "$(echo -e "${BLUE}GitHub Organization [default: $GITHUB_ORG]: ${NC}")" GITHUB_ORG_OVERRIDE
GITHUB_ORG=${GITHUB_ORG_OVERRIDE:-$GITHUB_ORG}

read -p "$(echo -e "${BLUE}GitHub Repository (empty for any repo in org) [default: $GITHUB_REPO]: ${NC}")" GITHUB_REPO_OVERRIDE
GITHUB_REPO=${GITHUB_REPO_OVERRIDE:-$GITHUB_REPO}

read -p "$(echo -e "${BLUE}Role name [default: $ROLE_NAME]: ${NC}")" ROLE_NAME_OVERRIDE
ROLE_NAME=${ROLE_NAME_OVERRIDE:-$ROLE_NAME}

# --- Apply Terraform configuration
echo -e "${BLUE}Applying Terraform configuration...${NC}"
pushd "${TF_DIR}" >/dev/null
  terraform init
  terraform apply -var-file="${TFVARS_FILE}"
  
  # Get outputs
  OIDC_ARN=$(terraform output -raw oidc_provider_arn)
  ROLE_ARN=$(terraform output -raw role_arn)
popd >/dev/null

# Write environment file for GitHub Actions
cat > "${ROOT}/oidc.env" <<EOF
# GitHub Actions OIDC Configuration
AWS_GHA_ROLE_ARN=${ROLE_ARN}
AWS_OIDC_PROVIDER_ARN=${OIDC_ARN}
EOF

echo -e "${GREEN}✔ OIDC bootstrap complete.${NC}"
echo -e "  ${YELLOW}OIDC provider ARN:${NC} ${OIDC_ARN}"
echo -e "  ${YELLOW}Role ARN:${NC}          ${ROLE_ARN}"
echo
echo -e "${BLUE}Wrote: ${ROOT}/oidc.env  (copy AWS_GHA_ROLE_ARN into repo/org secrets)${NC}"