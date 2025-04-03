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

module vnetModule 'br:bicep/modules/network/virtual-network:1.0.0' = {
  name: 'vnetDeployment'
  scope: subscription()  // Adjust scope if needed
  params: {
    location: location
    vnetName: vnetName
    subnetName: subnetName
  }
}

module storageModule 'br:bicep/modules/storage-account:1.0.0' = {
  name: 'storageDeployment'
  scope: rg
  params: {
    location: location
    name: storageAccountName
    sku: 'Standard_LRS'
    kind: 'StorageV2'
  }
}

module application_insights_deployment 'br:bicep/modules/insights/component:1.0.0' = {
  name: 'application_insights_deployment'
  params: {
    name: applicationInsightsName
    workspaceResourceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module appServicePlanModule 'br:bicep/modules/web/serverfarm:1.0.0' = {
  name: 'appServicePlanDeployment'
  scope: rg
  params: {
    location: location
    appServicePlanName: appServicePlanName
  }
}
