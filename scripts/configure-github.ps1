# PowerShell script to configure GitHub repository variables and secrets
param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-tasktracker-dev"
)

Write-Host "🔧 Configuring GitHub repository for CI/CD" -ForegroundColor Green

try {
    # Check if GitHub CLI is installed and authenticated
    Write-Host "🔐 Checking GitHub CLI authentication..." -ForegroundColor Blue
    $ghUser = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Please authenticate with GitHub CLI first: gh auth login" -ForegroundColor Red
        exit 1
    }

    # Set repository variables
    Write-Host "📝 Setting GitHub repository variables..." -ForegroundColor Blue
    
    gh variable set AZURE_CLIENT_ID --body $ClientId
    Write-Host "✓ Set AZURE_CLIENT_ID" -ForegroundColor Green
    
    gh variable set AZURE_TENANT_ID --body $TenantId
    Write-Host "✓ Set AZURE_TENANT_ID" -ForegroundColor Green
    
    gh variable set AZURE_SUBSCRIPTION_ID --body $SubscriptionId
    Write-Host "✓ Set AZURE_SUBSCRIPTION_ID" -ForegroundColor Green
    
    gh variable set AZURE_ENV_NAME --body $EnvironmentName
    Write-Host "✓ Set AZURE_ENV_NAME" -ForegroundColor Green
    
    gh variable set AZURE_LOCATION --body $Location
    Write-Host "✓ Set AZURE_LOCATION" -ForegroundColor Green
    
    gh variable set AZURE_RESOURCE_GROUP --body $ResourceGroup
    Write-Host "✓ Set AZURE_RESOURCE_GROUP" -ForegroundColor Green

    # Verify variables are set
    Write-Host ""
    Write-Host "📋 Verifying GitHub variables:" -ForegroundColor Blue
    gh variable list

    Write-Host ""
    Write-Host "✅ GitHub configuration completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Push your code to the main branch to trigger the pipeline" -ForegroundColor White
    Write-Host "2. Monitor the deployment at: https://github.com/wchigit/TaskTracker/actions" -ForegroundColor White
    Write-Host "3. Check Azure portal for deployed resources" -ForegroundColor White

} catch {
    Write-Host "❌ Error occurred: $_" -ForegroundColor Red
    exit 1
}