# PowerShell script to set up CI/CD pipeline for TaskTracker
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubOrg = "wchigit",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "TaskTracker"
)

Write-Host "🚀 Setting up CI/CD pipeline for TaskTracker" -ForegroundColor Green
Write-Host "Environment: $EnvironmentName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Yellow

# Set variables
$RESOURCE_GROUP_NAME = "rg-tasktracker-$EnvironmentName"
$MI_NAME = "mi-tasktracker-$EnvironmentName-cicd"

try {
    # Login to Azure (if not already logged in)
    Write-Host "🔐 Checking Azure login..." -ForegroundColor Blue
    $currentAccount = az account show --query id -o tsv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Please login to Azure first: az login" -ForegroundColor Red
        exit 1
    }

    # Set subscription
    Write-Host "📋 Setting subscription..." -ForegroundColor Blue
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to set subscription" -ForegroundColor Red
        exit 1
    }

    # Create resource group
    Write-Host "🏗️  Creating resource group: $RESOURCE_GROUP_NAME" -ForegroundColor Blue
    az group create --name $RESOURCE_GROUP_NAME --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create resource group" -ForegroundColor Red
        exit 1
    }

    # Create user-assigned managed identity
    Write-Host "🆔 Creating managed identity: $MI_NAME" -ForegroundColor Blue
    az identity create --name $MI_NAME --resource-group $RESOURCE_GROUP_NAME --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create managed identity" -ForegroundColor Red
        exit 1
    }

    # Get managed identity details
    Write-Host "📝 Getting managed identity details..." -ForegroundColor Blue
    $MI_CLIENT_ID = az identity show --name $MI_NAME --resource-group $RESOURCE_GROUP_NAME --query clientId -o tsv
    $MI_PRINCIPAL_ID = az identity show --name $MI_NAME --resource-group $RESOURCE_GROUP_NAME --query principalId -o tsv
    $AZURE_TENANT_ID = az account show --query tenantId -o tsv

    if (-not $MI_CLIENT_ID -or -not $MI_PRINCIPAL_ID) {
        Write-Host "Failed to get managed identity details" -ForegroundColor Red
        exit 1
    }

    # Assign roles to managed identity
    Write-Host "🔑 Assigning Contributor role..." -ForegroundColor Blue
    az role assignment create --assignee $MI_PRINCIPAL_ID --role "Contributor" --scope "/subscriptions/$SubscriptionId/resourceGroups/$RESOURCE_GROUP_NAME"
    
    Write-Host "🔑 Assigning Owner role (for role assignments)..." -ForegroundColor Blue  
    az role assignment create --assignee $MI_PRINCIPAL_ID --role "Owner" --scope "/subscriptions/$SubscriptionId/resourceGroups/$RESOURCE_GROUP_NAME"

    # Create federated credentials for GitHub Actions
    Write-Host "🔗 Creating federated credentials..." -ForegroundColor Blue
    
    # For main branch
    az identity federated-credential create `
        --name "tasktracker-main-branch" `
        --identity-name $MI_NAME `
        --resource-group $RESOURCE_GROUP_NAME `
        --issuer "https://token.actions.githubusercontent.com" `
        --subject "repo:$GitHubOrg/$GitHubRepo`:ref:refs/heads/main" `
        --audience "api://AzureADTokenExchange"

    # For pull requests  
    az identity federated-credential create `
        --name "tasktracker-pr" `
        --identity-name $MI_NAME `
        --resource-group $RESOURCE_GROUP_NAME `
        --issuer "https://token.actions.githubusercontent.com" `
        --subject "repo:$GitHubOrg/$GitHubRepo`:pull_request" `
        --audience "api://AzureADTokenExchange"

    Write-Host "✅ Azure setup completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 GitHub Configuration Values:" -ForegroundColor Cyan
    Write-Host "AZURE_CLIENT_ID: $MI_CLIENT_ID" -ForegroundColor White
    Write-Host "AZURE_TENANT_ID: $AZURE_TENANT_ID" -ForegroundColor White  
    Write-Host "AZURE_SUBSCRIPTION_ID: $SubscriptionId" -ForegroundColor White
    Write-Host "AZURE_ENV_NAME: $EnvironmentName" -ForegroundColor White
    Write-Host "AZURE_LOCATION: $Location" -ForegroundColor White
    Write-Host "AZURE_RESOURCE_GROUP: $RESOURCE_GROUP_NAME" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Navigate to your repository: cd 'c:\dev\samplerepo\TaskTracker'" -ForegroundColor White
    Write-Host "2. Set GitHub variables:" -ForegroundColor White
    Write-Host "   gh variable set AZURE_CLIENT_ID --body $MI_CLIENT_ID" -ForegroundColor Gray
    Write-Host "   gh variable set AZURE_TENANT_ID --body $AZURE_TENANT_ID" -ForegroundColor Gray
    Write-Host "   gh variable set AZURE_SUBSCRIPTION_ID --body $SubscriptionId" -ForegroundColor Gray
    Write-Host "   gh variable set AZURE_ENV_NAME --body $EnvironmentName" -ForegroundColor Gray
    Write-Host "   gh variable set AZURE_LOCATION --body $Location" -ForegroundColor Gray
    Write-Host "   gh variable set AZURE_RESOURCE_GROUP --body $RESOURCE_GROUP_NAME" -ForegroundColor Gray
    Write-Host "3. Push your code to trigger the pipeline!" -ForegroundColor White

} catch {
    Write-Host "❌ Error occurred: $_" -ForegroundColor Red
    exit 1
}