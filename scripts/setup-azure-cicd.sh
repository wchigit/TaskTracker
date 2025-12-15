#!/bin/bash

# TaskTracker Azure CI/CD Setup Script for Existing Resources
# This script automates the setup of GitHub Actions for deploying to existing Azure resources

set -e

echo "=========================================="
echo "TaskTracker Azure CI/CD Setup"
echo "For Existing Azure Resources"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI is not installed. Please install it from: https://cli.github.com/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Please install it: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
    exit 1
fi

echo "✅ All prerequisites are installed"
echo ""

# Login to Azure
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Please login to Azure..."
    az login
fi

# Set subscription
SUBSCRIPTION_ID="a4ab3025-1b32-4394-92e0-d07c1ebf3787"
echo "Setting Azure subscription to: $SUBSCRIPTION_ID"
az account set --subscription $SUBSCRIPTION_ID

echo "✅ Using Azure Subscription: $SUBSCRIPTION_ID"
echo ""

# GitHub repository info
GITHUB_ORG="wchigit"
GITHUB_REPO="TaskTracker"

echo "✅ GitHub Organization: $GITHUB_ORG"
echo "✅ GitHub Repository: $GITHUB_REPO"
echo ""

# Verify resource groups exist
echo "Verifying resource groups..."
for RG in "rg-wcdev" "rg-wcstaging" "rg-wcproduction"; do
    if az group show --name $RG &> /dev/null; then
        echo "  ✅ Found: $RG"
    else
        echo "  ❌ Not found: $RG"
        echo "     Please create this resource group first"
        exit 1
    fi
done
echo ""

# Verify Container Apps exist
echo "Verifying Container Apps..."
for RG in "rg-wcdev" "rg-wcstaging" "rg-wcproduction"; do
    BACKEND_APP=$(az containerapp list --resource-group $RG --query "[?contains(name, 'backend')].name | [0]" -o tsv 2>/dev/null || echo "")
    FRONTEND_APP=$(az containerapp list --resource-group $RG --query "[?contains(name, 'frontend')].name | [0]" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$BACKEND_APP" ] && [ -n "$FRONTEND_APP" ]; then
        echo "  ✅ $RG: Backend ($BACKEND_APP), Frontend ($FRONTEND_APP)"
    else
        echo "  ⚠️  $RG: Missing backend or frontend Container App"
        echo "     Backend: ${BACKEND_APP:-NOT FOUND}"
        echo "     Frontend: ${FRONTEND_APP:-NOT FOUND}"
    fi
done
echo ""

# Verify ACR exists
echo "Verifying Azure Container Registry..."
for RG in "rg-wcdev" "rg-wcstaging" "rg-wcproduction"; do
    ACR_NAME=$(az acr list --resource-group $RG --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$ACR_NAME" ]; then
        echo "  ✅ $RG: $ACR_NAME"
    else
        echo "  ⚠️  $RG: No Azure Container Registry found"
    fi
done
echo ""

# Create service principal
echo "Creating Azure service principal..."
SP_NAME="github-actions-tasktracker-$(date +%s)"
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role Contributor \
    --scopes /subscriptions/$SUBSCRIPTION_ID \
    --sdk-auth)

CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.clientId')
TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenantId')

echo "✅ Service Principal created"
echo "   Client ID: $CLIENT_ID"
echo ""

# Grant User Access Administrator role
echo "Granting User Access Administrator role..."
az role assignment create \
    --role "User Access Administrator" \
    --assignee $CLIENT_ID \
    --scope /subscriptions/$SUBSCRIPTION_ID \
    --output none

echo "✅ Role assigned"
echo ""

# Get App ID and create federated credentials for all environments
echo "Creating federated credentials for all environments..."
APP_ID=$(az ad sp show --id $CLIENT_ID --query appId -o tsv)

for ENV in "dev" "staging" "production"; do
    az ad app federated-credential create \
        --id $APP_ID \
        --parameters "{
            \"name\": \"github-federated-$ENV\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:environment:$ENV\",
            \"audiences\": [\"api://AzureADTokenExchange\"]
        }" \
        --output none
    
    echo "  ✅ Created federated credential for $ENV environment"
done
echo ""

# Create GitHub environments
echo "Creating GitHub environments..."
for ENV in "dev" "staging" "production"; do
    gh api --method PUT \
        -H "Accept: application/vnd.github+json" \
        repos/$GITHUB_ORG/$GITHUB_REPO/environments/$ENV \
        --silent || echo "  ⚠️  $ENV environment may already exist"
    
    echo "  ✅ $ENV environment configured"
done
echo ""

# Set GitHub secrets for all environments
echo "Setting GitHub environment secrets..."
for ENV in "dev" "staging" "production"; do
    gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --env $ENV
    gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --env $ENV
    gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --env $ENV
    
    echo "  ✅ Secrets configured for $ENV environment"
done
echo ""

# Summary
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Summary of configured values:"
echo "  - Azure Subscription ID: $SUBSCRIPTION_ID"
echo "  - Azure Tenant ID: $TENANT_ID"
echo "  - Azure Client ID: $CLIENT_ID"
echo "  - GitHub Org: $GITHUB_ORG"
echo "  - GitHub Repo: $GITHUB_REPO"
echo ""
echo "Configured environments:"
echo "  - dev (deploys from 'develop' branch → rg-wcdev)"
echo "  - staging (deploys from 'staging' branch → rg-wcstaging)"
echo "  - production (deploys from 'main' branch → rg-wcproduction)"
echo ""
echo "Next steps:"
echo "  1. Review the DEPLOYMENT.md file for detailed information"
echo "  2. Push your code to trigger automatic deployment:"
echo "     - Push to 'develop' → deploys to dev"
echo "     - Push to 'staging' → deploys to staging"
echo "     - Push to 'main' → deploys to production"
echo "  3. Or manually trigger from GitHub Actions UI"
echo ""
echo "To manually trigger deployment:"
echo "  - Go to: https://github.com/$GITHUB_ORG/$GITHUB_REPO/actions"
echo "  - Select 'Deploy to Azure' workflow"
echo "  - Click 'Run workflow' and choose environment"
echo ""
echo "To view deployment status:"
echo "  gh run list --workflow=azure-deploy.yml"
echo ""
