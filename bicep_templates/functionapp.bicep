
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

@description('Application Owner. It is used in tagging of resoruces')
param applicationOwner string = 'michael_jarvis@worldvision.ca'

@description('Budget Owner. It is used in tagging of resoruces')
param budgetOwner string = 'andrew_duffy@worldvision.ca'

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


var initialStorageAccountName = 'wvcazcc${environment}st${projectName}'
//var storageAccountName = 'wvcazccdevstidentityprov'
var storageAccountName = length(initialStorageAccountName) <= 24
  ? initialStorageAccountName
  : substring(initialStorageAccountName, 0, 23)
var applicationServicePlanName = 'wvcazcc${environment}-plan-${projectName}-${sequenceNumber}'
var applicationServicePlanSku = environment == 'prd' ? 'P1V3' : 'S1'

//Create Applicaiton Insights resource name from parameters
var applicationInsightsName = 'wvcazcc${environment}-appi-${projectName}-${sequenceNumber}'

//Set the Log Analystics Workspace instance
var logAnalyticsWorkspaceId = environment == 'prd'
  ? '/subscriptions/8026cce0-ff03-4224-99a6-b3ab3194f58c/resourceGroups/wvcazccprd-rg-monitor-001/providers/Microsoft.OperationalInsights/workspaces/wvcazccprd-log-monitor-001'
  : '/subscriptions/8026cce0-ff03-4224-99a6-b3ab3194f58c/resourceGroups/wvcazccnonprd-rg-monitor-001/providers/Microsoft.OperationalInsights/workspaces/wvcazccnonprd-log-monitor-001'

var functionApplicationName = 'wvcazcc${environment}-func-${projectName}-${sequenceNumber}'

var initialKeyVaultName = 'wvcazcc${environment}-kv-${projectName}-${sequenceNumber}'
//var keyVaultName = 'wvcazcc${environment}-kv-${projectName}'
//var initialKeyVaultName = 'wvccazdev-azkv-idprov'
var refinedKeyVaultName = length(initialKeyVaultName) <= 24
  ? initialKeyVaultName
  : substring(initialKeyVaultName, 0, 23)
var keyVaultName = endsWith(refinedKeyVaultName, '-')
  ? substring(refinedKeyVaultName, 0, length(refinedKeyVaultName) - 1)
  : refinedKeyVaultName

var keyVaultUri = 'https://${keyVaultName}.vault.azure.net/'
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

module key_vault_deployment '../bicep-registry-modules/avm/res/key-vault/vault/main.bicep' = {
  name: 'key_vault_deployment'
  params: {
    name: keyVaultName
    sku: 'standard'
    tags: tags
    enableRbacAuthorization: true
  }
}

module key_vault_role_assignments '../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: 'key_vault_role_assignments'
  params: {
    resourceId: key_vault_deployment.outputs.resourceId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' //Secrets User
    principalId: function_application_deployment.outputs.systemAssignedMIPrincipalId
    enableTelemetry: false
  }
}

module key_vault_role_assignments_slot '../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: 'key_vault_role_assignments_slot'
  params: {
    resourceId: key_vault_deployment.outputs.resourceId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' //Secrets User
    principalId: function_application_deployment.outputs.slotSystemAssignedMIPrincipalIds[0]
    enableTelemetry: false
  }
}


//Secret Reader
module key_vault_role_secret_reader '../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: 'key_vault_role_secret_reader'
  params: {
    resourceId: key_vault_deployment.outputs.resourceId
    roleDefinitionId: '21090545-7ca7-4776-b22c-e363652d74d2' //Secrets Reader
    principalId: keyVaultRoleReaderEntraGroup
    enableTelemetry: false
  }
}

//Secret Officer
module key_vault_role_secret_officer '../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: 'key_vault_role_secret_officer'
  params: {
    resourceId: key_vault_deployment.outputs.resourceId
    roleDefinitionId: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' //Secrets Officer
    principalId: keyVaultRoleOfficerEntraGroup
    enableTelemetry: false
  }
}

//Secret Admin
module key_vault_role_secret_admin '../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: 'key_vault_role_secret_admin'
  params: {
    resourceId: key_vault_deployment.outputs.resourceId
    roleDefinitionId: '00482a5a-887f-4fb3-b363-3b7fe8e74483' //Secrets Admin
    principalId: keyVaultRoleAdminEntraGroup
    enableTelemetry: false
  }
}
