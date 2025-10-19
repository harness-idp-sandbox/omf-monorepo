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

# --- Check if terraform.tfvars exists, if not create it from template
TFVARS_FILE="${ROOT}/terraform.tfvars"
TFVARS_TEMPLATE="${ROOT}/terraform.tfvars.template"

if [[ ! -f "$TFVARS_FILE" ]]; then
  if [[ -f "$TFVARS_TEMPLATE" ]]; then
    echo -e "${YELLOW}Creating terraform.tfvars from template...${NC}"
    cp "$TFVARS_TEMPLATE" "$TFVARS_FILE"
  else
    echo -e "${YELLOW}Creating default terraform.tfvars...${NC}"
    cat > "$TFVARS_FILE" <<EOF
# terraform.tfvars - Default values for iac-state module
region                = "us-east-1"
bucket_prefix         = "tfstate"
bucket_name_override  = ""
lock_table_name       = "tfstate-locks"
use_kms               = false
kms_key_arn           = ""
state_key_prefix      = "repos/harness-idp-sandbox/harness-monorepo"
noncurrent_version_expiration_days = 30
abort_multipart_days  = 7
bucket_force_destroy  = false
tags = {
  Project = "terraform-backend"
  Owner   = "HarnessPOV"
}
EOF
  fi
  echo -e "${GREEN}✓ Created terraform.tfvars${NC}"
  echo -e "${YELLOW}Please review and edit terraform.tfvars if needed before continuing.${NC}"
  read -p "Press Enter to continue or Ctrl+C to abort..."
fi

# --- Configuration variables with helpful descriptions
echo -e "${BLUE}======= Harness POV Terraform State Bootstrap =======${NC}"
echo -e "${YELLOW}This script will create an S3 bucket and DynamoDB table for Terraform state management.${NC}"
echo ""

# --- Load values from terraform.tfvars
echo -e "${BLUE}Loading configuration from terraform.tfvars...${NC}"

# Read values from terraform.tfvars with defaults
AWS_REGION=$(grep -E '^region\s*=' "$TFVARS_FILE" | sed -E 's/^region\s*=\s*"([^"]+)".*/\1/' || echo "us-east-1")
BUCKET_PREFIX=$(grep -E '^bucket_prefix\s*=' "$TFVARS_FILE" | sed -E 's/^bucket_prefix\s*=\s*"([^"]+)".*/\1/' || echo "tfstate")
LOCK_TABLE=$(grep -E '^lock_table_name\s*=' "$TFVARS_FILE" | sed -E 's/^lock_table_name\s*=\s*"([^"]+)".*/\1/' || echo "tfstate-locks")
USE_KMS=$(grep -E '^use_kms\s*=' "$TFVARS_FILE" | sed -E 's/^use_kms\s*=\s*([a-zA-Z0-9_]+).*/\1/' || echo "false")
PROJECT_TAG=$(grep -E 'Project\s*=' "$TFVARS_FILE" | sed -E 's/.*Project\s*=\s*"([^"]+)".*/\1/' || echo "terraform-backend")
OWNER_TAG=$(grep -E 'Owner\s*=' "$TFVARS_FILE" | sed -E 's/.*Owner\s*=\s*"([^"]+)".*/\1/' || echo "HarnessPOV")

# Allow overrides via command line
read -p "$(echo -e "${BLUE}AWS Region [default: $AWS_REGION]: ${NC}")" AWS_REGION_OVERRIDE
AWS_REGION=${AWS_REGION_OVERRIDE:-$AWS_REGION}

read -p "$(echo -e "${BLUE}Use KMS encryption? (true/false) [default: $USE_KMS]: ${NC}")" USE_KMS_OVERRIDE
USE_KMS=${USE_KMS_OVERRIDE:-$USE_KMS}

read -p "$(echo -e "${BLUE}State key prefix override (leave empty for default): ${NC}")" STATE_KEY_PREFIX_OVERRIDE

read -p "$(echo -e "${BLUE}S3 bucket name prefix [default: $BUCKET_PREFIX]: ${NC}")" BUCKET_PREFIX_OVERRIDE
BUCKET_PREFIX=${BUCKET_PREFIX_OVERRIDE:-$BUCKET_PREFIX}

read -p "$(echo -e "${BLUE}DynamoDB lock table name [default: $LOCK_TABLE]: ${NC}")" LOCK_TABLE_OVERRIDE
LOCK_TABLE=${LOCK_TABLE_OVERRIDE:-$LOCK_TABLE}

read -p "$(echo -e "${BLUE}Project tag [default: $PROJECT_TAG]: ${NC}")" PROJECT_TAG_OVERRIDE
PROJECT_TAG=${PROJECT_TAG_OVERRIDE:-$PROJECT_TAG}

read -p "$(echo -e "${BLUE}Owner tag [default: $OWNER_TAG]: ${NC}")" OWNER_TAG_OVERRIDE
OWNER_TAG=${OWNER_TAG_OVERRIDE:-$OWNER_TAG}

