
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




@description('Start Date. It is used in tagging of resoruces')
param startDate string = utcNow('dd-MMMM-yyyy')

@description('Role assigned as a KeyVault Reader')
param keyVaultRoleReaderEntraGroup string

@description('Role assigned as a KeyVault Reader')
param keyVaultRoleOfficerEntraGroup string

@description('Role assigned as a KeyVault Reader')
@allowed([
  '736d99e1-bd89-4a70-87ec-3dbf506a0f87' //Locked to Global Admins
])
param keyVaultRoleAdminEntraGroup string = '736d99e1-bd89-4a70-87ec-3dbf506a0f87'


var initialStorageAccountName = 'abcdef${environment}st${projectName}'
//var storageAccountName = 'abcdefdevstidentityprov'
var storageAccountName = length(initialStorageAccountName) <= 24
  ? initialStorageAccountName
  : substring(initialStorageAccountName, 0, 23)
var applicationServicePlanName = 'abcdef${environment}-plan-${projectName}-${sequenceNumber}'
var applicationServicePlanSku = environment == 'prd' ? 'P1V3' : 'S1'

//Create Applicaiton Insights resource name from parameters
var applicationInsightsName = 'abcdef${environment}-appi-${projectName}-${sequenceNumber}'

//Set the Log Analystics Workspace instance


var functionApplicationName = 'abcdef${environment}-func-${projectName}-${sequenceNumber}'





module storage_account_deployment '../bicep-registry-modules/avm/res/network/virtual-network' = {
  name: 'storage_account_deployment'
  params: {
    name: storageAccountName
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    tags: tags
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
    kind: 'FunctionApp'
    tags: tags
  }
}
module application_insights_deployment '../bicep-registry-modules/avm/res/insights/component/main.bicep' = {
  name: 'application_insights_deployment'
  params: {
    name: applicationInsightsName
    workspaceResourceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

var appSettingsKeyValuePairs = {
  FUNCTIONS_EXTENSION_VERSION: '~4'
  FUNCTION_APP_EDIT_MODE: 'readonly'
  FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
  KeyVaultURI: keyVaultUri
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
    appInsightResourceId: application_insights_deployment.outputs.resourceId
    managedIdentities: { systemAssigned: true }
    storageAccountResourceId: storage_account_deployment.outputs.resourceId
    appSettingsKeyValuePairs: appSettingsKeyValuePairs
    slots: appSlotSettingsKeyValuePairs
    tags: tags
    enableTelemetry: false
    publicNetworkAccess: 'Enabled'
  }
}

