# TaskTracker CI/CD Setup Script (PowerShell)
# This script automates the setup of Azure resources, managed identity, and GitHub environments

Param(
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    [string]$DevResourceGroup = "rg-tasktracker-dev",
    [string]$StagingResourceGroup = "rg-tasktracker-staging", 
    [string]$ProdResourceGroup = "rg-tasktracker-prod",
    [Parameter(Mandatory=$true)]
    [string]$StagingBackendAppName,
    [Parameter(Mandatory=$true)]
    [string]$StagingFrontendAppName,
    [Parameter(Mandatory=$true)]
    [string]$ProdBackendAppName,
    [Parameter(Mandatory=$true)]
    [string]$ProdFrontendAppName,
    [string]$ManagedIdentityName = "mi-tasktracker-github"
)

$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "==== $Message ====" -ForegroundColor Blue
}

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check Azure CLI
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI not found. Please install it first."
        exit 1
    }
    
    # Check GitHub CLI
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI not found. Please install it first."
        exit 1
    }
    
    # Check if logged into Azure
    try {
        az account show --output none
    }
    catch {
        Write-Error "Not logged into Azure. Please run 'az login' first."
        exit 1
    }
    
    # Check if logged into GitHub
    try {
        gh auth status
    }
    catch {
        Write-Error "Not logged into GitHub. Please run 'gh auth login' first."
        exit 1
    }
    
    Write-Status "All prerequisites met!"
}

# Get configuration
function Get-Configuration {
    Write-Header "Configuration Setup"
    
    # Set script variables from parameters
    $script:AcrName = $AcrName
    $script:StagingBackendAppName = $StagingBackendAppName
    $script:StagingFrontendAppName = $StagingFrontendAppName
    $script:ProdBackendAppName = $ProdBackendAppName
    $script:ProdFrontendAppName = $ProdFrontendAppName
    $script:MiName = $ManagedIdentityName
    $script:DevResourceGroup = $DevResourceGroup
    $script:StagingResourceGroup = $StagingResourceGroup
    $script:ProdResourceGroup = $ProdResourceGroup
    
    Write-Status "Using existing infrastructure:"
    Write-Status "  ACR: $AcrName"
    Write-Status "  Dev RG: $DevResourceGroup (uses Container Instances - no pre-existing apps needed)"
    Write-Status "  Staging RG: $StagingResourceGroup"
    Write-Status "    Backend App: $StagingBackendAppName"
    Write-Status "    Frontend App: $StagingFrontendAppName"
    Write-Status "  Prod RG: $ProdResourceGroup"
    Write-Status "    Backend App: $ProdBackendAppName"
    Write-Status "    Frontend App: $ProdFrontendAppName"
    
    # Get subscription and tenant ID
    $script:SubscriptionId = az account show --query id --output tsv
    $script:TenantId = az account show --query tenantId --output tsv
    
    Write-Status "Using Azure subscription: $SubscriptionId"
    Write-Status "Using Azure tenant: $TenantId"
    
    # Get GitHub repository info
    $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
    $script:GitHubOwner = $repoInfo.owner.login
    $script:GitHubRepo = $repoInfo.name
    
    Write-Status "Using GitHub repository: $GitHubOwner/$GitHubRepo"
    
    # Set registry URL
    $script:AcrRegistry = "$script:AcrName.azurecr.io"
    
    Write-Status "Configuration complete!"
}





# Create managed identity
function New-ManagedIdentity {
    Write-Header "Creating Managed Identity and Federated Credentials"
    
    # Create managed identity
    az identity create --resource-group $DevResourceGroup --name $MiName --output none
    
    # Get identity details
    $script:ClientId = az identity show --resource-group $DevResourceGroup --name $MiName --query clientId --output tsv
    $ObjectId = az identity show --resource-group $DevResourceGroup --name $MiName --query principalId --output tsv
    
    Write-Status "Managed identity created: $ClientId"
    
    # Assign roles
    Write-Status "Assigning roles to managed identity..."
    az role assignment create --assignee $ObjectId --role "Contributor" --scope "/subscriptions/$SubscriptionId/resourceGroups/$DevResourceGroup" --output none
    az role assignment create --assignee $ObjectId --role "Contributor" --scope "/subscriptions/$SubscriptionId/resourceGroups/$StagingResourceGroup" --output none
    az role assignment create --assignee $ObjectId --role "Contributor" --scope "/subscriptions/$SubscriptionId/resourceGroups/$ProdResourceGroup" --output none
    
    # Assign ACR role
    $AcrId = az acr show --name $AcrName --query id --output tsv
    az role assignment create --assignee $ObjectId --role "AcrPush" --scope $AcrId --output none
    
    # Create federated credentials
    Write-Status "Creating federated credentials..."
    
    az identity federated-credential create `
        --name "fc-tasktracker-main" `
        --identity-name $MiName `
        --resource-group $DevResourceGroup `
        --issuer "https://token.actions.githubusercontent.com" `
        --subject "repo:$GitHubOwner/$GitHubRepo:ref:refs/heads/main" `
        --audience "api://AzureADTokenExchange" --output none
    
    az identity federated-credential create `
        --name "fc-tasktracker-develop" `
        --identity-name $MiName `
        --resource-group $DevResourceGroup `
        --issuer "https://token.actions.githubusercontent.com" `
        --subject "repo:$GitHubOwner/$GitHubRepo:ref:refs/heads/develop" `
        --audience "api://AzureADTokenExchange" --output none
    
    az identity federated-credential create `
        --name "fc-tasktracker-pr" `
        --identity-name $MiName `
        --resource-group $DevResourceGroup `
        --issuer "https://token.actions.githubusercontent.com" `
        --subject "repo:$GitHubOwner/$GitHubRepo:pull_request" `
        --audience "api://AzureADTokenExchange" --output none
    
    Write-Status "Federated credentials created!"
}

