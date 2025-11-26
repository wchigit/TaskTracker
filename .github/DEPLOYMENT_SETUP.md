# GitHub Actions CI/CD Pipeline Setup Guide

This guide walks you through setting up automated build and deployment for your TaskTracker application using GitHub Actions and Azure Developer CLI.

## Prerequisites

1. **GitHub Repository**: Your code should be pushed to a GitHub repository
2. **Azure Subscription**: Active Azure subscription with appropriate permissions
3. **Azure CLI**: For initial setup commands

## Step-by-Step Setup

### 1. Create Service Principal for GitHub Actions

Run these commands in your terminal to create a service principal for GitHub Actions:

```bash
# Set variables (replace with your values)
$subscriptionId = "a4ab3025-1b32-4394-92e0-d07c1ebf3787"
$resourceGroup = "rg-tasktracker"  # Your resource group name
$servicePrincipalName = "sp-tasktracker-github"

# Create service principal
az ad sp create-for-rbac --name $servicePrincipalName --role contributor --scopes /subscriptions/$subscriptionId --sdk-auth
```

**Save the output JSON** - you'll need it for GitHub secrets!

### 2. Configure GitHub Repository Settings

#### A. Set up Repository Variables
Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **Variables** tab

Add these **Repository Variables**:
- `AZURE_ENV_NAME`: `tasktracker-prod` (or your preferred environment name)
- `AZURE_LOCATION`: `northeurope` (or your preferred Azure region)  
- `AZURE_SUBSCRIPTION_ID`: `a4ab3025-1b32-4394-92e0-d07c1ebf3787`

#### B. Set up Repository Secrets  
Go to **Secrets** tab and add:
- `AZURE_CREDENTIALS`: Paste the entire JSON output from step 1

### 3. Create GitHub Environment (Optional but Recommended)

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name it `production`
4. Add protection rules if desired (e.g., require reviews for deployment)

### 4. Alternative: Use Federated Identity (More Secure)

Instead of using client secrets, you can set up OpenID Connect:

```bash
# Create app registration
$appId = az ad app create --display-name "TaskTracker-GitHub" --query appId -o tsv

# Create service principal
az ad sp create --id $appId

# Add federated credential for GitHub Actions
az ad app federated-credential create --id $appId --parameters '{
    "name": "TaskTracker-GitHub-Actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_USERNAME/TaskTracker:ref:refs/heads/main",
    "description": "GitHub Actions for TaskTracker",
    "audiences": ["api://AzureADTokenExchange"]
}'

# Grant permissions
az role assignment create --assignee $appId --role contributor --scope /subscriptions/$subscriptionId
```

For federated identity, use these **Variables** instead:
- `AZURE_CLIENT_ID`: The application (client) ID
- `AZURE_TENANT_ID`: Your Azure tenant ID

## 5. Test the Pipeline

### Manual Trigger
1. Go to **Actions** tab in your GitHub repository
2. Select "Azure Dev CLI - Deploy TaskTracker" workflow  
3. Click **Run workflow** to test manually

### Automatic Trigger
- Push changes to `main` or `develop` branch
- Create a pull request to `main` branch

## 6. Pipeline Features

✅ **Automated Build**: Builds Docker containers for both backend and frontend  
✅ **Infrastructure Provisioning**: Creates/updates Azure resources using Bicep  
✅ **Application Deployment**: Deploys containers to Azure Container Apps  
✅ **Security**: Uses managed identity and secure authentication  
✅ **Multi-Environment**: Easy to extend for dev/staging/prod environments

## 7. Monitoring Deployment

After pipeline runs:
1. Check the **Actions** tab for build/deploy status
2. Visit Azure Portal to verify resources
3. Test your application endpoints:
   - Frontend: `https://<your-frontend-url>.azurecontainerapps.io/`
   - Backend API: `https://<your-backend-url>.azurecontainerapps.io/docs`

## 8. Environment-Specific Deployments

To deploy to different environments, create additional workflow files:
- `.github/workflows/deploy-dev.yml` (triggers on develop branch)
- `.github/workflows/deploy-staging.yml` (triggers on release branches)

## Troubleshooting

**Common Issues:**
- **Permission Errors**: Ensure service principal has Contributor role
- **Resource Naming**: Check for naming conflicts in Azure
- **Quota Limits**: Verify Azure subscription quotas for Container Apps
- **Secret Expiry**: Service principal secrets expire after 2 years by default

**Debug Steps:**
1. Check GitHub Actions logs for detailed error messages
2. Verify Azure credentials are correctly configured  
3. Run `azd provision` locally to test infrastructure templates
4. Check Azure Portal for resource deployment status

## Next Steps

- Set up branch protection rules for main branch
- Add automated testing before deployment
- Configure monitoring and alerting
- Set up staging environments for testing