#!/bin/bash

# TaskTracker CI/CD Setup Script
# This script automates the setup of Azure resources, managed identity, and GitHub environments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install it first."
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI not found. Please install it first."
        exit 1
    fi
    
    # Check if logged into Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check if logged into GitHub
    if ! gh auth status &> /dev/null; then
        print_error "Not logged into GitHub. Please run 'gh auth login' first."
        exit 1
    fi
    
    print_status "All prerequisites met!"
}

# Get configuration from user
get_configuration() {
    print_header "Configuration Setup"
    
    # Get subscription ID
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    print_status "Using Azure subscription: $SUBSCRIPTION_ID"
    
    # Get tenant ID
    TENANT_ID=$(az account show --query tenantId --output tsv)
    print_status "Using Azure tenant: $TENANT_ID"
    
    # Get GitHub repository info
    GITHUB_OWNER=$(gh repo view --json owner --jq '.owner.login')
    GITHUB_REPO=$(gh repo view --json name --jq '.name')
    print_status "Using GitHub repository: $GITHUB_OWNER/$GITHUB_REPO"
    
    # Generate unique suffix for resources
    SUFFIX=$(date +%s | tail -c 6)
    
    # Resource names
    ACR_NAME="acrtasktracker$SUFFIX"
    MI_NAME="mi-tasktracker-github"
    
    print_status "Configuration complete!"
}

# Create Azure resource groups
create_resource_groups() {
    print_header "Creating Azure Resource Groups"
    
    az group create --name "rg-tasktracker-dev" --location "East US" --output none
    az group create --name "rg-tasktracker-staging" --location "East US" --output none  
    az group create --name "rg-tasktracker-prod" --location "East US" --output none
    
    print_status "Resource groups created successfully!"
}

# Create Azure Container Registry
create_acr() {
    print_header "Creating Azure Container Registry"
    
    az acr create --resource-group "rg-tasktracker-dev" --name "$ACR_NAME" --sku Basic --output none
    az acr update --name "$ACR_NAME" --admin-enabled true --output none
    
    ACR_REGISTRY="$ACR_NAME.azurecr.io"
    
    print_status "Container registry created: $ACR_REGISTRY"
}

# Create App Services
create_app_services() {
    print_header "Creating App Services"
    
    # Create App Service Plans
    az appservice plan create --name "asp-tasktracker-staging" --resource-group "rg-tasktracker-staging" --sku B1 --is-linux --output none
    az appservice plan create --name "asp-tasktracker-prod" --resource-group "rg-tasktracker-prod" --sku S1 --is-linux --output none
    
    # Create Web Apps
    STAGING_APP_NAME="tasktracker-staging-$SUFFIX"
    PROD_APP_NAME="tasktracker-prod-$SUFFIX"
    
    az webapp create --resource-group "rg-tasktracker-staging" --plan "asp-tasktracker-staging" --name "$STAGING_APP_NAME" --deployment-container-image-name nginx --output none
    az webapp create --resource-group "rg-tasktracker-prod" --plan "asp-tasktracker-prod" --name "$PROD_APP_NAME" --deployment-container-image-name nginx --output none
    
    print_status "App services created: $STAGING_APP_NAME, $PROD_APP_NAME"
}

# Create Cosmos DB instances
create_cosmos_db() {
    print_header "Creating Cosmos DB Instances"
    
    az cosmosdb create --name "cosmos-tasktracker-dev-$SUFFIX" --resource-group "rg-tasktracker-dev" --kind MongoDB --output none &
    az cosmosdb create --name "cosmos-tasktracker-staging-$SUFFIX" --resource-group "rg-tasktracker-staging" --kind MongoDB --output none &
    az cosmosdb create --name "cosmos-tasktracker-prod-$SUFFIX" --resource-group "rg-tasktracker-prod" --kind MongoDB --output none &
    
    wait
    print_status "Cosmos DB instances created (this may take a few minutes to be fully ready)"
}

