# Setup GitHub Actions Pipeline Environment
# This script creates GitHub environments and configures variables and secrets

param(
    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg = "wchigit",
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubRepo = "TaskTracker",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "a4ab3025-1b32-4394-92e0-d07c1ebf3787",
    
    # These need to be provided by the user - update with your actual resource names
    [Parameter(Mandatory = $false)]
    [string]$DevAcrName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$StagingAcrName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$ProductionAcrName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$DevBackendAppName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$DevFrontendAppName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$StagingBackendAppName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$StagingFrontendAppName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$ProductionBackendAppName = "",  # User must provide this
    
    [Parameter(Mandatory = $false)]
    [string]$ProductionFrontendAppName = "",  # User must provide this
    
    # Managed Identity details (should match setup-azure-auth-for-pipeline.ps1)
    [Parameter(Mandatory = $false)]
    [string]$ClientId = "",  # User must provide this from previous script
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId = ""  # User must provide this from previous script
)

# Validate required parameters
$missingParams = @()
if ([string]::IsNullOrEmpty($DevAcrName)) { $missingParams += "DevAcrName" }
if ([string]::IsNullOrEmpty($StagingAcrName)) { $missingParams += "StagingAcrName" }
if ([string]::IsNullOrEmpty($ProductionAcrName)) { $missingParams += "ProductionAcrName" }
if ([string]::IsNullOrEmpty($DevBackendAppName)) { $missingParams += "DevBackendAppName" }
if ([string]::IsNullOrEmpty($DevFrontendAppName)) { $missingParams += "DevFrontendAppName" }
if ([string]::IsNullOrEmpty($StagingBackendAppName)) { $missingParams += "StagingBackendAppName" }
if ([string]::IsNullOrEmpty($StagingFrontendAppName)) { $missingParams += "StagingFrontendAppName" }
if ([string]::IsNullOrEmpty($ProductionBackendAppName)) { $missingParams += "ProductionBackendAppName" }
if ([string]::IsNullOrEmpty($ProductionFrontendAppName)) { $missingParams += "ProductionFrontendAppName" }
if ([string]::IsNullOrEmpty($ClientId)) { $missingParams += "ClientId" }
if ([string]::IsNullOrEmpty($TenantId)) { $missingParams += "TenantId" }

if ($missingParams.Count -gt 0) {
    Write-Host "ERROR: Missing required parameters:" -ForegroundColor Red
    foreach ($param in $missingParams) {
        Write-Host "  -$param" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Example usage:" -ForegroundColor Yellow
    Write-Host ".\setup-pipeline-environment.ps1 -DevAcrName 'acr-dev' -StagingAcrName 'acr-staging' -ProductionAcrName 'acr-prod' -DevBackendAppName 'ca-tasktracker-backend-dev' -DevFrontendAppName 'ca-tasktracker-frontend-dev' -StagingBackendAppName 'ca-tasktracker-backend-staging' -StagingFrontendAppName 'ca-tasktracker-frontend-staging' -ProductionBackendAppName 'ca-tasktracker-backend-prod' -ProductionFrontendAppName 'ca-tasktracker-frontend-prod' -ClientId 'your-client-id' -TenantId 'your-tenant-id'"
    exit 1
}

Write-Host "=== Setting up GitHub Pipeline Environment ===" -ForegroundColor Green
Write-Host "GitHub Repository: $GitHubOrg/$GitHubRepo"
Write-Host "Subscription ID: $SubscriptionId"
Write-Host "Dev ACR Name: $DevAcrName"
Write-Host "Staging ACR Name: $StagingAcrName"
Write-Host "Production ACR Name: $ProductionAcrName"
Write-Host ""

# Check if GitHub CLI is authenticated
Write-Host "Checking GitHub CLI authentication..." -ForegroundColor Yellow
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: GitHub CLI is not authenticated. Please run 'gh auth login' first." -ForegroundColor Red
    exit 1
}

