#!/usr/bin/env pwsh

# GitHub Pipeline Environment Setup Script
# This script configures GitHub environments, variables, and secrets for the CI/CD pipeline

param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "wchigit/TaskTracker",
    
    [Parameter(Mandatory=$false)]
    [string]$AuthConfigFile = "./.azure/auth-config.json"
)

Write-Host "🚀 Setting up GitHub environments and pipeline configuration..." -ForegroundColor Green

# Check if GitHub CLI is authenticated
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ GitHub CLI is not authenticated. Please run 'gh auth login' first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green

# Load authentication configuration
if (Test-Path $AuthConfigFile) {
    $authConfig = Get-Content $AuthConfigFile | ConvertFrom-Json
    Write-Host "✅ Loaded authentication configuration from $AuthConfigFile" -ForegroundColor Green
} else {
    Write-Host "❌ Authentication config file not found: $AuthConfigFile" -ForegroundColor Red
    Write-Host "Please run setup-azure-auth-for-pipeline.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Get ACR and resource information for each environment
$environments = @{
    'dev' = @{
        resourceGroup = 'rg-wcdev'
        acrName = 'acryqsta6dud5vi2'
    }
    'staging' = @{
        resourceGroup = 'rg-wcstaging'
        acrName = 'acroyid6zftjzu46'
    }
    'production' = @{
        resourceGroup = 'rg-wcproduction'
        acrName = 'acr6ia22terduzqo'
    }
}

# Create GitHub environments and configure variables
foreach ($envName in $environments.Keys) {
    $envConfig = $environments[$envName]
    
    Write-Host "🌍 Configuring GitHub environment: $envName" -ForegroundColor Yellow
    
    # Create the environment
    Write-Host "   📝 Creating environment: $envName" -ForegroundColor Cyan
    
    # Get current user for reviewers
    Write-Host "   👤 Getting current GitHub user for reviewers" -ForegroundColor Cyan
    try {
        $currentUser = gh api user --jq '.login'
        $currentUserId = gh api user --jq '.id'
        Write-Host "      ✅ Current GitHub user: $currentUser (ID: $currentUserId)" -ForegroundColor Green
    } catch {
        Write-Host "      ⚠️  Could not get current user, will create environment without reviewers" -ForegroundColor Yellow
        $currentUser = $null
        $currentUserId = $null
    }
    
    # Create environment with protection rules
    $envBody = @{
        wait_timer = 0
        deployment_branch_policy = @{
            protected_branches = $true
            custom_branch_policies = $false
        }
    }
    
    # Add reviewers if we have user info
    if ($currentUserId) {
        $envBody.reviewers = @(
            @{
                type = "User"
                id = [int]$currentUserId
            }
        )
    } else {
        $envBody.reviewers = @()
    }
    
    if ($envName -eq 'production') {
        Write-Host "   🔒 Adding protection rules for production environment" -ForegroundColor Yellow
        $envBody.wait_timer = 5  # 5 minute wait timer for production
    }
    
    try {
        $envBodyJson = $envBody | ConvertTo-Json -Depth 3
        $result = $envBodyJson | gh api "repos/$GitHubRepo/environments/$envName" --method PUT --input -
        Write-Host "   ✅ Environment '$envName' created/updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Environment creation had issues, but continuing with variables..." -ForegroundColor Yellow
        Write-Host "      Error: $_" -ForegroundColor Red
    }
    
    # Set environment variables
    Write-Host "   📋 Setting environment variables for: $envName" -ForegroundColor Cyan
    
    $variables = @{
        'AZURE_CLIENT_ID' = $authConfig.AZURE_CLIENT_ID
        'AZURE_TENANT_ID' = $authConfig.AZURE_TENANT_ID
        'AZURE_SUBSCRIPTION_ID' = $authConfig.AZURE_SUBSCRIPTION_ID
        'RESOURCE_GROUP' = $envConfig.resourceGroup
        'ACR_NAME' = $envConfig.acrName
        'BACKEND_APP_NAME' = 'backend'
        'FRONTEND_APP_NAME' = 'frontend'
    }
    
    # No application-level variables needed in pipeline
    # Application environment variables should be configured directly in Container Apps
    
    foreach ($varName in $variables.Keys) {
        $varValue = $variables[$varName]
        
        try {
            # Use gh variable set command for environment variables
            gh variable set $varName --body $varValue --env $envName --repo $GitHubRepo
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      ✅ Set variable: $varName" -ForegroundColor Green
            } else {
                Write-Host "      ❌ Failed to set variable: $varName (exit code: $LASTEXITCODE)" -ForegroundColor Red
            }
        } catch {
            Write-Host "      ❌ Failed to set variable: $varName" -ForegroundColor Red
            Write-Host "         Error: $_" -ForegroundColor Red
        }
    }
}

Write-Host "

🎯 Configuration Summary:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Created/Updated 3 GitHub environments: dev, staging, production" -ForegroundColor Green
Write-Host "✅ Configured environment variables for all environments" -ForegroundColor Green
Write-Host "✅ Set up OIDC authentication configuration" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "

📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update the environment variable values as needed" -ForegroundColor White
Write-Host "2. Push code to 'develop' branch to test dev deployment" -ForegroundColor White
Write-Host "3. Push code to 'main' branch to test staging → production pipeline" -ForegroundColor White

Write-Host "

🎉 GitHub pipeline environment setup completed!" -ForegroundColor Green

# Clean up the auth config file
if (Test-Path $AuthConfigFile) {
    Remove-Item $AuthConfigFile -Force
    Write-Host "🧹 Cleaned up temporary auth config file" -ForegroundColor Green
}