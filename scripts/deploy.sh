#!/bin/bash

# TaskTracker Deployment Script
# This script deploys the TaskTracker application to Azure using Azure CLI

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
validate_env_vars() {
    print_status "Validating environment variables..."
    
    required_vars=("RESOURCE_GROUP" "LOCATION" "APP_NAME" "COMMIT_SHA" "REPOSITORY_OWNER" "REPOSITORY_NAME")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            print_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    print_success "All required environment variables are set"
}

# Generate unique resource names
generate_resource_names() {
    print_status "Generating resource names..."
    
    # Generate unique token for resource naming (similar to Bicep's uniqueString)
    RESOURCE_TOKEN=$(echo "${REPOSITORY_OWNER}${REPOSITORY_NAME}${LOCATION}" | shasum -a 256 | cut -c1-13)
    
    # Export resource names
    export MANAGED_IDENTITY_NAME="azumi${RESOURCE_TOKEN}"
    export LOG_ANALYTICS_NAME="azlaw${RESOURCE_TOKEN}"
    export APP_INSIGHTS_NAME="azai${RESOURCE_TOKEN}"
    export CONTAINER_REGISTRY_NAME="azcr${RESOURCE_TOKEN}"
    export KEY_VAULT_NAME="azkv${RESOURCE_TOKEN}"
    export COSMOS_DB_NAME="azcdb${RESOURCE_TOKEN}"
    export CONTAINER_ENV_NAME="azcae${RESOURCE_TOKEN}"
    export BACKEND_APP_NAME="azca-backend-${RESOURCE_TOKEN}"
    export FRONTEND_APP_NAME="azca-frontend-${RESOURCE_TOKEN}"
    
    print_success "Resource names generated with token: ${RESOURCE_TOKEN}"
}

# Create Azure Resource Group
create_resource_group() {
    print_status "Creating resource group: ${RESOURCE_GROUP}"
    
    az group create \
        --name "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --tags environment=production project=tasktracker \
        --output table
    
    print_success "Resource group created successfully"
}

