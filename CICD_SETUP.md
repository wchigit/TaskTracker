# CI/CD Pipeline Setup Guide

This guide will help you set up the CI/CD pipeline for your TaskTracker application.

## Prerequisites

1. GitHub CLI installed (`gh` command)
2. Azure CLI installed (`az` command)
3. Your repository pushed to GitHub

## Step 1: Create User-Assigned Managed Identity

Run the following commands to create a managed identity for the CI/CD pipeline:

```bash
# Set variables (replace with your values)
$AZURE_ENV_NAME = "dev"
$AZURE_LOCATION = "eastus2"
$AZURE_SUBSCRIPTION_ID = "your-subscription-id"
$RESOURCE_GROUP_NAME = "rg-tasktracker-$AZURE_ENV_NAME"

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $AZURE_LOCATION

# Create user-assigned managed identity
$MI_NAME = "mi-tasktracker-$AZURE_ENV_NAME-cicd"
az identity create --name $MI_NAME --resource-group $RESOURCE_GROUP_NAME --location $AZURE_LOCATION

# Get the managed identity details
$MI_CLIENT_ID = az identity show --name $MI_NAME --resource-group $RESOURCE_GROUP_NAME --query clientId -o tsv
$MI_PRINCIPAL_ID = az identity show --name $MI_NAME --resource-group $RESOURCE_GROUP_NAME --query principalId -o tsv

# Assign Contributor role to the managed identity for the resource group
az role assignment create --assignee $MI_PRINCIPAL_ID --role "Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME"

# Assign Owner role to the managed identity for the resource group (needed for role assignments)
az role assignment create --assignee $MI_PRINCIPAL_ID --role "Owner" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME"

echo "Managed Identity Client ID: $MI_CLIENT_ID"
echo "Resource Group: $RESOURCE_GROUP_NAME"
```

## Step 2: Configure GitHub OIDC (Recommended)

Create a federated credential for GitHub Actions:

```bash
# Get your GitHub repository information
$GITHUB_ORG = "wchigit"  # Replace with your GitHub organization/username
$GITHUB_REPO = "TaskTracker"  # Replace with your repository name

# Create federated credential for main branch
az identity federated-credential create `
  --name "tasktracker-main-branch" `
  --identity-name $MI_NAME `
  --resource-group $RESOURCE_GROUP_NAME `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/main" `
  --audience "api://AzureADTokenExchange"

# Create federated credential for pull requests
az identity federated-credential create `
  --name "tasktracker-pr" `
  --identity-name $MI_NAME `
  --resource-group $RESOURCE_GROUP_NAME `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "repo:$GITHUB_ORG/$GITHUB_REPO:pull_request" `
  --audience "api://AzureADTokenExchange"

# Get tenant ID
$AZURE_TENANT_ID = az account show --query tenantId -o tsv

echo "Setup complete! Use these values in GitHub:"
echo "AZURE_CLIENT_ID: $MI_CLIENT_ID"
echo "AZURE_TENANT_ID: $AZURE_TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"
```

## Step 3: Configure GitHub Repository Secrets and Variables

Run these commands to set up your GitHub repository:

```bash
# Navigate to your repository directory
cd "c:\dev\samplerepo\TaskTracker"

# Set repository variables (replace values as needed)
gh variable set AZURE_CLIENT_ID --body $MI_CLIENT_ID
gh variable set AZURE_TENANT_ID --body $AZURE_TENANT_ID
gh variable set AZURE_SUBSCRIPTION_ID --body $AZURE_SUBSCRIPTION_ID
gh variable set AZURE_ENV_NAME --body $AZURE_ENV_NAME
gh variable set AZURE_LOCATION --body $AZURE_LOCATION
gh variable set AZURE_RESOURCE_GROUP --body $RESOURCE_GROUP_NAME

# Verify variables are set
gh variable list
```

## Alternative: Service Principal Authentication (if OIDC is not preferred)

If you prefer to use a service principal instead of OIDC:

```bash
# Create service principal
$SP_INFO = az ad sp create-for-rbac --name "sp-tasktracker-$AZURE_ENV_NAME" --role "Contributor" --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME" --json-auth

# Set the service principal credentials as a GitHub secret
echo $SP_INFO | gh secret set AZURE_CREDENTIALS
```

## Step 4: Test the Pipeline

1. Push your code to the `main` branch or create a pull request
2. Go to your GitHub repository's Actions tab
3. You should see the "Azure Developer CLI" workflow running
4. Monitor the logs to ensure everything deploys successfully

## Environment Structure

The pipeline will create and deploy to a `dev` environment with the following resources:
- Container Apps Environment
- Azure Container Registry
- Cosmos DB (MongoDB API)
- Key Vault
- Application Insights
- User-assigned Managed Identity

## Troubleshooting

1. **Permission errors**: Ensure the managed identity has Contributor and Owner roles on the resource group
2. **Resource group not found**: Make sure the resource group is created and the `AZURE_RESOURCE_GROUP` variable is set correctly
3. **Authentication issues**: Verify all GitHub variables and secrets are set correctly

## Next Steps

- Consider adding different environments (staging, production) with separate resource groups
- Add approval gates for production deployments
- Implement blue-green deployment strategies
- Add automated testing steps before deployment