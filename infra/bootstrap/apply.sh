#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======= Monorepo Bootstrap =======${NC}"
echo -e "${YELLOW}This script will bootstrap the infrastructure for your monorepo.${NC}"
echo ""

# Step 1: Set up Terraform state backend
echo -e "${BLUE}Step 1: Setting up Terraform state backend...${NC}"
pushd "${ROOT}/modules/iac-state" >/dev/null
  ./apply.sh
popd >/dev/null

# Step 2: Set up OIDC authentication
echo -e "${BLUE}Step 2: Setting up OIDC authentication...${NC}"
pushd "${ROOT}/modules/oidc" >/dev/null
  ./apply.sh
popd >/dev/null

echo -e "${GREEN}✓ Bootstrap complete!${NC}"
echo -e "${YELLOW}Please check the generated files for GitHub Actions secrets and backend configuration.${NC}"