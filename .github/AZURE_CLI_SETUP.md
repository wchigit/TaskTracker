# Azure CLI Workflow Setup Guide

## 🚀 Quick Setup for Azure CLI Deployment

The Azure CLI workflow file has been fixed and is ready to use. Here's how to set it up:

### 1. Create Service Principal

Run this command in your terminal (replace with your subscription ID):

```bash
az ad sp create-for-rbac \
  --name "sp-tasktracker-github" \
  --role contributor \
  --scopes /subscriptions/a4ab3025-1b32-4394-92e0-d07c1ebf3787 \
  --sdk-auth
```

**Save the JSON output** - you'll need it in step 2!

### 2. Configure GitHub Repository

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_CREDENTIALS`
5. Value: Paste the entire JSON from step 1
6. Click **Add secret**

### 3. Test the Workflow

1. Go to **Actions** tab in your GitHub repository
2. Find "Azure CLI - Deploy TaskTracker" workflow
3. Click **Run workflow** → **Run workflow**
4. Watch it deploy your application!

## ✅ Fixed Issues

The workflow file now has:
- ✅ **Correct syntax** for GitHub Actions
- ✅ **Simplified authentication** using service principal
- ✅ **Proper conditional logic** 
- ✅ **Error handling** for missing variables

## 🔧 What the Workflow Does

1. **Builds Docker images** for backend and frontend
2. **Deploys infrastructure** using your Bicep templates
3. **Pushes images** to Azure Container Registry
4. **Updates Container Apps** with new images
5. **Provides deployment summary** with URLs

## 🎯 Environment Variables Used

The workflow uses these pre-configured values:
- **Resource Group**: `rg-tasktracker`
- **Location**: `northeurope`
- **App Name**: `tasktracker`

You can change these by editing the `env:` section in the workflow file.

## 🔐 Authentication Methods

**Current Setup**: Service Principal (simplest)
- Uses `AZURE_CREDENTIALS` secret
- Works immediately after setup
- Good for getting started quickly

**Alternative**: OpenID Connect (more secure)
- No secrets stored in GitHub
- Uses federated identity
- Requires additional Azure AD configuration

## 🚨 Troubleshooting

**If the workflow fails:**

1. **Check Secrets**: Verify `AZURE_CREDENTIALS` is set correctly
2. **Check Permissions**: Ensure service principal has Contributor role
3. **Check Quotas**: Verify Azure subscription has available quotas
4. **Check Logs**: Review the Actions tab for detailed error messages

**Common Fixes:**
```bash
# Re-create service principal if expired
az ad sp create-for-rbac --name "sp-tasktracker-github" --role contributor --scopes /subscriptions/YOUR_SUB_ID --sdk-auth

# Check current permissions
az role assignment list --assignee YOUR_SP_APP_ID

# Verify subscription access
az account show
```

## 📋 Next Steps

After successful deployment:
1. **Visit your app**: Check the deployment summary for URLs
2. **Monitor logs**: Use Azure Portal to view application insights
3. **Set up monitoring**: Configure alerts and dashboards
4. **Scale as needed**: Adjust Container App settings

The workflow is now ready to deploy your TaskTracker application automatically on every push to main or develop branches!