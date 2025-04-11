// The templates are generated by bicep IaC generator
targetScope = 'subscription'

param location string = 'eastus'
param resourceGroupName string = 'rg-myenv'
param resourceToken string = toLower(uniqueString(subscription().id, location, resourceGroupName))
param containerAppBackendName string = 'backend${resourceToken}'
param containerAppFrontendName string = 'frontend${resourceToken}'
param cosmosMongoDb0Name string = 'db0${resourceToken}'
param keyVaultName string = 'kv${resourceToken}'
param containerAppEnvName string = 'env${resourceToken}'
param containerRegistryName string = 'acr${resourceToken}'


// Deploy an Azure Resource Group

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
	name: resourceGroupName
	location: location
}

// Deploy an Azure Container App environment

module containerAppEnv 'containerappenv.bicep' = {
	name: 'container-app-env-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: containerAppEnvName
	}
}
var containerAppEnvId = containerAppEnv.outputs.id

// Deploy an Azure Container Registry

module containerRegistry 'containerregistry.bicep' = {
	name: 'container-registry-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: containerRegistryName
	}
}

// Deploy an Azure Container App

module containerAppBackendDeployment 'containerapp.bicep' = {
	name: 'container-app-backend-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: containerAppBackendName
		targetPort: 80 
		containerAppEnvId: containerAppEnvId
		identityType: 'SystemAssigned'
		containerRegistryName: containerRegistryName 
	}
	dependsOn: [
		containerAppEnv
		containerRegistry
	]
}

// Deploy an Azure Container App

module containerAppFrontendDeployment 'containerapp.bicep' = {
	name: 'container-app-frontend-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: containerAppFrontendName
		targetPort: 80 
		containerAppEnvId: containerAppEnvId
		identityType: 'SystemAssigned'
		containerRegistryName: containerRegistryName 
	}
	dependsOn: [
		containerAppEnv
		containerRegistry
	]
}

// Deploy an Azure Cosmos DB account with a MongoDB database

module cosmosMongoDb0Deployment 'cosmosdb.bicep' = {
	name: 'cosmos-mongo-db0-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: cosmosMongoDb0Name 
		allowIps: union(containerAppBackendDeployment.outputs.outboundIps, [])
		keyVaultName: keyVaultName
		secretName: 'cosmos-mongo-db0-secret'
	}
	dependsOn: [
		keyVaultDeployment
		containerAppBackendDeployment
	]
}

// Deploy an Azure Keyvault

module keyVaultDeployment 'keyvault.bicep' = {
	name: 'key-vault--deployment'
	scope: resourceGroup
	params: {
		location: location
		name: keyVaultName
		principalIds: [
			containerAppBackendDeployment.outputs.identityPrincipalId
		] 
		allowIps: union(containerAppBackendDeployment.outputs.outboundIps, [])
	}
	dependsOn: [
		containerAppBackendDeployment
	]
}

// Deploy an Azure Container App

module containerAppSettingsBackendDeployment 'containerapp.bicep' = {
	name: 'container-app-settings-backend-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: containerAppBackendName
		targetPort: 80 
		secrets: [
			{
				name: 'cosmosmongodb0-connstr'
				keyVaultUrl: cosmosMongoDb0Deployment.outputs.keyVaultSecretUri
				identity: 'system'
			}
		]
		containerAppEnvId: containerAppEnvId
		identityType: 'SystemAssigned'
		containerRegistryName: containerRegistryName 
		containerEnv: [
			{
				name: 'MONGO_URL'
				secretRef: 'cosmosmongodb0-connstr'
			}
			{
				name: 'AZURE_KEYVAULT_RESOURCEENDPOINT'
				value: keyVaultDeployment.outputs.endpoint
			}
		]
	}
	dependsOn: [
		cosmosMongoDb0Deployment
		keyVaultDeployment
	]
}

// Deploy an Azure Container App

module containerAppSettingsFrontendDeployment 'containerapp.bicep' = {
	name: 'container-app-settings-frontend-deployment'
	scope: resourceGroup
	params: {
		location: location
		name: containerAppFrontendName
		targetPort: 80 
		containerAppEnvId: containerAppEnvId
		identityType: 'SystemAssigned'
		containerRegistryName: containerRegistryName 
		containerEnv: [
			{
				name: 'REACT_APP_API_URL'
				value: containerAppBackendDeployment.outputs.requestUrl
			}
		]
	}
	dependsOn: [
		containerAppBackendDeployment
	]
}



output containerAppBackendId string = containerAppBackendDeployment.outputs.id
output containerAppFrontendId string = containerAppFrontendDeployment.outputs.id
output cosmosMongoDb0Id string = cosmosMongoDb0Deployment.outputs.id
output keyVaultId string = keyVaultDeployment.outputs.id
output containerRegistryBackendId string = containerRegistry.outputs.id
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer

