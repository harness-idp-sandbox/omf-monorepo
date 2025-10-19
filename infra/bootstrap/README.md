# Monorepo Bootstrap

This directory contains infrastructure modules that should be run **once** when setting up a new monorepo with Harness IDP.

## Overview

The bootstrap process sets up foundational infrastructure required for:
- Terraform state management (S3 bucket + DynamoDB table)
- GitHub Actions OIDC authentication with cloud providers
- Required IAM roles and permissions

## Included Modules

- **`modules/iac-state`**: Creates S3 bucket and DynamoDB table for Terraform state management
- **`modules/oidc`**: Sets up GitHub Actions OIDC provider and IAM roles for secure cloud access

## Bootstrap Process

1. **Setup Terraform State Backend**:
    ```bash
    cd modules/iac-state
    ./apply.sh
    ```
    This creates the S3 bucket and DynamoDB table for state management.

2. **Setup OIDC Authentication:**
    ```bash
    cd modules/oidc
    ./apply.sh
    ```
    This creates the IAM role for GitHub Actions to assume via OIDC.

3. **Configure GitHub Secrets:** Add the generated secrets from github-actions-secrets.example to your repository.

**Next Steps**
After bootstrap is complete, you can begin using the IDP provisioning pipeline to scaffold new applications into the monorepo.
For detailed module documentation:
- [IAC State Module](./modules/iac-state/README.md)
- [OIDC Module](./modules/oidc/README.md)

