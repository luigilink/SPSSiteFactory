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
  -p appName=spssitefactory-func planSku=B1 \
     adminSiteUrl=https://contoso-admin.sharepoint.com \
     tenantUrl=https://contoso.sharepoint.com
```

| Parameter | Notes |
| --- | --- |
| `appName` | Base name for the Function app and related resources. |
| `planSku` | `B1` (Basic Linux, default), `Y1` (Consumption), or `EP1` (Premium, no cold start). |
| `adminSiteUrl` | SharePoint admin center URL. |
| `tenantUrl` | Tenant base URL used for communication site creation. |

The Function app is deployed on **Linux** with **identity-based storage access**
(system-assigned managed identity), not shared storage keys. See
[Tenant security constraints](#tenant-security-constraints) for the rationale.

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

On Linux Functions the certificate cannot be loaded from a Windows X509 store, and
`WEBSITE_LOAD_CERTIFICATES` does not mount it. The Function therefore loads the
certificate from **Key Vault** at runtime using its managed identity. The Bicep template
already provisions the vault and grants the identity the **Key Vault Secrets User** role.

Generate the app-only certificate **inside** the vault (its private key never leaves
Key Vault) and register its public key on the Entra ID application:

```bash
rg=<resource-group>
kv=$(az deployment group show -g $rg -n main --query properties.outputs.keyVaultName.value -o tsv)
appId=<client-id-from-step-2>

# 1. Generate a self-signed certificate in Key Vault
az keyvault certificate create --vault-name $kv -n spssitefactory-provisioning \
  -p "$(az keyvault certificate get-default-policy)"

# 2. Download the public key and register it on the app registration
az keyvault certificate download --vault-name $kv -n spssitefactory-provisioning \
  -f ./provisioning.cer -e DER
