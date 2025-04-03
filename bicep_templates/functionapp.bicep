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

@description('Application Category. It is used in tagging of resoruces')
param applicationCategory string = 'Web Services'

@description('Application Name. It is used in tagging of resoruces')
param applicationName string = 'Template Service'


@description('Start Date. It is used in tagging of resoruces')
param startDate string = utcNow('dd-MMMM-yyyy')




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
var logAnalyticsWorkspaceId = environment == 'prd'
  ? '/subscriptions/8026cce0-ff03-4224-99a6-b3ab3194f58c/resourceGroups/abcdefprd-rg-monitor-001/providers/Microsoft.OperationalInsights/workspaces/abcdefprd-log-monitor-001'
  : '/subscriptions/8026cce0-ff03-4224-99a6-b3ab3194f58c/resourceGroups/abcdefnonprd-rg-monitor-001/providers/Microsoft.OperationalInsights/workspaces/abcdefnonprd-log-monitor-001'

var functionApplicationName = 'abcdef${environment}-func-${projectName}-${sequenceNumber}'




var tags = {
  'Application Category': applicationCategory
  'Application Name': applicationName
  'Application Owner': applicationOwner
  'Budget Owner': budgetOwner
  'Start Date': startDate
}



module storage_account_deployment '../bicep-registry-modules/avm/res/storage/storage-account/main.bicep' = {
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
    keyVaultAccessIdentityResourceId: 'SystemAssigned'
    storageAccountResourceId: storage_account_deployment.outputs.resourceId
    appSettingsKeyValuePairs: appSettingsKeyValuePairs
    slots: appSlotSettingsKeyValuePairs
    tags: tags
    enableTelemetry: false
    publicNetworkAccess: 'Enabled'
  }
}
