# Setup Azure Authentication for GitHub Actions Pipeline
# This script creates a User-assigned Managed Identity and configures federated credentials for OIDC authentication

param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "a4ab3025-1b32-4394-92e0-d07c1ebf3787",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupForIdentity = "rg-pipeline-identity",
    
    [Parameter(Mandatory = $false)]
    [string]$ManagedIdentityName = "mi-tasktracker-pipeline",
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg = "wchigit",
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubRepo = "TaskTracker",
    
    [Parameter(Mandatory = $false)]
    [string]$DevAcrName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$StagingAcrName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$ProductionAcrName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US 2"
)

# Validate required parameters
$missingAcrParams = @()
if ([string]::IsNullOrEmpty($DevAcrName)) { $missingAcrParams += "DevAcrName" }
if ([string]::IsNullOrEmpty($StagingAcrName)) { $missingAcrParams += "StagingAcrName" }
if ([string]::IsNullOrEmpty($ProductionAcrName)) { $missingAcrParams += "ProductionAcrName" }

if ($missingAcrParams.Count -gt 0) {
    Write-Host "ERROR: ACR Names are required for all environments. Missing:" -ForegroundColor Red
    foreach ($param in $missingAcrParams) {
        Write-Host "  -$param" -ForegroundColor Red
    }
    Write-Host "Example: .\setup-azure-auth-for-pipeline.ps1 -DevAcrName 'acr-dev' -StagingAcrName 'acr-staging' -ProductionAcrName 'acr-prod'"
    exit 1
}

Write-Host "=== Setting up Azure Authentication for TaskTracker Pipeline ===" -ForegroundColor Green
Write-Host "Subscription ID: $SubscriptionId"
Write-Host "Resource Group for Identity: $ResourceGroupForIdentity"
Write-Host "Managed Identity Name: $ManagedIdentityName"
Write-Host "GitHub Org/Owner: $GitHubOrg"
Write-Host "GitHub Repository: $GitHubRepo"
Write-Host "Dev ACR Name: $DevAcrName"
Write-Host "Staging ACR Name: $StagingAcrName"
Write-Host "Production ACR Name: $ProductionAcrName"
Write-Host ""

# Set Azure subscription
Write-Host "Setting Azure subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to set subscription. Please check your Azure CLI login and subscription ID." -ForegroundColor Red
    exit 1
}

# Create resource group for the managed identity (if it doesn't exist)
Write-Host "Creating resource group for managed identity..." -ForegroundColor Yellow
az group create --name $ResourceGroupForIdentity --location $Location --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create resource group." -ForegroundColor Red
    exit 1
}

# Create User-assigned Managed Identity
Write-Host "Creating User-assigned Managed Identity..." -ForegroundColor Yellow
$identityResult = az identity create --name $ManagedIdentityName --resource-group $ResourceGroupForIdentity --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create managed identity." -ForegroundColor Red
    exit 1
}

$clientId = $identityResult.clientId
$principalId = $identityResult.principalId
$tenantId = (az account show --query tenantId --output tsv)

Write-Host "Managed Identity created successfully!" -ForegroundColor Green
Write-Host "Client ID: $clientId"
Write-Host "Principal ID: $principalId"
Write-Host "Tenant ID: $tenantId"
Write-Host ""

# Create federated credentials for different environments
Write-Host "Creating federated credentials..." -ForegroundColor Yellow

# Dev environment (develop branch)
$devCredential = @{
    name = "fc-tasktracker-dev"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$GitHubOrg/$GitHubRepo:environment:dev"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 10

az identity federated-credential create --name "fc-tasktracker-dev" --identity-name $ManagedIdentityName --resource-group $ResourceGroupForIdentity --issuer "https://token.actions.githubusercontent.com" --subject "repo:$GitHubOrg/$($GitHubRepo):environment:dev" --audiences "api://AzureADTokenExchange"

# Staging environment (main branch)
az identity federated-credential create --name "fc-tasktracker-staging" --identity-name $ManagedIdentityName --resource-group $ResourceGroupForIdentity --issuer "https://token.actions.githubusercontent.com" --subject "repo:$GitHubOrg/$($GitHubRepo):environment:staging" --audiences "api://AzureADTokenExchange"

# Production environment (main branch)
az identity federated-credential create --name "fc-tasktracker-production" --identity-name $ManagedIdentityName --resource-group $ResourceGroupForIdentity --issuer "https://token.actions.githubusercontent.com" --subject "repo:$GitHubOrg/$($GitHubRepo):environment:production" --audiences "api://AzureADTokenExchange"

Write-Host "Federated credentials created successfully!" -ForegroundColor Green
Write-Host ""

# Assign RBAC permissions
Write-Host "Assigning RBAC permissions..." -ForegroundColor Yellow

# Contributor role for resource groups
$resourceGroups = @("rg-wcdev", "rg-wcstaging", "rg-wcproduction")
foreach ($rg in $resourceGroups) {
    Write-Host "Assigning Contributor role for $rg..."
    az role assignment create --assignee $principalId --role "Contributor" --scope "/subscriptions/$SubscriptionId/resourceGroups/$rg"
}

# AcrPull/AcrPush roles for all Azure Container Registries
$acrNames = @($DevAcrName, $StagingAcrName, $ProductionAcrName)
$acrEnvironments = @("Dev", "Staging", "Production")

for ($i = 0; $i -lt $acrNames.Count; $i++) {
    $acrName = $acrNames[$i]
    $envName = $acrEnvironments[$i]
    
    Write-Host "Assigning ACR permissions for $envName environment ($acrName)..."
    $acrResourceId = az acr show --name $acrName --query id --output tsv 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $acrResourceId) {
        az role assignment create --assignee $principalId --role "AcrPull" --scope $acrResourceId --output none
        az role assignment create --assignee $principalId --role "AcrPush" --scope $acrResourceId --output none
        Write-Host "  ✓ ACR permissions assigned for $envName" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ WARNING: Could not find ACR '$acrName' for $envName. Please verify the name and assign AcrPull/AcrPush roles manually." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== IMPORTANT: Save these values for GitHub secrets ===" -ForegroundColor Cyan
Write-Host "AZURE_CLIENT_ID: $clientId" -ForegroundColor White
Write-Host "AZURE_TENANT_ID: $tenantId" -ForegroundColor White
Write-Host "AZURE_SUBSCRIPTION_ID: $SubscriptionId" -ForegroundColor White
Write-Host ""
Write-Host "Next step: Run setup-pipeline-environment.ps1 to configure GitHub environments and variables." -ForegroundColor Green