# Create foundational resources
create_foundational_resources() {
    print_status "Creating foundational resources..."
    
    # Create Managed Identity
    print_status "Creating managed identity: ${MANAGED_IDENTITY_NAME}"
    az identity create \
        --name "${MANAGED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --output table
    
    # Create Log Analytics Workspace
    print_status "Creating Log Analytics workspace: ${LOG_ANALYTICS_NAME}"
    az monitor log-analytics workspace create \
        --workspace-name "${LOG_ANALYTICS_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --sku PerGB2018 \
        --retention-time 30 \
        --output table
    
    # Create Application Insights
    print_status "Creating Application Insights: ${APP_INSIGHTS_NAME}"
    WORKSPACE_ID=$(az monitor log-analytics workspace show \
        --workspace-name "${LOG_ANALYTICS_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "id" -o tsv)
    
    az monitor app-insights component create \
        --app "${APP_INSIGHTS_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --kind web \
        --application-type web \
        --workspace "${WORKSPACE_ID}" \
        --output table
    
    print_success "Foundational resources created successfully"
}

# Create container registry and assign permissions
create_container_registry() {
    print_status "Creating container registry: ${CONTAINER_REGISTRY_NAME}"
    
    az acr create \
        --name "${CONTAINER_REGISTRY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --sku Basic \
        --admin-enabled false \
        --output table
    
    # Get managed identity principal ID
    MANAGED_IDENTITY_ID=$(az identity show \
        --name "${MANAGED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "principalId" -o tsv)
    
    # Get registry resource ID
    REGISTRY_ID=$(az acr show \
        --name "${CONTAINER_REGISTRY_NAME}" \
        --query "id" -o tsv)
    
    # Assign AcrPull role to managed identity
    print_status "Assigning AcrPull role to managed identity"
    az role assignment create \
        --assignee "${MANAGED_IDENTITY_ID}" \
        --role "AcrPull" \
        --scope "${REGISTRY_ID}" \
        --output table
    
    print_success "Container registry created and permissions assigned"
}

# Create Key Vault and assign permissions
create_key_vault() {
    print_status "Creating Key Vault: ${KEY_VAULT_NAME}"
    
    az keyvault create \
        --name "${KEY_VAULT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --enable-rbac-authorization \
        --public-network-access Enabled \
        --output table
    
    # Get managed identity principal ID
    MANAGED_IDENTITY_ID=$(az identity show \
        --name "${MANAGED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "principalId" -o tsv)
    
    # Get Key Vault resource ID\n    KEYVAULT_ID=$(az keyvault show \
        --name "${KEY_VAULT_NAME}" \
        --query "id" -o tsv)
    
    # Assign Key Vault Secrets Officer role to managed identity
    print_status "Assigning Key Vault Secrets Officer role to managed identity"
    az role assignment create \
        --assignee "${MANAGED_IDENTITY_ID}" \
        --role "Key Vault Secrets Officer" \
        --scope "${KEYVAULT_ID}" \
        --output table
    
    print_success "Key Vault created and permissions assigned"
}

# Create Cosmos DB
create_cosmos_db() {
    print_status "Creating Cosmos DB: ${COSMOS_DB_NAME}"
    
    az cosmosdb create \
        --name "${COSMOS_DB_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --kind MongoDB \
        --locations regionName="${LOCATION}" failoverPriority=0 isZoneRedundant=False \
        --capabilities EnableMongo \
        --ip-range-filter "0.0.0.0" \
        --public-network-access Enabled \
        --output table
    
    # Create database
    print_status "Creating Cosmos DB database: tasktracker"
    az cosmosdb mongodb database create \
        --account-name "${COSMOS_DB_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name tasktracker \
        --output table
    
    # Create collection
    print_status "Creating Cosmos DB collection: tasks"
    az cosmosdb mongodb collection create \
        --account-name "${COSMOS_DB_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --database-name tasktracker \
        --name tasks \
        --shard id \
        --output table
    
    # Store connection string in Key Vault
    print_status "Storing Cosmos DB connection string in Key Vault"
    CONNECTION_STRING=$(az cosmosdb keys list \
        --name "${COSMOS_DB_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --type connection-strings \
        --query "connectionStrings[0].connectionString" -o tsv)
    
    az keyvault secret set \
        --vault-name "${KEY_VAULT_NAME}" \
        --name "cosmos-connection-string" \
        --value "${CONNECTION_STRING}" \
        --output table
    
    print_success "Cosmos DB created and configured"
}

# Create Container Apps Environment
create_container_apps_environment() {
    print_status "Creating Container Apps Environment: ${CONTAINER_ENV_NAME}"
    
    WORKSPACE_ID=$(az monitor log-analytics workspace show \
        --workspace-name "${LOG_ANALYTICS_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "customerId" -o tsv)
    
    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
        --workspace-name "${LOG_ANALYTICS_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "primarySharedKey" -o tsv)
    
    az containerapp env create \
        --name "${CONTAINER_ENV_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --logs-workspace-id "${WORKSPACE_ID}" \
        --logs-workspace-key "${WORKSPACE_KEY}" \
        --output table
    
    print_success "Container Apps Environment created"
}

# Build and push container images
build_and_push_images() {
    print_status "Building and pushing container images..."
    
    # Build and push backend image
    print_status "Building backend image"
    az acr build \
        --registry "${CONTAINER_REGISTRY_NAME}" \
        --image "tasktracker/backend:${COMMIT_SHA}" \
        --image "tasktracker/backend:latest" \
        --file backend/Dockerfile \
        backend/
    
    # Build and push frontend image
    print_status "Building frontend image"
    az acr build \
        --registry "${CONTAINER_REGISTRY_NAME}" \
        --image "tasktracker/frontend:${COMMIT_SHA}" \
        --image "tasktracker/frontend:latest" \
        --file frontend/Dockerfile.prod \
        frontend/
    
    print_success "Container images built and pushed"
}

# Deploy container apps
deploy_container_apps() {
    print_status "Deploying container applications..."
    
    # Get required values
    MANAGED_IDENTITY_RESOURCE_ID=$(az identity show \
        --name "${MANAGED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "id" -o tsv)
    
    REGISTRY_SERVER=$(az acr show \
        --name "${CONTAINER_REGISTRY_NAME}" \
        --query "loginServer" -o tsv)
    
    CONNECTION_STRING=$(az cosmosdb keys list \
        --name "${COSMOS_DB_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --type connection-strings \
        --query "connectionStrings[0].connectionString" -o tsv)
    
    # Create backend container app
    print_status "Creating backend container app: ${BACKEND_APP_NAME}"
    az containerapp create \
        --name "${BACKEND_APP_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --environment "${CONTAINER_ENV_NAME}" \
        --image "${REGISTRY_SERVER}/tasktracker/backend:${COMMIT_SHA}" \
        --target-port 80 \
        --ingress external \
        --user-assigned "${MANAGED_IDENTITY_RESOURCE_ID}" \
        --registry-server "${REGISTRY_SERVER}" \
        --registry-identity "${MANAGED_IDENTITY_RESOURCE_ID}" \
        --secrets mongo-url="${CONNECTION_STRING}" \
        --env-vars MONGO_URL=secretref:mongo-url \
        --cpu 0.5 \
        --memory 1.0Gi \
        --min-replicas 0 \
        --max-replicas 10 \
        --tags azd-service-name=backend \
        --output table
    
    # Get backend URL
    BACKEND_FQDN=$(az containerapp show \
        --name "${BACKEND_APP_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "properties.configuration.ingress.fqdn" -o tsv)
    
    BACKEND_URL="https://${BACKEND_FQDN}"
    
    # Create frontend container app
    print_status "Creating frontend container app: ${FRONTEND_APP_NAME}"
    az containerapp create \
        --name "${FRONTEND_APP_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --environment "${CONTAINER_ENV_NAME}" \
        --image "${REGISTRY_SERVER}/tasktracker/frontend:${COMMIT_SHA}" \
        --target-port 80 \
        --ingress external \
        --user-assigned "${MANAGED_IDENTITY_RESOURCE_ID}" \
        --registry-server "${REGISTRY_SERVER}" \
        --registry-identity "${MANAGED_IDENTITY_RESOURCE_ID}" \
        --env-vars REACT_APP_API_URL="${BACKEND_URL}" \
        --cpu 0.25 \
        --memory 0.5Gi \
        --min-replicas 0 \
        --max-replicas 5 \
        --tags azd-service-name=frontend \
        --output table
    
    print_success "Container applications deployed successfully"
    
    # Output deployment summary
    FRONTEND_FQDN=$(az containerapp show \
        --name "${FRONTEND_APP_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "properties.configuration.ingress.fqdn" -o tsv)
    
    echo ""
    echo "========================================="
    echo "🚀 DEPLOYMENT SUMMARY"
    echo "========================================="
    echo "Resource Group: ${RESOURCE_GROUP}"
    echo "Location: ${LOCATION}"
    echo "Container Registry: ${REGISTRY_SERVER}"
    echo "Backend API: ${BACKEND_URL}"
    echo "Frontend App: https://${FRONTEND_FQDN}"
    echo "Commit SHA: ${COMMIT_SHA}"
    echo "========================================="
}

# Main deployment function
main() {
    echo "========================================="
    echo "🚀 TaskTracker Deployment Starting"
    echo "========================================="
    
    validate_env_vars
    generate_resource_names
    
    # Infrastructure deployment
    create_resource_group
    create_foundational_resources
    create_container_registry
    create_key_vault
    create_cosmos_db
    create_container_apps_environment
    
    # Application deployment
    build_and_push_images
    deploy_container_apps
    
    print_success "🎉 Deployment completed successfully!"
}

# Run main function
main "$@"