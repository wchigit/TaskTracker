# TaskTracker CI/CD Setup Guide

This guide will help you set up authentication and GitHub environments for the TaskTracker CI/CD pipeline.

## Prerequisites

- Azure CLI installed and logged in
- GitHub CLI installed and authenticated
- Owner or Admin access to the GitHub repository
- Contributor access to Azure subscription

## Step 1: Create Azure Resources

### 1.1 Create Resource Groups for Each Environment

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource groups
az group create --name "rg-tasktracker-dev" --location "East US"
az group create --name "rg-tasktracker-staging" --location "East US"
az group create --name "rg-tasktracker-prod" --location "East US"
```

### 1.2 Create Azure Container Registry

```bash
# Create ACR (shared across environments)
az acr create --resource-group "rg-tasktracker-dev" --name "acrtasktracker" --sku Basic

# Enable admin user for ACR
az acr update --name "acrtasktracker" --admin-enabled true

# Get ACR credentials
az acr credential show --name "acrtasktracker"
```

### 1.3 Create App Services for Staging and Production

```bash
# Create App Service Plans
az appservice plan create --name "asp-tasktracker-staging" --resource-group "rg-tasktracker-staging" --sku B1 --is-linux
az appservice plan create --name "asp-tasktracker-prod" --resource-group "rg-tasktracker-prod" --sku S1 --is-linux

# Create Web Apps
az webapp create --resource-group "rg-tasktracker-staging" --plan "asp-tasktracker-staging" --name "tasktracker-staging-$(date +%s)" --deployment-container-image-name nginx
az webapp create --resource-group "rg-tasktracker-prod" --plan "asp-tasktracker-prod" --name "tasktracker-prod-$(date +%s)" --deployment-container-image-name nginx
```

### 1.4 Create MongoDB Resources

```bash
# Create Cosmos DB with MongoDB API for each environment
az cosmosdb create --name "cosmos-tasktracker-dev" --resource-group "rg-tasktracker-dev" --kind MongoDB
az cosmosdb create --name "cosmos-tasktracker-staging" --resource-group "rg-tasktracker-staging" --kind MongoDB
az cosmosdb create --name "cosmos-tasktracker-prod" --resource-group "rg-tasktracker-prod" --kind MongoDB

# Get connection strings
az cosmosdb keys list --name "cosmos-tasktracker-dev" --resource-group "rg-tasktracker-dev" --type connection-strings
az cosmosdb keys list --name "cosmos-tasktracker-staging" --resource-group "rg-tasktracker-staging" --type connection-strings
az cosmosdb keys list --name "cosmos-tasktracker-prod" --resource-group "rg-tasktracker-prod" --type connection-strings
```

## Step 2: Set Up Managed Identity and Federated Credentials

### 2.1 Create Managed Identity

```bash
# Create User Assigned Managed Identity
az identity create --resource-group "rg-tasktracker-dev" --name "mi-tasktracker-github"

# Get the identity details
CLIENT_ID=$(az identity show --resource-group "rg-tasktracker-dev" --name "mi-tasktracker-github" --query clientId --output tsv)
OBJECT_ID=$(az identity show --resource-group "rg-tasktracker-dev" --name "mi-tasktracker-github" --query principalId --output tsv)
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

echo "CLIENT_ID: $CLIENT_ID"
echo "OBJECT_ID: $OBJECT_ID"
echo "SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"
```

### 2.2 Assign Roles to Managed Identity

```bash
# Assign Contributor role for each resource group
az role assignment create --assignee $OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tasktracker-dev"
az role assignment create --assignee $OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tasktracker-staging"
az role assignment create --assignee $OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tasktracker-prod"

# Assign ACR push/pull role
ACR_ID=$(az acr show --name "acrtasktracker" --query id --output tsv)
az role assignment create --assignee $OBJECT_ID --role "AcrPush" --scope $ACR_ID
```

### 2.3 Create Federated Credentials

```bash
# Get your GitHub repository details
GITHUB_OWNER="YOUR_GITHUB_USERNAME"
GITHUB_REPO="TaskTracker"

# Create federated credential for main branch
az identity federated-credential create \
  --name "fc-tasktracker-main" \
  --identity-name "mi-tasktracker-github" \
  --resource-group "rg-tasktracker-dev" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:$GITHUB_OWNER/$GITHUB_REPO:ref:refs/heads/main" \
  --audience "api://AzureADTokenExchange"

# Create federated credential for develop branch
az identity federated-credential create \
  --name "fc-tasktracker-develop" \
  --identity-name "mi-tasktracker-github" \
  --resource-group "rg-tasktracker-dev" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:$GITHUB_OWNER/$GITHUB_REPO:ref:refs/heads/develop" \
  --audience "api://AzureADTokenExchange"

# Create federated credential for pull requests
az identity federated-credential create \
  --name "fc-tasktracker-pr" \
  --identity-name "mi-tasktracker-github" \
  --resource-group "rg-tasktracker-dev" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:$GITHUB_OWNER/$GITHUB_REPO:pull_request" \
  --audience "api://AzureADTokenExchange"
```

## Step 3: Set Up GitHub Environments and Secrets

### 3.1 Create GitHub Environments

```bash
# Navigate to your repository directory
cd /path/to/your/TaskTracker/repo

