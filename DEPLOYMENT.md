# Azure Deployment Guide for TaskTracker

This guide explains how to set up and use the CI/CD pipeline for deploying TaskTracker to your existing Azure resources.

## Overview

The CI/CD pipeline deploys to three existing environments:
- **Dev**: Resource group `rg-wcdev` (triggered by pushes to `develop` branch)
- **Staging**: Resource group `rg-wcstaging` (triggered by pushes to `staging` branch)
- **Production**: Resource group `rg-wcproduction` (triggered by pushes to `main` branch)

## Architecture

- **Subscription**: `a4ab3025-1b32-4394-92e0-d07c1ebf3787`
- **Backend**: FastAPI (Python) - deployed to Container Apps
- **Frontend**: React - deployed to Container Apps
- **Container Registry**: Azure Container Registry (ACR) in each resource group
- **Authentication**: OIDC (OpenID Connect) federated credentials

## Prerequisites

Before setting up the pipeline, ensure you have:

1. **Azure Resources**: Container Apps and Container Registry must exist in each resource group
2. **Azure CLI**: Installed locally for initial setup
3. **GitHub CLI**: Installed for setting up secrets
4. **Permissions**: 
   - Contributor role on the Azure subscription
   - User Access Administrator role (for role assignments)

## Initial Setup

### Step 1: Create Service Principal with Federated Credentials

Run these commands to create a service principal for GitHub Actions authentication:

```bash
# Login to Azure
az login
az account set --subscription a4ab3025-1b32-4394-92e0-d07c1ebf3787

# Get subscription details
SUBSCRIPTION_ID="a4ab3025-1b32-4394-92e0-d07c1ebf3787"
GITHUB_ORG="wchigit"
GITHUB_REPO="TaskTracker"

# Create service principal
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "github-actions-tasktracker" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth)

# Extract values
CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.clientId')
TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenantId')

echo "Client ID: $CLIENT_ID"
echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
```

### Step 2: Grant User Access Administrator Role

```bash
az role assignment create \
  --role "User Access Administrator" \
  --assignee $CLIENT_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

### Step 3: Create Federated Credentials for Each Environment

Create federated credentials for dev, staging, and production environments:

```bash
# Get App ID
APP_ID=$(az ad sp show --id $CLIENT_ID --query appId -o tsv)

# Create federated credential for dev environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-federated-dev\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:environment:dev\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Create federated credential for staging environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-federated-staging\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:environment:staging\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Create federated credential for production environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-federated-production\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:environment:production\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

### Step 4: Create GitHub Environments and Secrets

Create the three environments and add secrets to each:

```bash
# Create environments
gh api --method PUT -H "Accept: application/vnd.github+json" \
  repos/$GITHUB_ORG/$GITHUB_REPO/environments/dev

gh api --method PUT -H "Accept: application/vnd.github+json" \
  repos/$GITHUB_ORG/$GITHUB_REPO/environments/staging

gh api --method PUT -H "Accept: application/vnd.github+json" \
  repos/$GITHUB_ORG/$GITHUB_REPO/environments/production

# Add secrets to dev environment
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --env dev
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --env dev
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --env dev

# Add secrets to staging environment
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --env staging
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --env staging
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --env staging

# Add secrets to production environment
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --env production
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --env production
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --env production
```

Alternatively, you can add secrets manually via GitHub UI:
1. Go to repository Settings → Environments
2. For each environment (dev, staging, production):
   - Click on the environment name
   - Add the following secrets:
     - `AZURE_CLIENT_ID`: The client ID from Step 1
     - `AZURE_TENANT_ID`: The tenant ID from Step 1
     - `AZURE_SUBSCRIPTION_ID`: `a4ab3025-1b32-4394-92e0-d07c1ebf3787`

### Step 5: Verify Azure Resources

Ensure the following resources exist in each resource group:

**For rg-wcdev:**
- Azure Container Registry (ACR)
- Container App for backend
- Container App for frontend

**For rg-wcstaging:**
- Azure Container Registry (ACR)
- Container App for backend
- Container App for frontend

**For rg-wcproduction:**
- Azure Container Registry (ACR)
- Container App for backend
- Container App for frontend

You can verify with:
```bash
# Check dev resources
az containerapp list --resource-group rg-wcdev --output table
az acr list --resource-group rg-wcdev --output table

# Check staging resources
az containerapp list --resource-group rg-wcstaging --output table
az acr list --resource-group rg-wcstaging --output table

# Check production resources
az containerapp list --resource-group rg-wcproduction --output table
az acr list --resource-group rg-wcproduction --output table
```