echo ""
echo -e "${YELLOW}Configuration Summary:${NC}"
echo -e "  ${BLUE}AWS Region:${NC} $AWS_REGION"
echo -e "  ${BLUE}Use KMS:${NC} $USE_KMS"
echo -e "  ${BLUE}State Key Prefix:${NC} ${STATE_KEY_PREFIX_OVERRIDE:-<default>}"
echo -e "  ${BLUE}Bucket Prefix:${NC} $BUCKET_PREFIX"
echo -e "  ${BLUE}DynamoDB Table:${NC} $LOCK_TABLE"
echo -e "  ${BLUE}Project Tag:${NC} $PROJECT_TAG"
echo -e "  ${BLUE}Owner Tag:${NC} $OWNER_TAG"
echo ""

# --- Confirm before proceeding
read -p "$(echo -e "${YELLOW}Proceed with these settings? (y/n): ${NC}")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo -e "${RED}Operation cancelled.${NC}"
  exit 0
fi

echo ""
echo -e "${BLUE}Checking AWS credentials...${NC}"

# --- Verify AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}Error: AWS credentials not found or invalid.${NC}"
  echo -e "${YELLOW}Please configure your AWS credentials and try again.${NC}"
  echo -e "${YELLOW}You can use 'aws configure' or set the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.${NC}"
  exit 1
fi

# --- Check if Terraform is installed
if ! command -v terraform &>/dev/null; then
  echo -e "${RED}Error: Terraform not found.${NC}"
  echo -e "${YELLOW}Please install Terraform and try again.${NC}"
  exit 1
fi

# --- Create terraform directory if it doesn't exist
mkdir -p "${TF_DIR}"

# --- Create terraform directory if it doesn't exist
mkdir -p "${TF_DIR}"

# --- Apply Terraform configuration
pushd "${TF_DIR}" >/dev/null
  # Initialize Terraform
  echo -e "${BLUE}Initializing Terraform...${NC}"
  terraform init

  # Apply Terraform configuration
  echo -e "${BLUE}Applying Terraform configuration...${NC}"
  terraform apply \
    -var "region=${AWS_REGION}" \
    -var "bucket_prefix=${BUCKET_PREFIX}" \
    -var "lock_table_name=${LOCK_TABLE}" \
    -var "use_kms=${USE_KMS}" \
    ${STATE_KEY_PREFIX_OVERRIDE:+-var "state_key_prefix=${STATE_KEY_PREFIX_OVERRIDE}"} \
    -var "tags={Project=\"${PROJECT_TAG}\",Owner=\"${OWNER_TAG}\"}" \
    -auto-approve

  # Output the backend configuration
  echo -e "${BLUE}Retrieving backend configuration...${NC}"
  BUCKET_NAME=$(terraform output -raw bucket_name)
  DYNAMODB_TABLE=$(terraform output -raw dynamodb_table)
  REGION=$(terraform output -raw region)
popd >/dev/null

# --- Generate backend.hcl example
cat > "${ROOT}/backend.hcl.example" <<EOF
bucket         = "${BUCKET_NAME}"
key            = "repos/ORGANIZATION/REPOSITORY/ENVIRONMENT/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${DYNAMODB_TABLE}"
encrypt        = true
EOF

# --- Generate GitHub Actions secrets example
cat > "${ROOT}/github-actions-secrets.example" <<EOF
TFSTATE_BUCKET=${BUCKET_NAME}
TF_LOCK_TABLE=${DYNAMODB_TABLE}
AWS_REGION=${REGION}
EOF

echo -e "${GREEN}✓ Terraform state infrastructure successfully created!${NC}"
echo ""
echo -e "${BLUE}Backend Configuration:${NC}"
echo -e "  ${YELLOW}S3 Bucket:${NC} ${BUCKET_NAME}"
echo -e "  ${YELLOW}DynamoDB Table:${NC} ${DYNAMODB_TABLE}"
echo -e "  ${YELLOW}Region:${NC} ${REGION}"
echo ""
echo -e "${BLUE}Example backend.hcl has been generated at:${NC} ${ROOT}/backend.hcl.example"
echo -e "${BLUE}Example GitHub Actions secrets have been generated at:${NC} ${ROOT}/github-actions-secrets.example"
echo ""
echo -e "${YELLOW}To use this backend in your Terraform configurations:${NC}"
echo -e "  1. Copy the backend.hcl.example to your project"
echo -e "  2. Update the 'key' parameter with your specific path"
echo -e "  3. Initialize Terraform with: terraform init -backend-config=backend.hcl"
echo ""
echo -e "${YELLOW}For GitHub Actions:${NC}"
echo -e "  1. Add the secrets from github-actions-secrets.example to your repository"
echo -e "  2. Configure your workflow to use these secrets for backend configuration"