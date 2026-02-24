---
description: |
  Deploy the wc/develop branch to Azure. This workflow performs CI steps (build and test)
  and CD steps (deploy to Azure) for both the FastAPI backend and React frontend.

on:
  push:
    branches:
      - wc/develop
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read

network:
  allowed:
    - defaults
    - node
    - python
    - containers

tools:
  github:
    lockdown: false

safe-outputs:
  create-issue:
    title-prefix: "[Azure Deploy] "
    labels: [deployment, azure, ci-cd]

engine: copilot
---

# Deploy wc/develop to Azure

You are a deployment automation agent responsible for deploying the TaskTracker application to Azure.

## Project Structure

The TaskTracker application consists of:
- **Backend**: Python FastAPI application (in `/backend` directory)
- **Frontend**: React application (in `/frontend` directory)
- **Database**: MongoDB (configured via docker-compose)

## Azure Configuration

- **Subscription ID**: a4ab3025-1b32-4394-92e0-d07c1ebf3787
- **Target Branch**: wc/develop

### Required GitHub Secrets

This workflow requires Azure authentication to be configured. The recommended approach is:
- Set up Azure OIDC authentication for GitHub Actions (preferred for security)
- Or configure service principal credentials as repository secrets

The subscription ID (a4ab3025-1b32-4394-92e0-d07c1ebf3787) is provided as reference but should be validated during deployment.

## CI/CD Process

### Phase 1: Continuous Integration (CI)

1. **Backend CI**:
   - Navigate to `/backend` directory
   - Install Python dependencies from `requirements.txt`
   - Run any backend tests if they exist (check for test files)
   - Lint the Python code if linting configuration exists
   - Build the backend Docker image
   - Use ubuntu:latest as the base image for building the backend Docker container

2. **Frontend CI**:
   - Navigate to `/frontend` directory
   - Install Node.js dependencies with `npm install`
   - Run frontend tests with `npm test` (if tests exist)
   - Build the production frontend with `npm run build`
   - Build the frontend Docker image

### Phase 2: Continuous Deployment (CD)

3. **Deploy to Azure**:
   - Check for Azure CLI: `which az` or install via package manager: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
   - Verify Azure authentication is configured (OIDC or service principal), use secrets.AZURE_CLIENT_ID, secrets.AZURE_TENANT_ID, secrets.AZURE_SUBSCRIPTION_ID for Azure login
   - Use subscription ID: a4ab3025-1b32-4394-92e0-d07c1ebf3787
   - Deploy the Docker containers to Azure (use Azure Container Apps or Azure App Service)
   - Configure the following environment variables:
     - Backend: `MONGO_URL` pointing to Azure-hosted MongoDB or MongoDB Atlas
     - Frontend: `REACT_APP_API_URL` pointing to the deployed backend URL
   - Verify the deployment was successful

4. **Report Deployment Status**:
   - Create a GitHub issue with deployment details including:
     - Deployment timestamp
     - Commit SHA deployed
     - CI test results
     - Azure deployment URLs
     - Any errors or warnings encountered
   - If deployment fails, provide detailed error information and suggested remediation steps

## Important Notes

- Use the repository's existing Dockerfiles for building images
- Azure authentication must be configured (OIDC recommended, or service principal via repository secrets)
- The subscription ID is provided for reference and validation during deployment
- Ensure all credentials are handled securely - never log or expose them in plain text
- Provide clear, actionable feedback in deployment reports
- If authentication is not configured, create an issue with setup instructions for Azure OIDC or service principal

## Error Handling

If any step fails:
1. Stop the deployment process
2. Create a detailed issue report with:
   - The failing step
   - Complete error messages
   - Suggested fixes
   - Rollback recommendations if applicable

## Success Criteria

- All CI tests pass
- Docker images build successfully
- Application deploys to Azure without errors
- Deployment issue is created with all relevant details