# Setup GitHub
function Set-GitHubConfiguration {
    Write-Header "Setting up GitHub Environments and Secrets"
    
    # Create environments
    Write-Status "Creating GitHub environments..."
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/development" --silent
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/staging" --silent
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/production" --silent
    
    # Set repository secrets
    Write-Status "Setting repository secrets..."
    gh secret set AZURE_CLIENT_ID --body $ClientId
    gh secret set AZURE_TENANT_ID --body $TenantId
    gh secret set AZURE_SUBSCRIPTION_ID --body $SubscriptionId
    
    # Get ACR credentials
    $AcrCredentials = az acr credential show --name $AcrName | ConvertFrom-Json
    $AcrUsername = $AcrCredentials.username
    $AcrPassword = $AcrCredentials.passwords[0].value
    
    gh secret set ACR_NAME --body $AcrName
    gh secret set ACR_REGISTRY --body $AcrRegistry
    gh secret set ACR_USERNAME --body $AcrUsername
    gh secret set ACR_PASSWORD --body $AcrPassword
    
    # Set environment variables
    Write-Status "Setting environment variables..."
    
    # Use configured resource group names
    $devRgName = $DevResourceGroup
    $stagingRgName = $StagingResourceGroup  
    $prodRgName = $ProdResourceGroup
    
    # Development
    $devVarBody = @{ name = 'RESOURCE_GROUP_NAME'; value = $devRgName } | ConvertTo-Json
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/development/variables/RESOURCE_GROUP_NAME" --input - <<< $devVarBody
    
    # Staging
    $stagingRgBody = @{ name = 'RESOURCE_GROUP_NAME'; value = $stagingRgName } | ConvertTo-Json
    $stagingBackendAppBody = @{ name = 'BACKEND_APP_SERVICE_NAME'; value = $StagingBackendAppName } | ConvertTo-Json
    $stagingFrontendAppBody = @{ name = 'FRONTEND_APP_SERVICE_NAME'; value = $StagingFrontendAppName } | ConvertTo-Json
    
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/staging/variables/RESOURCE_GROUP_NAME" --input - <<< $stagingRgBody
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/staging/variables/BACKEND_APP_SERVICE_NAME" --input - <<< $stagingBackendAppBody
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/staging/variables/FRONTEND_APP_SERVICE_NAME" --input - <<< $stagingFrontendAppBody
    
    # Production
    $prodRgBody = @{ name = 'RESOURCE_GROUP_NAME'; value = $prodRgName } | ConvertTo-Json
    $prodBackendAppBody = @{ name = 'BACKEND_APP_SERVICE_NAME'; value = $ProdBackendAppName } | ConvertTo-Json
    $prodFrontendAppBody = @{ name = 'FRONTEND_APP_SERVICE_NAME'; value = $ProdFrontendAppName } | ConvertTo-Json
    
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/production/variables/RESOURCE_GROUP_NAME" --input - <<< $prodRgBody
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/production/variables/BACKEND_APP_SERVICE_NAME" --input - <<< $prodBackendAppBody
    gh api --method PUT "repos/$GitHubOwner/$GitHubRepo/environments/production/variables/FRONTEND_APP_SERVICE_NAME" --input - <<< $prodFrontendAppBody
    
    Write-Status "GitHub setup complete!"
}

# Main execution
function Main {
    Write-Header "TaskTracker CI/CD Setup"
    
    Test-Prerequisites
    Get-Configuration
    New-ManagedIdentity
    Set-GitHubConfiguration
    
    Write-Header "Setup Complete!"
    Write-Status "Your TaskTracker CI/CD pipeline is now configured for existing infrastructure!"
    Write-Status ""
    Write-Status "Next steps:"
    Write-Status "1. Ensure your Azure resources exist and are accessible"
    Write-Status "2. Push your code to the 'develop' branch to trigger a dev deployment"
    Write-Status "3. Create a PR from 'develop' to 'main' for staging deployment"
    Write-Status "4. Merge to 'main' to trigger staging and production deployments"
    Write-Status ""
    Write-Status "Configured Resources:"
    Write-Status "- Container Registry: $AcrRegistry"
    Write-Status "- Dev Environment: Uses Azure Container Instances (created dynamically)"
    Write-Status "- Staging Environment:"
    Write-Status "  Backend: https://$StagingBackendAppName.azurewebsites.net"
    Write-Status "  Frontend: https://$StagingFrontendAppName.azurewebsites.net"
    Write-Status "- Production Environment:"
    Write-Status "  Backend: https://$ProdBackendAppName.azurewebsites.net"
    Write-Status "  Frontend: https://$ProdFrontendAppName.azurewebsites.net"
}

# Run main function
Main