# Create environments
gh api --method PUT repos/:owner/:repo/environments/development
gh api --method PUT repos/:owner/:repo/environments/staging
gh api --method PUT repos/:owner/:repo/environments/production
```

### 3.2 Set Repository Secrets

```bash
# Set global repository secrets
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"

# Set ACR secrets
ACR_USERNAME=$(az acr credential show --name "acrtasktracker" --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name "acrtasktracker" --query passwords[0].value --output tsv)

gh secret set ACR_NAME --body "acrtasktracker"
gh secret set ACR_REGISTRY --body "acrtasktracker.azurecr.io"
gh secret set ACR_USERNAME --body "$ACR_USERNAME"
gh secret set ACR_PASSWORD --body "$ACR_PASSWORD"
```

### 3.3 Set Environment Variables

```bash
# Development environment variables
gh api --method PUT repos/:owner/:repo/environments/development/variables/RESOURCE_GROUP_NAME \
  --field name='RESOURCE_GROUP_NAME' \
  --field value='rg-tasktracker-dev'

gh api --method PUT repos/:owner/:repo/environments/development/variables/MONGO_URL \
  --field name='MONGO_URL' \
  --field value='mongodb://cosmos-tasktracker-dev:PASSWORD@cosmos-tasktracker-dev.mongo.cosmos.azure.com:10255/tasktracker?ssl=true'

# Staging environment variables
STAGING_APP_NAME=$(az webapp list --resource-group "rg-tasktracker-staging" --query "[0].name" --output tsv)

gh api --method PUT repos/:owner/:repo/environments/staging/variables/RESOURCE_GROUP_NAME \
  --field name='RESOURCE_GROUP_NAME' \
  --field value='rg-tasktracker-staging'

gh api --method PUT repos/:owner/:repo/environments/staging/variables/APP_SERVICE_NAME \
  --field name='APP_SERVICE_NAME' \
  --field value="$STAGING_APP_NAME"

gh api --method PUT repos/:owner/:repo/environments/staging/variables/MONGO_URL \
  --field name='MONGO_URL' \
  --field value='mongodb://cosmos-tasktracker-staging:PASSWORD@cosmos-tasktracker-staging.mongo.cosmos.azure.com:10255/tasktracker?ssl=true'

# Production environment variables
PROD_APP_NAME=$(az webapp list --resource-group "rg-tasktracker-prod" --query "[0].name" --output tsv)

gh api --method PUT repos/:owner/:repo/environments/production/variables/RESOURCE_GROUP_NAME \
  --field name='RESOURCE_GROUP_NAME' \
  --field value='rg-tasktracker-prod'

gh api --method PUT repos/:owner/:repo/environments/production/variables/APP_SERVICE_NAME \
  --field name='APP_SERVICE_NAME' \
  --field value="$PROD_APP_NAME"

gh api --method PUT repos/:owner/:repo/environments/production/variables/MONGO_URL \
  --field name='MONGO_URL' \
  --field value='mongodb://cosmos-tasktracker-prod:PASSWORD@cosmos-tasktracker-prod.mongo.cosmos.azure.com:10255/tasktracker?ssl=true'
```

### 3.4 Set Up Environment Protection Rules

```bash
# Add protection rules for staging (require review)
gh api --method PUT repos/:owner/:repo/environments/staging \
  --field reviewers='[{"type":"User","id":YOUR_GITHUB_USER_ID}]' \
  --field wait_timer=0

# Add protection rules for production (require review + timer)
gh api --method PUT repos/:owner/:repo/environments/production \
  --field reviewers='[{"type":"User","id":YOUR_GITHUB_USER_ID}]' \
  --field wait_timer=300
```

## Step 4: Test the Pipeline

### 4.1 Create Test Files

Create basic test files to ensure the pipeline works:

```bash
# Create backend test
mkdir -p backend/tests
cat > backend/tests/test_main.py << 'EOF'
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
EOF

# Create frontend test (update package.json if needed)
echo 'import { render } from "@testing-library/react"; import App from "./App"; test("renders app", () => { render(<App />); });' > frontend/src/App.test.js
```

### 4.2 Commit and Push

```bash
# Add the workflow files
git add .github/
git add setup-auth-and-environments.md
git add backend/tests/
git add frontend/src/App.test.js

# Commit and push to develop branch
git checkout -b develop
git commit -m "Add CI/CD pipeline and setup documentation"
git push origin develop

# Create PR and merge to main for full pipeline test
git checkout main
git merge develop
git push origin main
```

## Important Notes

1. **Replace placeholders**: Update `YOUR_GITHUB_USERNAME`, `YOUR_GITHUB_USER_ID`, and `YOUR_SUBSCRIPTION_ID` with actual values
2. **MongoDB passwords**: Replace `PASSWORD` in MongoDB connection strings with actual passwords from Cosmos DB
3. **Resource names**: Some Azure resources require globally unique names - adjust accordingly
4. **Environment protection**: Configure GitHub environment protection rules according to your team's requirements
5. **Monitoring**: Set up Azure Application Insights for monitoring deployed applications

## Troubleshooting

- **Authentication issues**: Verify federated credentials are correctly configured
- **Resource access**: Ensure managed identity has proper RBAC assignments
- **Container registry**: Verify ACR credentials are correctly set in GitHub secrets
- **Environment variables**: Double-check all environment-specific variables are properly set

For additional help, check the GitHub Actions logs and Azure Activity logs for detailed error messages.