## Deployment Workflow

### Automatic Deployments

The pipeline automatically triggers based on branch:

- **Dev Environment**: Pushes to `develop` branch → deploys to `rg-wcdev`
- **Staging Environment**: Pushes to `staging` branch → deploys to `rg-wcstaging`
- **Production Environment**: Pushes to `main` branch → deploys to `rg-wcproduction`

### Manual Deployments

You can manually trigger deployments from GitHub Actions:

1. Go to repository → Actions tab
2. Select "Deploy to Azure" workflow
3. Click "Run workflow"
4. Choose the target environment (dev/staging/production)
5. Click "Run workflow"

## Pipeline Steps

The workflow consists of these stages:

### 1. Build Stage
- Builds backend Docker image
- Builds frontend Docker image
- Uploads images as artifacts (for deployment reuse)

### 2. Deploy Stage (per environment)
- Downloads built Docker images
- Authenticates to Azure using OIDC
- Discovers Azure Container Registry in the resource group
- Logs into ACR
- Tags and pushes images with commit SHA and environment-specific tags
- Discovers Container Apps in the resource group
- Updates Container Apps with new images
- Displays deployment URLs in workflow summary

## Branching Strategy

Recommended Git workflow:

```
develop → staging → main
  ↓         ↓        ↓
 dev    staging  production
```

1. **Feature Development**: Create feature branches from `develop`
2. **Dev Deployment**: Merge to `develop` → auto-deploys to dev
3. **Staging Deployment**: Merge `develop` to `staging` → auto-deploys to staging
4. **Production Deployment**: Merge `staging` to `main` → auto-deploys to production

## Image Tagging Strategy

Images are tagged with:
- Commit SHA: `tasktracker-backend:abc1234` (immutable, per deployment)
- Environment-specific latest: 
  - Dev: `tasktracker-backend:latest`
  - Staging: `tasktracker-backend:staging-latest`
  - Production: `tasktracker-backend:production-latest`

## Monitoring Deployments

### View Workflow Status

```bash
# List recent workflow runs
gh run list --workflow=azure-deploy.yml

# View specific run details
gh run view <run-id>

# Watch a running workflow
gh run watch <run-id>
```

### View Application Logs

After deployment, view Container App logs in Azure Portal:

1. Go to Azure Portal → Container Apps
2. Select the backend or frontend app
3. Navigate to "Log stream" or "Logs" section

## Rollback

To rollback to a previous version:

1. Find the commit SHA of the working version
2. Manually trigger the workflow for that commit:
   ```bash
   # Checkout the working commit
   git checkout <working-commit-sha>
   
   # Push to the environment branch
   git push origin HEAD:develop --force  # for dev
   git push origin HEAD:staging --force  # for staging
   git push origin HEAD:main --force     # for production
   ```

Or update Container App to use a previous image:
```bash
# Example for dev backend
az containerapp update \
  --name <backend-app-name> \
  --resource-group rg-wcdev \
  --image <acr-name>.azurecr.io/tasktracker-backend:<previous-sha>
```

## Troubleshooting

### Pipeline Fails at Azure Login
- Verify GitHub secrets are correctly set in each environment
- Check federated credentials exist for all three environments
- Ensure service principal has correct permissions

### ACR Not Found
- Verify Azure Container Registry exists in the resource group
- Check service principal has access to the resource group
- Ensure ACR name is correct

### Container App Not Found
- Verify Container Apps exist in the resource group
- Check that app names contain "backend" or "frontend" keywords
- Ensure service principal has access to Container Apps

### Image Push Fails
- Check ACR admin user is enabled OR managed identity has AcrPush role
- Verify network access to ACR
- Check ACR storage quota

### Container App Update Fails
- Verify the Container App exists
- Check image name and tag are correct
- Ensure service principal has permissions
- Review Container App logs for startup errors

## Security Best Practices

1. **OIDC Authentication**: Uses federated credentials (no secrets stored)
2. **Least Privilege**: Service principal has only required permissions
3. **Environment Isolation**: Each environment has separate resources and secrets
4. **Image Scanning**: Consider adding Azure Container Registry image scanning
5. **Network Security**: Use private endpoints if needed

## Cost Optimization

- Container Apps scale to zero when idle (Consumption plan)
- Docker layer caching reduces build times
- Artifacts retained for only 1 day

## Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [GitHub Actions with Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)
