// SPSSiteFactory - Azure resources for the provisioning Function app.
//
// Deploys the minimum set of resources required to host the PowerShell Function app:
// a storage account (also used by the provisioning queue), a workspace-based
// Application Insights instance, a hosting plan, and the Function App itself.
//
// Deploy (resource group scope):
//   az deployment group create -g <rg> -f infra/main.bicep -p appName=<name>
//
// SharePoint settings (tenantId, clientId, certificateThumbprint, adminSiteUrl,
// tenantUrl) can be passed at deploy time or set later on the Function App.

targetScope = 'resourceGroup'

@description('Base name for the Function app and related resources.')
@minLength(3)
@maxLength(24)
param appName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Hosting plan SKU. Y1 = Consumption (lowest cost), EP1 = Premium (no cold start).')
@allowed([
  'B1'
  'Y1'
  'EP1'
])
param planSku string = 'B1'

@description('Storage account SKU.')
param storageSku string = 'Standard_LRS'

@description('Entra ID tenant id used for PnP app-only authentication.')
param tenantId string = ''

@description('Entra ID application (client) id used for PnP app-only authentication.')
param clientId string = ''

@description('Certificate thumbprint used for PnP app-only authentication.')
param certificateThumbprint string = ''

@description('SharePoint admin center URL, e.g. https://contoso-admin.sharepoint.com.')
param adminSiteUrl string = ''

@description('SharePoint tenant base URL, e.g. https://contoso.sharepoint.com.')
param tenantUrl string = ''

var storageAccountName = toLower('st${uniqueString(resourceGroup().id, appName)}')
var hostingPlanName = '${appName}-plan'
var appInsightsName = '${appName}-ai'
var logAnalyticsName = '${appName}-law'

// Built-in role definition ids for identity-based storage access.
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    // Identity-based access only. The tenant policy forbids shared key access.
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: hostingPlanName
  location: location
  kind: 'linux'
  sku: {
    name: planSku
    tier: planSku == 'Y1' ? 'Dynamic' : (planSku == 'EP1' ? 'ElasticPremium' : 'Basic')
  }
  properties: {
    // Linux plan. Avoids the Windows content file share (Azure Files), which requires
    // storage shared key access that the tenant policy forbids.
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'POWERSHELL|7.4'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
      appSettings: [
        {
          // Identity-based AzureWebJobsStorage (no shared key). The function's
          // system-assigned identity is granted blob and queue data roles below.
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: 'https://${storageAccount.name}.queue.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: 'https://${storageAccount.name}.table.${environment().suffixes.storage}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_LOAD_CERTIFICATES'
          value: '*'
        }
        {
          name: 'TenantId'
          value: tenantId
        }
        {
          name: 'ClientId'
          value: clientId
        }
        {
          name: 'CertificateThumbprint'
          value: certificateThumbprint
        }
        {
          name: 'AdminSiteUrl'
          value: adminSiteUrl
        }
        {
          name: 'TenantUrl'
          value: tenantUrl
        }
      ]
    }
  }
}

// Grant the function's managed identity identity-based access to storage
// (host metadata in blob, queue triggers in queue) so no shared key is needed.
resource blobOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, storageBlobDataOwnerRoleId)
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
  }
}

resource queueContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, storageQueueDataContributorRoleId)
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
