# Pipeline Setup Guide

This guide will help you set up the CI/CD pipeline for deploying TaskTracker to Azure Container Apps using GitHub Actions.

## Overview

The pipeline includes:
- **Build stage**: Builds Docker images for frontend and backend
- **Deploy stages**: Deploys to dev, staging, and production environments
- **Authentication**: Uses User-assigned Managed Identity with OIDC
- **Multi-environment**: Separate deployments for dev, staging, and production

## Prerequisites

Before running the setup scripts, ensure you have:
1. Azure CLI installed and logged in
2. GitHub CLI installed and authenticated
3. Appropriate permissions in Azure subscription
4. Container Apps and Azure Container Registry already created in your resource groups

## Setup Steps

### 1. Configure Azure Authentication

Run the Azure authentication setup script:

**PowerShell:**
```powershell
.\scripts\setup-azure-auth-for-pipeline.ps1 -DevAcrName "your-dev-acr" -StagingAcrName "your-staging-acr" -ProductionAcrName "your-prod-acr"
```

This script will:
- Create a User-assigned Managed Identity for the pipeline
- Configure federated credentials for GitHub Actions
- Set up RBAC permissions for resource groups and all three ACRs

### 2. Configure Pipeline Environment

Run the pipeline environment setup script:

**PowerShell:**
```powershell
.\scripts\setup-pipeline-environment.ps1 -ClientId "from-auth-script" -TenantId "from-auth-script"
```

This script will:
- Create GitHub environments (dev, staging, production)
- Set up environment variables and secrets for each environment's ACR
- Configure environment protection rules
- Uses your specific ACR names and container app names (`frontend` and `backend` in each environment)

## Required Information

You'll need to provide the following information when running the setup scripts:

### Azure Resources (Pre-configured)
- **Resource Groups**: 
  - Dev: `rg-wcdev`
  - Staging: `rg-wcstaging` 
  - Production: `rg-wcproduction`
- **Container App Names**: `frontend` and `backend` in each environment
- **Azure Container Registry Names**: 
  - Dev: `acryqsta6dud5vi2`
  - Staging: `acroyid6zftjzu46`
  - Production: `acr6ia22terduzqo`

### GitHub Repository
- **Repository Owner**: `wchigit`
- **Repository Name**: `TaskTracker`

## Pipeline Behavior

- **Develop branch**: Deploys to dev environment only
- **Main branch**: Deploys to staging first, then production (with approval)
- **Pull requests**: Only builds (no deployment)

## Environment Protection

- **Dev**: No protection rules (automatic deployment)
- **Staging**: Optional - can add reviewers if needed
- **Production**: Requires manual approval before deployment

## Next Steps

After running both setup scripts:
1. Verify the User-assigned Managed Identity has correct permissions
2. Test the pipeline by pushing to the develop branch
3. Check that images are being pushed to ACR correctly
4. Verify deployments are working in each environment