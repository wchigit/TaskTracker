# CI/CD Pipeline Setup for TaskTracker

This document outlines the steps to set up the GitHub Actions CI/CD pipeline for deploying TaskTracker to Azure Container Apps across multiple environments (dev, staging, production).

## Prerequisites

1. **Azure CLI** installed and configured
2. **GitHub CLI** installed and authenticated
3. **Owner or Contributor** access to Azure subscription
4. **Admin access** to the GitHub repository
5. **Existing Azure resources** in the following resource groups:
   - `rg-wcdev` (Development environment)
   - `rg-wcstaging` (Staging environment)
   - `rg-wcproduction` (Production environment)

## Setup Steps

### Step 1: Create User-Assigned Managed Identity for Pipeline

Run the Azure authentication setup script:
```bash
./.azure/setup-azure-auth-for-pipeline.ps1
```

This script will:
- Create a new User-Assigned Managed Identity for the pipeline
- Configure federated credentials for GitHub Actions OIDC
- Assign necessary RBAC permissions (Contributor to resource groups, AcrPull to container registries)

### Step 2: Configure GitHub Environments and Variables

Run the pipeline environment setup script:
```bash
./.azure/setup-pipeline-environment.ps1
```

This script will:
- Create GitHub environments (dev, staging, production) with approval requirements
- Set up environment-specific variables and secrets
- Configure protection rules for production deployment

## Pipeline Workflow

The CI/CD pipeline (`deploy.yml`) includes:

### Build Job
- Builds Docker images for backend and frontend
- Uses Docker layer caching for optimization
- Stores images as artifacts

### Deployment Jobs
- **Development**: Deploys automatically on `develop` branch pushes
- **Staging**: Deploys automatically on `main` branch pushes
- **Production**: Deploys after staging, requires manual approval

### Trigger Conditions
- `develop` branch → Dev environment
- `main` branch → Staging → Production
- Manual dispatch → Any environment (with selection)

## Environment Variables

Each environment requires these variables:

| Variable | Description | Example |
|----------|-------------|----------|
| `AZURE_CLIENT_ID` | Managed Identity Client ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_TENANT_ID` | Azure Tenant ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `a4ab3025-1b32-4394-92e0-d07c1ebf3787` |
| `RESOURCE_GROUP` | Resource Group Name | `rg-wcdev` |
| `ACR_NAME` | Container Registry Name | `acryqsta6dud5vi2` |
| `BACKEND_APP_NAME` | Backend Container App Name | `backend` |
| `FRONTEND_APP_NAME` | Frontend Container App Name | `frontend` |

## Application Environment Variables

These should be configured **directly in the Container Apps**, not in the pipeline:

| Variable | Description | Configure In |
|----------|-------------|-------------|
| `MONGO_URL` | MongoDB Connection String | Container App Environment Variables |
| `REACT_APP_API_URL` | Backend API URL | Container App Environment Variables |

## Security Considerations

1. **Managed Identity**: Uses OIDC authentication instead of service principal secrets
2. **Least Privilege**: Managed Identity only has required permissions
3. **Environment Protection**: Production requires manual approval
4. **Secrets Management**: Sensitive values stored in GitHub secrets

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify federated credentials are correctly configured
   - Check that the Managed Identity has proper RBAC permissions

2. **Image Push Failures**
   - Ensure ACR login is successful
   - Verify AcrPull/AcrPush permissions on the container registry

3. **Container App Update Failures**
   - Check that the container app names are correct
   - Verify the Managed Identity has Contributor access to resource groups

### Monitoring

- Check GitHub Actions logs for detailed error messages
- Monitor Azure Container Apps logs via Azure Portal
- Review container registry activity logs

## Next Steps

1. Run the setup scripts in order
2. Test the pipeline with a small change to the `develop` branch
3. Monitor the deployment process
4. Configure additional monitoring and alerts as needed