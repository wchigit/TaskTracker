# TaskTracker Deployment Script - PowerShell Version
# This script deploys the TaskTracker application to Azure using Azure CLI

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$true)]
    [string]$CommitSha,
    
    [Parameter(Mandatory=$true)]
    [string]$RepositoryOwner,
    
    [Parameter(Mandatory=$true)]
    [string]$RepositoryName
)

# Set error handling
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-StatusMessage {
    param([string]$Message, [string]$Color = "Blue")
    Write-Host "[INFO] $Message" -ForegroundColor $Color
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Generate unique resource names
function Initialize-ResourceNames {
    Write-StatusMessage "Generating resource names..."
    
    # Generate unique token for resource naming (similar to Bicep's uniqueString)
    $TokenSource = "$RepositoryOwner$RepositoryName$Location"
    $Hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($TokenSource))
    $ResourceToken = ([System.BitConverter]::ToString($Hash) -replace '-', '').Substring(0, 13).ToLower()
    
    # Set global variables for resource names
    $Global:ManagedIdentityName = "azumi$ResourceToken"
    $Global:LogAnalyticsName = "azlaw$ResourceToken"
    $Global:AppInsightsName = "azai$ResourceToken"
    $Global:ContainerRegistryName = "azcr$ResourceToken"
    $Global:KeyVaultName = "azkv$ResourceToken"
    $Global:CosmosDbName = "azcdb$ResourceToken"
    $Global:ContainerEnvName = "azcae$ResourceToken"
    $Global:BackendAppName = "azca-backend-$ResourceToken"
    $Global:FrontendAppName = "azca-frontend-$ResourceToken"
    
    Write-SuccessMessage "Resource names generated with token: $ResourceToken"
}

# Create Azure Resource Group
function New-ResourceGroup {
    Write-StatusMessage "Creating resource group: $ResourceGroup"
    
    az group create `
        --name $ResourceGroup `
        --location $Location `
        --tags environment=production project=tasktracker `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create resource group" }
    Write-SuccessMessage "Resource group created successfully"
}

# Create foundational resources
function New-FoundationalResources {
    Write-StatusMessage "Creating foundational resources..."
    
    # Create Managed Identity
    Write-StatusMessage "Creating managed identity: $Global:ManagedIdentityName"
    az identity create `
        --name $Global:ManagedIdentityName `
        --resource-group $ResourceGroup `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create managed identity" }
    
    # Create Log Analytics Workspace
    Write-StatusMessage "Creating Log Analytics workspace: $Global:LogAnalyticsName"
    az monitor log-analytics workspace create `
        --workspace-name $Global:LogAnalyticsName `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku PerGB2018 `
        --retention-time 30 `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Log Analytics workspace" }
    
    # Create Application Insights
    Write-StatusMessage "Creating Application Insights: $Global:AppInsightsName"
    $WorkspaceId = az monitor log-analytics workspace show `
        --workspace-name $Global:LogAnalyticsName `
        --resource-group $ResourceGroup `
        --query "id" -o tsv
    
    az monitor app-insights component create `
        --app $Global:AppInsightsName `
        --resource-group $ResourceGroup `
        --location $Location `
        --kind web `
        --application-type web `
        --workspace $WorkspaceId `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Application Insights" }
    Write-SuccessMessage "Foundational resources created successfully"
}

# Create container registry and assign permissions
function New-ContainerRegistry {
    Write-StatusMessage "Creating container registry: $Global:ContainerRegistryName"
    
    az acr create `
        --name $Global:ContainerRegistryName `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Basic `
        --admin-enabled false `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create container registry" }
    
    # Get managed identity principal ID
    $ManagedIdentityId = az identity show `
        --name $Global:ManagedIdentityName `
        --resource-group $ResourceGroup `
        --query "principalId" -o tsv
    
    # Get registry resource ID
    $RegistryId = az acr show `
        --name $Global:ContainerRegistryName `
        --query "id" -o tsv
    
    # Assign AcrPull role to managed identity
    Write-StatusMessage "Assigning AcrPull role to managed identity"
    az role assignment create `
        --assignee $ManagedIdentityId `
        --role "AcrPull" `
        --scope $RegistryId `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to assign AcrPull role" }
    Write-SuccessMessage "Container registry created and permissions assigned"
}

