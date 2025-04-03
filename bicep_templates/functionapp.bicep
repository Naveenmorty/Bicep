param location string = 'westeurope'
param functionAppName string
param storageAccountName string
param appServicePlanName string
param vnetName string
param subnetName string
param resourceGroupName string
param applicationInsightsName string
param logAnalyticsWorkspaceId string
param tags object = {}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroupName
}

module vnetModule '../bicep-registry-modules/avm/res/network/virtual-network/main.bicep' = {
  name: 'vnetDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    vnetName: vnetName
    subnetName: subnetName
  }
}

module storageModule '../bicep-registry-modules/avm/res/storage/storage-account/main.bicep' = {
  name: 'storageDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    name: storageAccountName
    sku: 'Standard_LRS'
    kind: 'StorageV2'
  }
}

module applicationInsightsModule '../bicep-registry-modules/avm/res/insights/component/main.bicep' = {
  name: 'applicationInsightsDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: applicationInsightsName
    workspaceResourceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module appServicePlanModule '../bicep-registry-modules/avm/res/web/serverfarm/main.bicep' = {
  name: 'appServicePlanDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    appServicePlanName: appServicePlanName
  }
}

module functionAppModule './functionapp.bicep' = {
  name: 'functionAppDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    functionAppName: functionAppName
    storageAccountName: storageModule.outputs.name
    appServicePlanId: appServicePlanModule.outputs.appServicePlanId
    subnetId: vnetModule.outputs.subnetId
  }
}
