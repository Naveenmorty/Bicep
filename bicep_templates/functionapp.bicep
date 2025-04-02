param location string = 'westeurope'
param functionAppName string
param storageAccountName string
param appServicePlanName string
param vnetName string
param subnetName string
param resourceGroupName string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroupName
}

module vnetModule '../bicep-registry-modules/avm/res/network/virtual-network' = {
  name: 'vnetDeployment'
  scope: rg
  params: {
    location: location
    vnetName: vnetName
    subnetName: subnetName
  }
}

module storageModule '../bicep-registry-modules/avm/res/storage/storage-account/main.bicep' = {
  name: 'storageDeployment'
  scope: rg
  params: {
    location: location
    name: storageAccountName
    sku: 'Standard_LRS'
    kind: 'StorageV2'
  }
}
module application_insights_deployment '../bicep-registry-modules/avm/res/insights/component/main.bicep' = {
  name: 'application_insights_deployment'
  params: {
    name: applicationInsightsName
    workspaceResourceId: logAnalyticsWorkspaceId
    tags: tags
  }
}d
module appServicePlanModule '../bicep-registry-modules/avm/res/web/serverfarm/main.bicep' = {
  name: 'appServicePlanDeployment'
  scope: rg
  params: {
    location: location
    appServicePlanName: appServicePlanName
  }
}

module functionAppModule './functionapp.bicep' = {
  name: 'functionAppDeployment'
  scope: rg
  params: {
    location: location
    functionAppName: functionAppName
    storageAccountName: storageModule.outputs.name
    appServicePlanId: appServicePlanModule.outputs.appServicePlanId
    subnetId: vnetModule.outputs.subnetId
  }
}
