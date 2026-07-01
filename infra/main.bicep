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
//
// App-only certificate: this template provisions an empty Key Vault and grants the
// Function's managed identity read access to its secrets. After deployment, generate
// the self-signed certificate inside the vault and register its public key on the
// Entra ID application (see docs/azure-setup.md). The Function loads the certificate
// from Key Vault at runtime (CertificateSecretUri), which is the only app-only path
// that works on Linux Functions.

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

@description('Certificate thumbprint used for PnP app-only authentication (local Windows development fallback).')
param certificateThumbprint string = ''

@description('Name of the Key Vault certificate/secret holding the app-only provisioning certificate.')
param certificateSecretName string = 'spssitefactory-provisioning'

@description('SharePoint admin center URL, e.g. https://contoso-admin.sharepoint.com.')
param adminSiteUrl string = ''

@description('SharePoint tenant base URL, e.g. https://contoso.sharepoint.com.')
param tenantUrl string = ''

@description('Client id of the SPSSiteFactory-Api app registration used as the Easy Auth audience. Empty leaves App Service Authentication unconfigured.')
param apiClientId string = ''

@description('App id allowed to call the API through Easy Auth. Defaults to the SharePoint Online Web Client Extensibility principal used by SPFx.')
param spfxPrincipalAppId string = '08e18876-6177-487e-b8b5-cf950c1e598c'

var storageAccountName = toLower('st${uniqueString(resourceGroup().id, appName)}')
var hostingPlanName = '${appName}-plan'
var appInsightsName = '${appName}-ai'
var logAnalyticsName = '${appName}-law'
var keyVaultName = toLower('kv-${uniqueString(resourceGroup().id, appName)}')

// Built-in role definition ids for identity-based storage access.
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
// Built-in role definition id allowing the identity to read Key Vault secrets.
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

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

// Key Vault holding the app-only provisioning certificate. RBAC authorization is used
// so the Function's managed identity can read the certificate secret at runtime.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
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
          // Data-plane URI of the Key Vault secret holding the app-only certificate.
          // The Function reads it at runtime through its managed identity.
          name: 'CertificateSecretUri'
          value: '${keyVault.properties.vaultUri}secrets/${certificateSecretName}'
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

// Allow the function's managed identity to read the provisioning certificate secret.
resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

// App Service Authentication (Easy Auth). Requires callers to present a valid Entra
// token audienced to the SPSSiteFactory-Api app, and restricts callers to the SPFx
// SharePoint principal. Only configured when apiClientId is supplied.
resource functionAuth 'Microsoft.Web/sites/config@2023-12-01' = if (!empty(apiClientId)) {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          // SPFx AadHttpClient issues v1 tokens (iss = sts.windows.net), so the Easy Auth
          // issuer must be the v1 STS endpoint to validate them.
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/'
          clientId: apiClientId
        }
        validation: {
          allowedAudiences: [
            'api://${apiClientId}'
            apiClientId
          ]
          defaultAuthorizationPolicy: {
            allowedApplications: [
              spfxPrincipalAppId
            ]
          }
        }
      }
    }
    login: {
      tokenStore: {
        enabled: false
      }
    }
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
