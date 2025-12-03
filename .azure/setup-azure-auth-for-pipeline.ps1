#!/usr/bin/env pwsh

# Azure Authentication Setup Script for GitHub Actions Pipeline
# This script creates a User-Assigned Managed Identity and configures federated credentials for OIDC authentication

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "a4ab3025-1b32-4394-92e0-d07c1ebf3787",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pipeline-auth",
    
    [Parameter(Mandatory=$false)]
    [string]$ManagedIdentityName = "tasktracker-pipeline-identity",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "wchigit/TaskTracker",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US 2"
)

Write-Host "🚀 Setting up Azure authentication for GitHub Actions pipeline..." -ForegroundColor Green

# Set the subscription
Write-Host "📋 Setting Azure subscription to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Create resource group for pipeline authentication resources
Write-Host "📁 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# Create User-Assigned Managed Identity
Write-Host "🔐 Creating User-Assigned Managed Identity: $ManagedIdentityName" -ForegroundColor Yellow
$identityResult = az identity create `
    --name $ManagedIdentityName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --output json | ConvertFrom-Json

$clientId = $identityResult.clientId
$principalId = $identityResult.principalId
$resourceId = $identityResult.id

Write-Host "✅ Created Managed Identity with Client ID: $clientId" -ForegroundColor Green

# Get tenant ID
$tenantId = (az account show --query tenantId -o tsv)
Write-Host "🏢 Tenant ID: $tenantId" -ForegroundColor Yellow

# Configure federated credentials for each environment
$environments = @('dev', 'staging', 'production')
foreach ($env in $environments) {
    Write-Host "🔗 Creating federated credential for environment: $env" -ForegroundColor Yellow
    
    $credentialName = "tasktracker-$env-credential"
    $subject = "repo:$($GitHubRepo):environment:$env"
    
    az identity federated-credential create `
        --name $credentialName `
        --identity-name $ManagedIdentityName `
        --resource-group $ResourceGroupName `
        --issuer "https://token.actions.githubusercontent.com" `
        --subject $subject `
        --audience "api://AzureADTokenExchange"
    
    Write-Host "✅ Created federated credential: $credentialName" -ForegroundColor Green
}

# Assign RBAC permissions to resource groups
$resourceGroups = @('rg-wcdev', 'rg-wcstaging', 'rg-wcproduction')
foreach ($rg in $resourceGroups) {
    Write-Host "🔒 Assigning Contributor role to resource group: $rg" -ForegroundColor Yellow
    
    az role assignment create `
        --assignee $principalId `
        --role "Contributor" `
        --scope "/subscriptions/$SubscriptionId/resourceGroups/$rg"
    
    Write-Host "✅ Assigned Contributor role to: $rg" -ForegroundColor Green
}

# Get ACR names and assign AcrPull permissions
$acrNames = @()
$resourceGroups | ForEach-Object {
    $acrs = az acr list --resource-group $_ --query "[].name" -o tsv
    if ($acrs) {
        $acrNames += $acrs
    }
}

foreach ($acrName in $acrNames) {
    Write-Host "🐳 Assigning AcrPull role to ACR: $acrName" -ForegroundColor Yellow
    
    az role assignment create `
        --assignee $principalId `
        --role "AcrPull" `
        --scope "/subscriptions/$SubscriptionId/resourceGroups/$(az acr show --name $acrName --query resourceGroup -o tsv)/providers/Microsoft.ContainerRegistry/registries/$acrName"
    
    Write-Host "✅ Assigned AcrPull role to ACR: $acrName" -ForegroundColor Green
}

# Output the values needed for GitHub secrets
Write-Host "

🎯 Configuration Complete! Use these values in your GitHub repository:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "AZURE_CLIENT_ID: $clientId" -ForegroundColor White
Write-Host "AZURE_TENANT_ID: $tenantId" -ForegroundColor White
Write-Host "AZURE_SUBSCRIPTION_ID: $SubscriptionId" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "

📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run the pipeline environment setup script: ./.azure/setup-pipeline-environment.ps1" -ForegroundColor White
Write-Host "2. The script will use these values to configure GitHub environments automatically" -ForegroundColor White

# Save credentials to a file for the next script
$credentials = @{
    AZURE_CLIENT_ID = $clientId
    AZURE_TENANT_ID = $tenantId
    AZURE_SUBSCRIPTION_ID = $SubscriptionId
}

$credentials | ConvertTo-Json | Out-File -FilePath "./.azure/auth-config.json" -Encoding UTF8
Write-Host "💾 Saved authentication config to ./.azure/auth-config.json" -ForegroundColor Green

Write-Host "

🎉 Azure authentication setup completed successfully!" -ForegroundColor Green