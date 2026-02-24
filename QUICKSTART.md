# Quick Setup Guide

## Automated Setup (Recommended)

Run the automated setup script:

```bash
./scripts/setup-azure-cicd.sh
```

This script will:
- Verify all Azure resources exist
- Create service principal with federated credentials
- Configure GitHub environments (dev, staging, production)
- Set up all required secrets

## Manual Deployment Trigger

After setup, trigger deployments via:

**Option 1: Push to branches**
- `develop` → deploys to dev environment
- `staging` → deploys to staging environment  
- `main` → deploys to production environment

**Option 2: GitHub Actions UI**
1. Go to Actions tab
2. Select "Deploy to Azure"
3. Click "Run workflow"
4. Choose environment

## Resource Mapping

| Environment | Branch | Resource Group | 
|------------|--------|----------------|
| Dev | `develop` | `rg-wcdev` |
| Staging | `staging` | `rg-wcstaging` |
| Production | `main` | `rg-wcproduction` |

## Required Azure Resources (Per Environment)

Each resource group needs:
- ✅ Azure Container Registry (ACR)
- ✅ Container App (backend - must contain "backend" in name)
- ✅ Container App (frontend - must contain "frontend" in name)

## GitHub Secrets (Per Environment)

Each environment (dev/staging/production) needs:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Workflow Features

- ✅ Multi-environment deployment (dev, staging, production)
- ✅ Docker build caching for faster builds
- ✅ OIDC authentication (no stored secrets)
- ✅ Automatic resource discovery
- ✅ Commit SHA-based image tagging
- ✅ Deployment URL reporting

## Quick Commands

```bash
# View workflow runs
gh run list --workflow=azure-deploy.yml

# Watch active run
gh run watch

# View Container Apps
az containerapp list --resource-group rg-wcdev --output table

# View Container Registry
az acr list --resource-group rg-wcdev --output table
```

## Troubleshooting

If deployment fails:
1. Check GitHub Actions logs
2. Verify all Azure resources exist
3. Ensure secrets are set correctly
4. Check service principal permissions

For detailed information, see [DEPLOYMENT.md](./DEPLOYMENT.md)
