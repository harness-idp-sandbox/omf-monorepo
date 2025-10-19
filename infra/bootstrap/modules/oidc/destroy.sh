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

CONFIRM="${1:-}"
if [[ "$CONFIRM" != "--yes" ]]; then
  echo -e "${YELLOW}⚠️  This will destroy the OIDC role/policies.${NC}"
  read -r -p "$(echo -e "${BLUE}Type 'destroy' to continue:${NC} ")" ans
  [[ "$ans" == "destroy" ]] || { echo -e "${RED}Aborted.${NC}"; exit 2; }
fi

# --- Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo -e "${RED}❌ No valid AWS credentials. Run 'aws sso login' and set AWS_PROFILE, or export keys.${NC}"
  exit 1
fi

# --- Check if terraform.tfvars exists
TFVARS_FILE="${ROOT}/terraform.tfvars"
if [[ ! -f "$TFVARS_FILE" ]]; then
  echo -e "${RED}Error: terraform.tfvars not found.${NC}"
  exit 1
fi

echo -e "${BLUE}Destroying OIDC configuration...${NC}"
pushd "${TF_DIR}" >/dev/null
  terraform destroy -var-file="${TFVARS_FILE}" -auto-approve
popd >/dev/null

echo -e "${GREEN}✓ OIDC configuration destroyed.${NC}"