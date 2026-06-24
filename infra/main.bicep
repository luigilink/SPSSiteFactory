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
  'Y1'
  'EP1'
])
param planSku string = 'Y1'

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
var contentShareName = toLower(appName)

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
  sku: {
    name: planSku
    tier: planSku == 'Y1' ? 'Dynamic' : 'ElasticPremium'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      powerShellVersion: '7.4'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: contentShareName
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

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
