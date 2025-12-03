# Manual GitHub Environment Variable Setup

Since the automated script had API issues, here are the exact values to set manually in GitHub:

## Go to: https://github.com/wchigit/TaskTracker/settings/environments

### **Dev Environment Variables:**
```
AZURE_CLIENT_ID = 3467d932-b21f-4957-bc6c-75dd864d2afc
AZURE_TENANT_ID = 72f988bf-86f1-41af-91ab-2d7cd011db47
AZURE_SUBSCRIPTION_ID = a4ab3025-1b32-4394-92e0-d07c1ebf3787
RESOURCE_GROUP = rg-wcdev
ACR_NAME = acryqsta6dud5vi2
BACKEND_APP_NAME = backend
FRONTEND_APP_NAME = frontend
REACT_APP_API_URL = https://backend.salmonmeadow-68725b48.swedencentral.azurecontainerapps.io
```

### **Staging Environment Variables:**
```
AZURE_CLIENT_ID = 3467d932-b21f-4957-bc6c-75dd864d2afc
AZURE_TENANT_ID = 72f988bf-86f1-41af-91ab-2d7cd011db47
AZURE_SUBSCRIPTION_ID = a4ab3025-1b32-4394-92e0-d07c1ebf3787
RESOURCE_GROUP = rg-wcstaging
ACR_NAME = acroyid6zftjzu46
BACKEND_APP_NAME = backend
FRONTEND_APP_NAME = frontend
REACT_APP_API_URL = https://backend.whitemeadow-ef27bc65.swedencentral.azurecontainerapps.io
```

### **Production Environment Variables:**
```
AZURE_CLIENT_ID = 3467d932-b21f-4957-bc6c-75dd864d2afc
AZURE_TENANT_ID = 72f988bf-86f1-41af-91ab-2d7cd011db47
AZURE_SUBSCRIPTION_ID = a4ab3025-1b32-4394-92e0-d07c1ebf3787
RESOURCE_GROUP = rg-wcproduction
ACR_NAME = acr6ia22terduzqo
BACKEND_APP_NAME = backend
FRONTEND_APP_NAME = frontend
REACT_APP_API_URL = https://backend.whitestone-e524cfb1.swedencentral.azurecontainerapps.io
```

## MONGO_URL (Secrets - Add to Environment Secrets, not variables)

You'll need to add the Cosmos DB connection strings as **secrets** (not variables) for each environment:

1. Go to each environment in GitHub
2. Add a **Secret** (not variable) named `MONGO_URL`
3. Use the actual Cosmos DB connection string for each environment

## Manual Setup Steps:

1. **Go to GitHub Repository Settings** → **Environments**
2. **For each environment** (dev, staging, production):
   - Click on the environment name
   - Add the variables listed above under "Environment variables"
   - Add the `MONGO_URL` as a secret under "Environment secrets"
3. **For Production Environment**:
   - Add required reviewers under "Required reviewers"
   - Enable "Prevent self-review" if desired

## Notes:

- The **Container App URLs** were successfully retrieved and are ready to use
- The **Cosmos DB connection strings** were found but should be added as secrets
- All environments are **created and ready** for the pipeline