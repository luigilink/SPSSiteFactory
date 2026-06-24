# SPSSiteFactory provisioning Function app

PowerShell Azure Function app that provisions SharePoint Online sites from SPSSiteFactory requests.

## Architecture

```text
SPFx web part
  -> writes the request item (Status = Submitted) to SiteFactoryRequests
  -> calls SubmitSiteRequest (HTTP)

SubmitSiteRequest (HTTP trigger)
  -> validates the message
  -> enqueues it on the sps-provisioning-requests queue
  -> returns 202 Accepted

ProvisionSite (Queue trigger)
  -> connects app-only with PnP.PowerShell
  -> creates the SharePoint Online site
  -> updates Status, SiteUrl, and provisioning tracking fields
```

The provisioning logic lives in the host-agnostic module
`Modules/SPSSiteFactory.Provisioning`, so it can also run in an Azure Automation
runbook or interactively for testing.

## Components

| Path | Purpose |
| --- | --- |
| `host.json` | Function host configuration and extension bundle. |
| `requirements.psd1` | Managed dependency on PnP.PowerShell. |
| `profile.ps1` | Cold-start module import and settings check. |
| `SubmitSiteRequest/` | HTTP intake that validates and enqueues a request. |
| `ProvisionSite/` | Queue worker that provisions the site. |
| `Modules/SPSSiteFactory.Provisioning/` | Host-agnostic provisioning logic. |
| `tests/` | Pester tests for the pure helpers. |

## Required settings

Copy `local.settings.json.example` to `local.settings.json` (gitignored) and fill in:

| Setting | Description |
| --- | --- |
| `AzureWebJobsStorage` | Storage connection (use Azurite locally). |
| `TenantId` | Entra ID tenant id. |
| `ClientId` | Entra ID application (client) id with `Sites.FullControl.All`. |
| `CertificateThumbprint` | Certificate thumbprint for app-only authentication. |
| `AdminSiteUrl` | SharePoint admin center URL. |
| `TenantUrl` | Tenant base URL (used to build communication site URLs). |

## Hosting notes

- PnP.PowerShell 3.x requires the PowerShell 7.4 Functions runtime.
- Use a Premium or App Service plan to avoid cold starts in production.
- The provisioning identity needs elevated permissions; requesters do not need direct
  access to the list when this Function app performs the writes.

## Local development

```bash
# Requires Azure Functions Core Tools and Azurite
cd functions
func start
```

## Tests

```powershell
Invoke-Pester ./tests
```
