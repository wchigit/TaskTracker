# Federated Identity (OpenID Connect) Setup Guide

## 🔐 Setting Up Secure Authentication with Federated Credentials

Federated credentials are more secure than storing secrets because:
- ✅ **No secrets stored in GitHub**
- ✅ **Tokens are short-lived and automatically rotated**
- ✅ **Uses Azure AD's trust relationship with GitHub**
- ✅ **No client secret expiration issues**

## Step-by-Step Setup

### 1. Create App Registration and Service Principal

```bash
# Set your variables (replace with your values)
$subscriptionId = "a4ab3025-1b32-4394-92e0-d07c1ebf3787"
$githubOrg = "wchigit"  # Your GitHub username/organization
$githubRepo = "TaskTracker"  # Your repository name

# Create app registration
$appId = az ad app create --display-name "TaskTracker-GitHub-OIDC" --query appId -o tsv
Write-Host "Created App Registration with ID: $appId"

# Create service principal
az ad sp create --id $appId
Write-Host "Created Service Principal"

# Get tenant ID
$tenantId = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $tenantId"
```

### 2. Configure Federated Credentials

```bash
# Create federated credential for main branch
az ad app federated-credential create --id $appId --parameters @"
{
    "name": "TaskTracker-GitHub-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:$githubOrg/$githubRepo:ref:refs/heads/main",
    "description": "GitHub Actions for TaskTracker main branch",
    "audiences": ["api://AzureADTokenExchange"]
}
"@

# Create federated credential for develop branch  
az ad app federated-credential create --id $appId --parameters @"
{
    "name": "TaskTracker-GitHub-Develop", 
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:$githubOrg/$githubRepo:ref:refs/heads/develop",
    "description": "GitHub Actions for TaskTracker develop branch",
    "audiences": ["api://AzureADTokenExchange"]
}
"@

# Create federated credential for pull requests
az ad app federated-credential create --id $appId --parameters @"
{
    "name": "TaskTracker-GitHub-PR",
    "issuer": "https://token.actions.githubusercontent.com", 
    "subject": "repo:$githubOrg/$githubRepo:pull_request",
    "description": "GitHub Actions for TaskTracker pull requests",
    "audiences": ["api://AzureADTokenExchange"]
}
"@
```

### 3. Grant Azure Permissions

```bash
# Grant Contributor role to the subscription
az role assignment create \
  --assignee $appId \
  --role "Contributor" \
  --scope "/subscriptions/$subscriptionId"

Write-Host "✅ Setup complete!"
Write-Host "App ID (Client ID): $appId"
Write-Host "Tenant ID: $tenantId"  
Write-Host "Subscription ID: $subscriptionId"
```

### 4. Configure GitHub Repository Variables

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **Variables** tab

Add these **Repository Variables**:
- `AZURE_CLIENT_ID`: `<your-app-id-from-step1>`
- `AZURE_TENANT_ID`: `<your-tenant-id-from-step1>`
- `AZURE_SUBSCRIPTION_ID`: `a4ab3025-1b32-4394-92e0-d07c1ebf3787`

**No secrets needed!** 🎉

## 🔄 Alternative: One-Command Setup

If you prefer a single script, save this as `setup-federated-auth.ps1`:

```powershell
# Complete setup script
param(
    [string]$SubscriptionId = "a4ab3025-1b32-4394-92e0-d07c1ebf3787",
    [string]$GitHubOrg = "wchigit",
    [string]$GitHubRepo = "TaskTracker"
)

Write-Host "🚀 Setting up federated identity for $GitHubOrg/$GitHubRepo"

# Create app registration
$appId = az ad app create --display-name "TaskTracker-GitHub-OIDC" --query appId -o tsv
az ad sp create --id $appId

# Get tenant ID  
$tenantId = az account show --query tenantId -o tsv

# Create federated credentials for different scenarios
$credentials = @(
    @{ name = "main"; subject = "repo:$GitHubOrg/$GitHubRepo:ref:refs/heads/main" },
    @{ name = "develop"; subject = "repo:$GitHubOrg/$GitHubRepo:ref:refs/heads/develop" },
    @{ name = "pr"; subject = "repo:$GitHubOrg/$GitHubRepo:pull_request" }
)

foreach ($cred in $credentials) {
    $params = @{
        name = "TaskTracker-GitHub-$($cred.name)"
        issuer = "https://token.actions.githubusercontent.com"
        subject = $cred.subject
        description = "GitHub Actions for TaskTracker $($cred.name)"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json

    az ad app federated-credential create --id $appId --parameters $params
}

# Grant permissions
az role assignment create --assignee $appId --role "Contributor" --scope "/subscriptions/$SubscriptionId"

Write-Host "✅ Setup Complete!"
Write-Host ""
Write-Host "🔗 Add these to your GitHub repository variables:"
Write-Host "   AZURE_CLIENT_ID: $appId"
Write-Host "   AZURE_TENANT_ID: $tenantId"  
Write-Host "   AZURE_SUBSCRIPTION_ID: $SubscriptionId"
```

Then run: `.\setup-federated-auth.ps1`

## 🧪 Test the Setup

1. **Commit and push** your workflow file
2. **Go to Actions tab** in GitHub
3. **Run the workflow** manually or push to main/develop
4. **Verify authentication** works without any stored secrets

## 🔍 Troubleshooting

**Common Issues:**

1. **Invalid subject claim**
   ```bash
   # Check your federated credentials
   az ad app federated-credential list --id $appId
   ```

2. **Wrong repository path**
   - Make sure the subject matches exactly: `repo:wchigit/TaskTracker:ref:refs/heads/main`
   - Case-sensitive repository and organization names

3. **Missing permissions**
   ```bash
   # Verify role assignment
   az role assignment list --assignee $appId
   ```

## ✨ Benefits of This Setup

- 🔒 **More Secure**: No long-lived secrets in GitHub
- 🔄 **Auto-rotating**: Tokens expire quickly and renew automatically  
- 🎯 **Granular Control**: Different credentials for different branches
- 🚀 **Zero Maintenance**: No secret expiration to worry about
- ✅ **Azure Best Practice**: Recommended by Microsoft

Your workflow is now configured to use the most secure authentication method available!