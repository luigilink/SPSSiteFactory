# Azure setup

This guide describes how to prepare the Azure prerequisites for the SPSSiteFactory
provisioning Function app. It assumes the SharePoint host site and the
`SiteFactoryRequests` list already exist (see [Prerequisites and governance](prerequisites.md)).

The setup has three steps:

1. Deploy the Azure resources (Bicep).
2. Register the Entra ID application (PowerShell + PnP).
3. Configure and deploy the Function app.

## Prerequisites

- An Azure subscription and a resource group.
- Azure CLI (`az`) and Azure Functions Core Tools (`func`).
- PowerShell 7.2 or later and PnP.PowerShell.
- An Entra ID administrator able to grant admin consent.

## 1. Deploy the Azure resources

The Bicep template provisions a storage account, a workspace-based Application Insights
instance, a hosting plan, and the Function app.

```bash
az group create -n <resource-group> -l westeurope

az deployment group create \
  -g <resource-group> \
  -f infra/main.bicep \
  -p appName=spssitefactory-func planSku=Y1 \
     adminSiteUrl=https://contoso-admin.sharepoint.com \
     tenantUrl=https://contoso.sharepoint.com
```

| Parameter | Notes |
| --- | --- |
| `appName` | Base name for the Function app and related resources. |
| `planSku` | `Y1` (Consumption, lowest cost) or `EP1` (Premium, no cold start). |
| `adminSiteUrl` | SharePoint admin center URL. |
| `tenantUrl` | Tenant base URL used for communication site creation. |

## 2. Register the Entra ID application

The Function app authenticates to SharePoint with PnP app-only using an Entra ID
application and a certificate. The helper script wraps `Register-PnPAzureADApp`.

```powershell
$certPassword = Read-Host -AsSecureString
pwsh ./scripts/Register-SPSSiteFactoryApp.ps1 `
  -ApplicationName 'SPSSiteFactory' `
  -Tenant 'contoso.onmicrosoft.com' `
  -CertificatePassword $certPassword
```

The script requests `Sites.FullControl.All` (SharePoint) and the Graph permissions
needed to create groups and resolve users. An administrator must grant admin consent
when prompted. The script outputs the **ClientId** and **certificate thumbprint** and
writes the certificate files under `scripts/certs/` (gitignored).

## 3. Configure and deploy the Function app

Set the SharePoint settings on the Function app (if not already passed to Bicep), then
upload the certificate so app-only authentication can load it.

```bash
az functionapp config appsettings set -g <resource-group> -n spssitefactory-func --settings \
  TenantId=<tenant-guid> \
  ClientId=<client-id-from-step-2> \
  CertificateThumbprint=<thumbprint-from-step-2>

# Upload the PFX so WEBSITE_LOAD_CERTIFICATES can load it (or reference Key Vault)
az functionapp config ssl upload -g <resource-group> -n spssitefactory-func \
  --certificate-file ./scripts/certs/SPSSiteFactory.pfx --certificate-password <pfx-password>
```

Deploy the Function code:

```bash
cd functions
func azure functionapp publish spssitefactory-func
```

## Authentication options

| Option | When to use |
| --- | --- |
| Certificate app registration | Works in Azure and for local development; certificate rotation required. |
| Managed Identity | Cleaner in production (no secret rotation). Grant the Function app's system-assigned identity the SharePoint and Graph app roles, then connect with `Connect-PnPOnline -ManagedIdentity`. |

For V1, the certificate app registration is the simplest single path. Managed Identity is
recommended as a production hardening step.

## Cost and performance

- `Y1` Consumption is the cheapest option but has cold starts.
- `EP1` Premium keeps an instance warm and removes cold starts.
- Provisioning is asynchronous (queue worker), so cold starts do not affect the SPFx
  submission experience.