# Environment configurations
$environments = @(
    @{
        Name = "dev"
        ResourceGroup = "rg-wcdev"
        AcrName = $DevAcrName
        BackendAppName = $DevBackendAppName
        FrontendAppName = $DevFrontendAppName
        RequiresApproval = $false
    },
    @{
        Name = "staging"
        ResourceGroup = "rg-wcstaging"
        AcrName = $StagingAcrName
        BackendAppName = $StagingBackendAppName
        FrontendAppName = $StagingFrontendAppName
        RequiresApproval = $false  # Set to $true if you want manual approval for staging
    },
    @{
        Name = "production"
        ResourceGroup = "rg-wcproduction"
        AcrName = $ProductionAcrName
        BackendAppName = $ProductionBackendAppName
        FrontendAppName = $ProductionFrontendAppName
        RequiresApproval = $true
    }
)

# Create or update environments
foreach ($env in $environments) {
    Write-Host "Setting up environment: $($env.Name)" -ForegroundColor Yellow
    
    # Create environment using GitHub API (gh CLI doesn't have direct environment creation)
    $envData = @{
        wait_timer = 0
        reviewers = @()
        deployment_branch_policy = $null
    } | ConvertTo-Json -Depth 10
    
    # Create environment
    $createResult = $envData | gh api --method PUT "repos/$GitHubOrg/$GitHubRepo/environments/$($env.Name)" --input - 2>&1
    
    # Set environment variables
    Write-Host "Setting environment variables for $($env.Name)..."
    
    gh variable set ACR_NAME --env $($env.Name) --body $($env.AcrName) --repo "$GitHubOrg/$GitHubRepo"
    gh variable set RESOURCE_GROUP --env $($env.Name) --body $($env.ResourceGroup) --repo "$GitHubOrg/$GitHubRepo"
    gh variable set BACKEND_APP_NAME --env $($env.Name) --body $($env.BackendAppName) --repo "$GitHubOrg/$GitHubRepo"
    gh variable set FRONTEND_APP_NAME --env $($env.Name) --body $($env.FrontendAppName) --repo "$GitHubOrg/$GitHubRepo"
    
    Write-Host "Environment $($env.Name) configured successfully!" -ForegroundColor Green
}

# Set repository-level variables (shared across environments)
Write-Host "Setting repository-level variables..." -ForegroundColor Yellow
gh variable set AZURE_SUBSCRIPTION_ID --body $SubscriptionId --repo "$GitHubOrg/$GitHubRepo"

Write-Host "Repository variables set successfully!" -ForegroundColor Green
Write-Host ""

# Set repository secrets
Write-Host "Setting repository secrets..." -ForegroundColor Yellow
gh secret set AZURE_CLIENT_ID --body $ClientId --repo "$GitHubOrg/$GitHubRepo"
gh secret set AZURE_TENANT_ID --body $TenantId --repo "$GitHubOrg/$GitHubRepo"

Write-Host "Repository secrets set successfully!" -ForegroundColor Green
Write-Host ""

# Configure environment protection rules for production
Write-Host "Configuring production environment protection..." -ForegroundColor Yellow
$protectionData = @{
    wait_timer = 5
    reviewers = @(
        @{
            type = "User"
            id = $null  # Will need to be set manually or retrieved via API
        }
    )
} | ConvertTo-Json -Depth 10

# Note: Setting up reviewers requires user IDs which need to be retrieved separately
Write-Host "WARNING: Production environment protection rules need to be configured manually in GitHub." -ForegroundColor Yellow
Write-Host "Go to: https://github.com/$GitHubOrg/$GitHubRepo/settings/environments/production" -ForegroundColor Yellow
Write-Host "1. Enable 'Required reviewers' and add yourself as a reviewer" -ForegroundColor Yellow
Write-Host "2. Optionally set a wait timer" -ForegroundColor Yellow
Write-Host ""

Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Summary of configured environments:" -ForegroundColor Cyan
foreach ($env in $environments) {
    Write-Host "  $($env.Name):" -ForegroundColor White
    Write-Host "    Resource Group: $($env.ResourceGroup)" -ForegroundColor Gray
    Write-Host "    Backend App: $($env.BackendAppName)" -ForegroundColor Gray
    Write-Host "    Frontend App: $($env.FrontendAppName)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Verify all Container Apps exist in the specified resource groups" -ForegroundColor White
Write-Host "2. Test the pipeline by pushing to the develop branch" -ForegroundColor White
Write-Host "3. Configure production environment reviewers in GitHub settings" -ForegroundColor White