# Create managed identity and federated credentials
create_managed_identity() {
    print_header "Creating Managed Identity and Federated Credentials"
    
    # Create managed identity
    az identity create --resource-group "rg-tasktracker-dev" --name "$MI_NAME" --output none
    
    # Get identity details
    CLIENT_ID=$(az identity show --resource-group "rg-tasktracker-dev" --name "$MI_NAME" --query clientId --output tsv)
    OBJECT_ID=$(az identity show --resource-group "rg-tasktracker-dev" --name "$MI_NAME" --query principalId --output tsv)
    
    print_status "Managed identity created: $CLIENT_ID"
    
    # Assign roles
    print_status "Assigning roles to managed identity..."
    az role assignment create --assignee $OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tasktracker-dev" --output none
    az role assignment create --assignee $OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tasktracker-staging" --output none
    az role assignment create --assignee $OBJECT_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tasktracker-prod" --output none
    
    # Assign ACR role
    ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv)
    az role assignment create --assignee $OBJECT_ID --role "AcrPush" --scope $ACR_ID --output none
    
    # Create federated credentials
    print_status "Creating federated credentials..."
    az identity federated-credential create \
        --name "fc-tasktracker-main" \
        --identity-name "$MI_NAME" \
        --resource-group "rg-tasktracker-dev" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$GITHUB_OWNER/$GITHUB_REPO:ref:refs/heads/main" \
        --audience "api://AzureADTokenExchange" --output none
    
    az identity federated-credential create \
        --name "fc-tasktracker-develop" \
        --identity-name "$MI_NAME" \
        --resource-group "rg-tasktracker-dev" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$GITHUB_OWNER/$GITHUB_REPO:ref:refs/heads/develop" \
        --audience "api://AzureADTokenExchange" --output none
    
    az identity federated-credential create \
        --name "fc-tasktracker-pr" \
        --identity-name "$MI_NAME" \
        --resource-group "rg-tasktracker-dev" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$GITHUB_OWNER/$GITHUB_REPO:pull_request" \
        --audience "api://AzureADTokenExchange" --output none
    
    print_status "Federated credentials created!"
}

# Setup GitHub environments and secrets
setup_github() {
    print_header "Setting up GitHub Environments and Secrets"
    
    # Create environments
    print_status "Creating GitHub environments..."
    gh api --method PUT repos/:owner/:repo/environments/development --silent
    gh api --method PUT repos/:owner/:repo/environments/staging --silent
    gh api --method PUT repos/:owner/:repo/environments/production --silent
    
    # Set repository secrets
    print_status "Setting repository secrets..."
    gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
    gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
    gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
    
    # Get ACR credentials
    ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username --output tsv)
    ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query passwords[0].value --output tsv)
    
    gh secret set ACR_NAME --body "$ACR_NAME"
    gh secret set ACR_REGISTRY --body "$ACR_REGISTRY"
    gh secret set ACR_USERNAME --body "$ACR_USERNAME"
    gh secret set ACR_PASSWORD --body "$ACR_PASSWORD"
    
    # Set environment variables
    print_status "Setting environment variables..."
    
    # Development
    gh api --method PUT repos/:owner/:repo/environments/development/variables/RESOURCE_GROUP_NAME \
        --field name='RESOURCE_GROUP_NAME' \
        --field value='rg-tasktracker-dev' --silent
    
    # Staging
    gh api --method PUT repos/:owner/:repo/environments/staging/variables/RESOURCE_GROUP_NAME \
        --field name='RESOURCE_GROUP_NAME' \
        --field value='rg-tasktracker-staging' --silent
    
    gh api --method PUT repos/:owner/:repo/environments/staging/variables/APP_SERVICE_NAME \
        --field name='APP_SERVICE_NAME' \
        --field value="$STAGING_APP_NAME" --silent
    
    # Production
    gh api --method PUT repos/:owner/:repo/environments/production/variables/RESOURCE_GROUP_NAME \
        --field name='RESOURCE_GROUP_NAME' \
        --field value='rg-tasktracker-prod' --silent
    
    gh api --method PUT repos/:owner/:repo/environments/production/variables/APP_SERVICE_NAME \
        --field name='APP_SERVICE_NAME' \
        --field value="$PROD_APP_NAME" --silent
    
    print_status "GitHub setup complete!"
}

# Main execution
main() {
    print_header "TaskTracker CI/CD Setup"
    
    check_prerequisites
    get_configuration
    create_resource_groups
    create_acr
    create_app_services
    create_cosmos_db
    create_managed_identity
    setup_github
    
    print_header "Setup Complete!"
    print_status "Your TaskTracker CI/CD pipeline is now configured!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Push your code to the 'develop' branch to trigger a dev deployment"
    print_status "2. Create a PR from 'develop' to 'main' for staging deployment"
    print_status "3. Merge to 'main' to trigger staging and production deployments"
    print_status ""
    print_status "Resource Summary:"
    print_status "- Container Registry: $ACR_REGISTRY"
    print_status "- Staging App: https://$STAGING_APP_NAME.azurewebsites.net"
    print_status "- Production App: https://$PROD_APP_NAME.azurewebsites.net"
}

# Run main function
main "$@"