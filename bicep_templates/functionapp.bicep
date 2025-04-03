@description('Application environment. This is used in naming resources')
@allowed([
  'poc'
  'dev'
  'uat'
  'stg'
  'pre'
  'prd'
])
param environment string = 'dev'

param projectName string = 'template'

param sequenceNumber string = '001'

param subnetId string = '/subscriptions/c44cf592-60df-46be-96bb-1ffb0b5902bb/resourceGroups/dinesh-rg/providers/Microsoft.Network/virtualNetworks/linux-citrin-vm-vnet/subnets/default'


var storageAccountName = 'abcdefdevstidentityprov'
var applicationServicePlanName = 'abcdef${environment}-plan-${projectName}-${sequenceNumber}'
var applicationServicePlanSku = environment == 'prd' ? 'P1V3' : 'S1'

//Create Applicaiton Insights resource name from parameters

//Set the Log Analystics Workspace instance


var functionApplicationName = 'abcdef${environment}-func-${projectName}-${sequenceNumber}'






module storage_account_deployment '../bicep-registry-modules/avm/res/storage/storage-account/main.bicep' = {
  name: 'storage_account_deployment'
  params: {
    name: storageAccountName
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    enableTelemetry: false
    publicNetworkAccess: 'Enabled'//TODO: CHANGE TO DISABLED - REQUIRES RESEARCH ON HOW FUNCTIONAPP CAN ACCESS WITH DISABLED
    supportsHttpsTrafficOnly: true
  }
}

module service_plan_deployment '../bicep-registry-modules/avm/res/web/serverfarm/main.bicep' = {
  name: 'service_plan_deployment'
  params: {
    name: applicationServicePlanName
    skuName: applicationServicePlanSku
    skuCapacity: 1
    kind: 'functionApp'
  }
}

var appSettingsKeyValuePairs = {
  FUNCTIONS_EXTENSION_VERSION: '~4'
  FUNCTION_APP_EDIT_MODE: 'readonly'
  FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
  WEBSITE_RUN_FROM_PACKAGE: '1'
}
var appSlotSettingsKeyValuePairs = [
  {
    name: 'deployment'
  }
]

module function_application_deployment '../bicep-registry-modules/avm/res/web/site/main.bicep' = {
  name: 'function_application_deployment'
  params: {
    name: functionApplicationName
    kind: 'functionapp'
    serverFarmResourceId: service_plan_deployment.outputs.resourceId
    managedIdentities: { systemAssigned: true }
    keyVaultAccessIdentityResourceId: 'SystemAssigned'
    storageAccountResourceId: storage_account_deployment.outputs.resourceId
    appSettingsKeyValuePairs: appSettingsKeyValuePairs
    slots: appSlotSettingsKeyValuePairs
    enableTelemetry: false
    siteConfig: {
      virtualNetworkSubnetId: subnetId // Correct property inside siteConfig
    }
    accessRestrictions: [
      {
        name: 'AllowDefaultSubnet'
        action: 'Allow'
        priority: 100
        description: 'Allow traffic only from default subnet'
        vnetSubnetResourceId: subnetId
      }
    ]
  }
}