objId=$(az ad app show --id $appId --query id -o tsv)
key=$(base64 -i ./provisioning.cer | tr -d '\n')
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/applications/$objId" \
  --headers "Content-Type=application/json" \
  --body "{\"keyCredentials\":[{\"type\":\"AsymmetricX509Cert\",\"usage\":\"Verify\",\"key\":\"$key\",\"displayName\":\"SPSSiteFactory KV cert\"}]}"
rm ./provisioning.cer
```

Set the remaining SharePoint settings (if not already passed to Bicep). `CertificateSecretUri`
is wired by the template, so app-only auth works as soon as the certificate exists:

```bash
az functionapp config appsettings set -g $rg -n spssitefactory-func --settings \
  TenantId=<tenant-guid> \
  ClientId=$appId
```

Deploy the Function code (the `--powershell` flag is required):

```bash
cd functions
func azure functionapp publish spssitefactory-func --powershell
```

## Authentication options

| Option | When to use |
| --- | --- |
| **Key Vault certificate** (default in Azure) | The certificate is generated in Key Vault and read at runtime via the Function's managed identity (`CertificateSecretUri` → `Connect-PnPOnline -CertificateBase64Encoded`). Works on Linux Functions and yields both SharePoint REST and Graph tokens. Rotatable without redeploying code. |
| Certificate thumbprint (local dev) | On a developer Windows machine the certificate lives in the user store and is used with `-Thumbprint`. Not usable on Linux Functions. |
| Managed Identity only | `Connect-PnPOnline -ManagedIdentity` yields a **Graph-only** token, so SharePoint REST cmdlets (`Get-/Set-PnPListItem`, communication-site creation) return **401**. Insufficient on its own for this workload. |

> Why not just upload the PFX to the app service or use `-Thumbprint`? On **Linux** Function
> Apps there is no Windows certificate store, and `WEBSITE_LOAD_CERTIFICATES` does not mount
> the certificate under `/var/ssl/private`. Loading the certificate bytes from Key Vault is
> the reliable app-only path, and keeping the private key in Key Vault (audit, rotation, no
> cleartext secret in app settings) is the production-grade choice.

## 4. Secure the intake API (Easy Auth + SPFx)

The `SubmitSiteRequest` HTTP trigger uses `authLevel: anonymous` so that **App Service
Authentication (Easy Auth)** is the single authentication gate. Callers must present a
valid Entra token audienced to a dedicated API app registration, and only the SharePoint
SPFx principal is allowed through.

### 4.1 Register the API app (App B)

This is separate from the app-only provisioning app so the user-facing API surface carries
no application permissions.

```bash
apiAppId=$(az ad app create --display-name "SPSSiteFactory-Api" \
  --sign-in-audience AzureADMyOrg --query appId -o tsv)
az ad app update --id $apiAppId --identifier-uris "api://$apiAppId"
# Expose a user_impersonation delegated scope (portal: Expose an API), then create the SP:
az ad sp create --id $apiAppId
```

### 4.2 Configure Easy Auth

Pass `apiClientId` (App B) to Bicep, or configure it directly. `spfxPrincipalAppId`
defaults to the SharePoint Online Web Client Extensibility principal
(`08e18876-6177-487e-b8b5-cf950c1e598c`):

```bash
az deployment group create -g <resource-group> -f infra/main.bicep \
  -p appName=spssitefactory-func apiClientId=$apiAppId
```

The resulting policy: unauthenticated → **401**; valid token from a non-allowed app →
**403**; valid token from the SPFx principal → the request reaches the function.

### 4.3 Wire and approve the SPFx side

- `config/package-solution.json` requests the API scope:

  ```json
  "webApiPermissionRequests": [
    { "resource": "api://<apiAppId>", "scope": "user_impersonation" }
  ]
  ```

- After uploading the `.sppkg`, an administrator approves the request in the SharePoint
  admin center under **Advanced → API access**. This grants the SharePoint principal the
  `user_impersonation` scope so `AadHttpClient` can obtain tokens.
- Configure the web part properties: **Provisioning function URL** =
  `https://<func>.azurewebsites.net/api/submitsiterequest`, **resource URI** =
  `api://<apiAppId>`.

## Cost and performance

- `B1` Basic is a small always-on plan suitable for steady low-volume provisioning.
- `Y1` Consumption is the cheapest option but has cold starts.
- `EP1` Premium keeps an instance warm and removes cold starts.
- Provisioning is asynchronous (queue worker), so cold starts do not affect the SPFx
  submission experience.

## Tenant security constraints

Some Microsoft 365 / Azure tenants (for example MCAP and other managed environments)
enforce Azure Policies that harden storage accounts. The two that affect this project:

| Constraint | Impact | How the template handles it |
| --- | --- | --- |
| Storage **shared key access disabled** (`allowSharedKeyAccess = false`) | A classic Windows Consumption Function App fails during creation with `403 Forbidden` because it needs an account-key connection string for its content file share. | The Function uses **identity-based storage** (`AzureWebJobsStorage__accountName` + service URIs) and its managed identity is granted **Storage Blob Data Owner** and **Storage Queue Data Contributor**. No shared key is used. |
| Windows content file share requires Azure Files with a key | Even with identity-based `AzureWebJobsStorage`, a Windows plan still provisions a content share on Azure Files, which needs a key. | The Function app runs on **Linux** (`kind: functionapp,linux`, `reserved: true`, `linuxFxVersion: POWERSHELL|7.4`), which does not require the Windows content file share. |
| App-only **certificate** cannot be loaded on Linux | `Connect-PnPOnline -Thumbprint` needs a Windows X509 store, and `WEBSITE_LOAD_CERTIFICATES` does not mount the certificate under `/var/ssl/private` on Function Apps Linux. | The certificate lives in **Key Vault**; the Function reads it via its managed identity (**Key Vault Secrets User**) and connects with `Connect-PnPOnline -CertificateBase64Encoded`. |

If your tenant does **not** enforce these policies, a `Y1` Windows Consumption plan with a
storage connection string also works and is cheaper. The Linux + managed identity setup is
the safe default that works in both cases.
