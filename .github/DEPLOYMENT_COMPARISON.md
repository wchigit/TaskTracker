# Azure CLI vs AZD Deployment Comparison

This document compares the two deployment approaches for your TaskTracker application.

## Authentication Differences

### ✅ **Authentication is IDENTICAL for both workflows**

Both Azure CLI and AZD workflows use the same authentication methods:

#### Option 1: Service Principal with Client Secret
```yaml
# Same for both workflows
- name: Azure Login (Service Principal)
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

#### Option 2: OpenID Connect (Federated Identity) - RECOMMENDED
```yaml
# Same for both workflows  
- name: Azure Login (OIDC)
  uses: azure/login@v1
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

## Key Differences

### 🔧 **Azure Developer CLI (AZD) Approach**
**File:** `.github/workflows/azure-dev.yml`

**Pros:**
- ✅ **Simple Commands**: Just `azd provision` and `azd deploy`
- ✅ **Integrated Workflow**: Handles infrastructure + app deployment together
- ✅ **Convention-based**: Uses `azure.yaml` configuration
- ✅ **Less Code**: Minimal workflow file
- ✅ **Built for DevOps**: Designed specifically for CI/CD

**Cons:**
- ❌ **Less Control**: Limited customization options
- ❌ **Newer Tool**: Less community resources
- ❌ **Opinionated**: Must follow AZD conventions

**Best For:** Simple deployments, rapid prototyping, teams new to Azure

---

### 🛠️ **Azure CLI Approach**  
**File:** `.github/workflows/azure-cli.yml`

**Pros:**
- ✅ **Full Control**: Complete control over every step
- ✅ **Flexible**: Can customize any part of the deployment
- ✅ **Mature Tool**: Extensive documentation and community support
- ✅ **Granular**: Fine-tuned resource management
- ✅ **Troubleshooting**: Easier to debug individual steps

**Cons:**
- ❌ **More Complex**: Longer workflow files
- ❌ **Manual Steps**: Need to handle dependencies manually  
- ❌ **More Maintenance**: More code to maintain
- ❌ **Error-prone**: More opportunities for mistakes

**Best For:** Production environments, complex deployments, teams wanting full control

## Setup Requirements Comparison

| Aspect | AZD Workflow | Azure CLI Workflow |
|--------|-------------|-------------------|
| **GitHub Secrets** | Same - `AZURE_CREDENTIALS` OR federated identity | Same - `AZURE_CREDENTIALS` OR federated identity |
| **GitHub Variables** | `AZURE_ENV_NAME`, `AZURE_LOCATION`, `AZURE_SUBSCRIPTION_ID` | `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` (for OIDC) |
| **Service Principal** | Same permissions required | Same permissions required |
| **Repository Files** | Requires `azure.yaml` | Uses Bicep templates directly |

## Workflow Features Comparison

| Feature | AZD Workflow | Azure CLI Workflow |
|---------|-------------|-------------------|
| **Infrastructure Deployment** | `azd provision` | `az deployment group create` |
| **App Deployment** | `azd deploy` | `az containerapp update` |
| **Image Building** | Automatic | `az acr build` |
| **Environment Variables** | Configured in `azure.yaml` | Set via CLI commands |
| **Rollback** | Limited | Manual via CLI |
| **Monitoring** | Basic | Custom deployment summary |

## Recommendation

### 🎯 **For Your TaskTracker App:**

**Use AZD Workflow if:**
- You want simple, fast deployments
- You're comfortable with AZD conventions
- You prefer minimal maintenance
- You're building a straightforward application

**Use Azure CLI Workflow if:**
- You need fine-grained control over deployment
- You want to customize build/deploy steps
- You plan to add complex CI/CD features later
- You prefer explicit over implicit behavior

## Security Notes

Both approaches use **identical authentication** - the choice doesn't affect security:

1. **Recommended**: Use OpenID Connect (federated identity) for better security
2. **Alternative**: Use service principal with client secret
3. Both support Azure RBAC and managed identities
4. Both can use the same Key Vault for secrets management

## Migration Between Approaches

You can easily switch between approaches:
- Both use the same Bicep infrastructure templates
- Both deploy to the same Azure resources
- Authentication setup is identical
- Just use different workflow files

Choose the approach that best fits your team's needs and expertise level!