# Create Key Vault and assign permissions
function New-KeyVault {
    Write-StatusMessage "Creating Key Vault: $Global:KeyVaultName"
    
    az keyvault create `
        --name $Global:KeyVaultName `
        --resource-group $ResourceGroup `
        --location $Location `
        --enable-rbac-authorization `
        --public-network-access Enabled `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Key Vault" }
    
    # Get managed identity principal ID
    $ManagedIdentityId = az identity show `
        --name $Global:ManagedIdentityName `
        --resource-group $ResourceGroup `
        --query "principalId" -o tsv
    
    # Get Key Vault resource ID
    $KeyVaultId = az keyvault show `
        --name $Global:KeyVaultName `
        --query "id" -o tsv
    
    # Assign Key Vault Secrets Officer role to managed identity
    Write-StatusMessage "Assigning Key Vault Secrets Officer role to managed identity"
    az role assignment create `
        --assignee $ManagedIdentityId `
        --role "Key Vault Secrets Officer" `
        --scope $KeyVaultId `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to assign Key Vault role" }
    Write-SuccessMessage "Key Vault created and permissions assigned"
}

# Create Cosmos DB
function New-CosmosDb {
    Write-StatusMessage "Creating Cosmos DB: $Global:CosmosDbName"
    
    az cosmosdb create `
        --name $Global:CosmosDbName `
        --resource-group $ResourceGroup `
        --kind MongoDB `
        --locations regionName=$Location failoverPriority=0 isZoneRedundant=False `
        --capabilities EnableMongo `
        --ip-range-filter "0.0.0.0" `
        --public-network-access Enabled `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Cosmos DB" }
    
    # Create database
    Write-StatusMessage "Creating Cosmos DB database: tasktracker"
    az cosmosdb mongodb database create `
        --account-name $Global:CosmosDbName `
        --resource-group $ResourceGroup `
        --name tasktracker `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Cosmos DB database" }
    
    # Create collection
    Write-StatusMessage "Creating Cosmos DB collection: tasks"
    az cosmosdb mongodb collection create `
        --account-name $Global:CosmosDbName `
        --resource-group $ResourceGroup `
        --database-name tasktracker `
        --name tasks `
        --shard id `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Cosmos DB collection" }
    
    # Store connection string in Key Vault
    Write-StatusMessage "Storing Cosmos DB connection string in Key Vault"
    $ConnectionString = az cosmosdb keys list `
        --name $Global:CosmosDbName `
        --resource-group $ResourceGroup `
        --type connection-strings `
        --query "connectionStrings[0].connectionString" -o tsv
    
    az keyvault secret set `
        --vault-name $Global:KeyVaultName `
        --name "cosmos-connection-string" `
        --value $ConnectionString `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to store connection string in Key Vault" }
    Write-SuccessMessage "Cosmos DB created and configured"
}

# Create Container Apps Environment
function New-ContainerAppsEnvironment {
    Write-StatusMessage "Creating Container Apps Environment: $Global:ContainerEnvName"
    
    $WorkspaceId = az monitor log-analytics workspace show `
        --workspace-name $Global:LogAnalyticsName `
        --resource-group $ResourceGroup `
        --query "customerId" -o tsv
    
    $WorkspaceKey = az monitor log-analytics workspace get-shared-keys `
        --workspace-name $Global:LogAnalyticsName `
        --resource-group $ResourceGroup `
        --query "primarySharedKey" -o tsv
    
    az containerapp env create `
        --name $Global:ContainerEnvName `
        --resource-group $ResourceGroup `
        --location $Location `
        --logs-workspace-id $WorkspaceId `
        --logs-workspace-key $WorkspaceKey `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Container Apps Environment" }
    Write-SuccessMessage "Container Apps Environment created"
}

# Build and push container images
function Build-ContainerImages {
    Write-StatusMessage "Building and pushing container images..."
    
    # Build and push backend image
    Write-StatusMessage "Building backend image"
    az acr build `
        --registry $Global:ContainerRegistryName `
        --image "tasktracker/backend:$CommitSha" `
        --image "tasktracker/backend:latest" `
        --file backend/Dockerfile `
        backend/
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to build backend image" }
    
    # Build and push frontend image
    Write-StatusMessage "Building frontend image"
    az acr build `
        --registry $Global:ContainerRegistryName `
        --image "tasktracker/frontend:$CommitSha" `
        --image "tasktracker/frontend:latest" `
        --file frontend/Dockerfile.prod `
        frontend/
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to build frontend image" }
    Write-SuccessMessage "Container images built and pushed"
}

# Deploy container apps
function Deploy-ContainerApps {
    Write-StatusMessage "Deploying container applications..."
    
    # Get required values
    $ManagedIdentityResourceId = az identity show `
        --name $Global:ManagedIdentityName `
        --resource-group $ResourceGroup `
        --query "id" -o tsv
    
    $RegistryServer = az acr show `
        --name $Global:ContainerRegistryName `
        --query "loginServer" -o tsv
    
    $ConnectionString = az cosmosdb keys list `
        --name $Global:CosmosDbName `
        --resource-group $ResourceGroup `
        --type connection-strings `
        --query "connectionStrings[0].connectionString" -o tsv
    
    # Create backend container app
    Write-StatusMessage "Creating backend container app: $Global:BackendAppName"
    az containerapp create `
        --name $Global:BackendAppName `
        --resource-group $ResourceGroup `
        --environment $Global:ContainerEnvName `
        --image "$RegistryServer/tasktracker/backend:$CommitSha" `
        --target-port 80 `
        --ingress external `
        --user-assigned $ManagedIdentityResourceId `
        --registry-server $RegistryServer `
        --registry-identity $ManagedIdentityResourceId `
        --secrets mongo-url="$ConnectionString" `
        --env-vars MONGO_URL=secretref:mongo-url `
        --cpu 0.5 `
        --memory 1.0Gi `
        --min-replicas 0 `
        --max-replicas 10 `
        --tags azd-service-name=backend `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create backend container app" }
    
    # Get backend URL
    $BackendFqdn = az containerapp show `
        --name $Global:BackendAppName `
        --resource-group $ResourceGroup `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    $BackendUrl = "https://$BackendFqdn"
    
    # Create frontend container app
    Write-StatusMessage "Creating frontend container app: $Global:FrontendAppName"
    az containerapp create `
        --name $Global:FrontendAppName `
        --resource-group $ResourceGroup `
        --environment $Global:ContainerEnvName `
        --image "$RegistryServer/tasktracker/frontend:$CommitSha" `
        --target-port 80 `
        --ingress external `
        --user-assigned $ManagedIdentityResourceId `
        --registry-server $RegistryServer `
        --registry-identity $ManagedIdentityResourceId `
        --env-vars REACT_APP_API_URL="$BackendUrl" `
        --cpu 0.25 `
        --memory 0.5Gi `
        --min-replicas 0 `
        --max-replicas 5 `
        --tags azd-service-name=frontend `
        --output table
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create frontend container app" }
    Write-SuccessMessage "Container applications deployed successfully"
    
    # Output deployment summary
    $FrontendFqdn = az containerapp show `
        --name $Global:FrontendAppName `
        --resource-group $ResourceGroup `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "🚀 DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "Location: $Location" -ForegroundColor White
    Write-Host "Container Registry: $RegistryServer" -ForegroundColor White
    Write-Host "Backend API: $BackendUrl" -ForegroundColor White
    Write-Host "Frontend App: https://$FrontendFqdn" -ForegroundColor White
    Write-Host "Commit SHA: $CommitSha" -ForegroundColor White
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Main deployment function
function Start-Deployment {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "🚀 TaskTracker Deployment Starting" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    try {
        Initialize-ResourceNames
        
        # Infrastructure deployment
        New-ResourceGroup
        New-FoundationalResources
        New-ContainerRegistry
        New-KeyVault
        New-CosmosDb
        New-ContainerAppsEnvironment
        
        # Application deployment
        Build-ContainerImages
        Deploy-ContainerApps
        
        Write-SuccessMessage "🎉 Deployment completed successfully!"
    }
    catch {
        Write-ErrorMessage "Deployment failed: $($_.Exception.Message)"
        throw
    }
}

# Run the deployment
Start-Deployment