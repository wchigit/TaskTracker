# Understand the generated Bicep files

CodeToCloud generates Bicep code to create Azure resources according to your infrastructure requirements and manages the connection between created Azure services. The generator takes care of app settings, authentication settings (identity enabling and role assignments), and public network settings to make your service work once deployed.

## Bicep files

The generator for Bicep generates three types of files: `main.bicep`, `main.parameters.json` and other Bicep files that serve as templates for each type of resource. `main.bicep` describes the deployment of the resources. `main.parameters.json` contains user inputs, and the other Bicep files are used as modules in main.bicep.

1. Bicep templates of resources

    For each type of resources, a Bicep file is generated as a module. These Bicep files are used once or multiple times in `main.bicep` for actual deployments. Each template contains the parameters it takes from `main.bicep` at the top, followed by the basic configurations of the resources and the outputs at the end. You can modify the basic configurations of the resources in the templates or customize the parameters of a resource instance in the deployments in `main.bicep`. Below is a brief introduction to the generated Bicep files for all resources and their dependencies.

    - Azure Container Apps

        `containerappenv.bicep` defines the Container Apps Environment and the Log Analytics (for monitoring) that are prerequisites for the creation of Container Apps. Only one Container Apps Environment is created and is shared by all Container Apps services.
        `containerappregistry.bicep` defines the Container Registry that is also shared by all Container Apps services.
        `containerapp.bicep` defines a Container App template with system identity enabled and the Container App Registry referenced. Environment variables and secrets for service bindings are passed through from `main.bicep`.

    - Azure Cosmos DB for MongoDB

        `cosmosdb.bicep` defines a Cosmos DB template of the MongoDB kind and a Mongo database. Public IPs are set to IP rules. The DocumentDB Account Contributor role is granted if system identity-based connection is used. The primary connection string is stored in the key vault if connection by secret is used.

    - Azure Key Vault

        `keyvault.bicep` defines an Azure Key Vault template. Public IP rules are set to the network ACL. The Key Vault Secrets Officer role is granted. For Bicep, all secret values for service bindings are stored in the key vault first and used as key vault references in compute resources. A key vault is automatically created and shared across all resources.

    **_NOTE:_** All the secrets (connectin strings, access keys, and passwords) are stored in the key vault and used as key vault references in compute resources.

1. `main.bicep`

    This file defines the deployments of your services. During the deployments, the connection information between services is configured. The resources are created or updated in the following order:

    - Dependency resources such as Container Apps Environment and App Service Plan, etc.
    - Compute resources such as Container App and App Service, etc.
    - Target resources such as databases, storage, and key vault, etc. If the target is connected to a compute resource, network and authentication settings are configured. Outbound IPs of the compute resources are added to the target's firewall rules. If the connection is using system identity, the principal ID is used to do role assignment according to the resource templates. If the connection is using secret authentication, connection strings or keys are constructed or acquired in the templates.
    - The deployment of app settings. The connection information, such as key vault secret (retrieved from each resource template using the key vault reference format) and the resource endpoint from the outputs of the target resources, is set in app settings. Container Apps are deployed a second time if they are connected to target resources. The connection information is set to the environment variables and the Container Apps secret. The key vault secret is referenced by the secret URI using system identity.

1. `main.parameters.json`

    This file contains the parameters that require user input.

## Next Step

1. Complete the input parameters.
1. Customize the configurations of the resources.
1. Provision the resources. Refer to [Deploy Bicep files from Visual Studio Code](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-vscode).
