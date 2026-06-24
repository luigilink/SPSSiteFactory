# Prerequisites and governance

This document describes the initial prerequisites for deploying SPSSiteFactory and the governance choices around the `SiteFactoryRequests` list.

## Required components

- A dedicated SharePoint Online site that will host the SPFx web part and the `SiteFactoryRequests` list.
- A tenant app catalog for deploying the SPFx package.
- PowerShell 7.2 or later for provisioning scripts.
- PnP.PowerShell for provisioning the initial request list.
- A security group for requesters.
- A security group for site factory administrators.
- A provisioning identity or workflow owner for later site creation automation.

## SharePoint host site

SPSSiteFactory should be deployed to a dedicated SharePoint Online site instead of the tenant root site.

Recommended V1 setup:

| Setting | Recommendation |
| --- | --- |
| Site type | Team site |
| Site name | `SPSSiteFactory` |
| Site alias | `spssitefactory` |
| Site URL | `https://contoso.sharepoint.com/sites/spssitefactory` |
| Privacy | Private |

A dedicated site keeps request tracking, provisioning configuration, permissions, pages, and future admin views isolated from other collaboration spaces.

Install the PowerShell prerequisites:

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

Run provisioning scripts with `pwsh`, not Windows PowerShell 5.1.

## V1 direct-submit model

The current V1 implementation submits requests directly from the SPFx web part to the `SiteFactoryRequests` SharePoint list.

Because SPFx runs in the current user's context, requesters must have permission to add list items. The recommended V1 setup is:

| Audience | Permission |
| --- | --- |
| Requesters | Contribute on `SiteFactoryRequests`; read/edit limited to their own items. |
| Site factory administrators | Full Control on `SiteFactoryRequests`. |
| Provisioning engine | Permission required to read requests, update status, and create sites. |

The list may be hidden from navigation, but users with direct list permissions may still be able to reach it by URL depending on tenant and site settings.

## Strict governance model

If the requirement is: "users can access the form but cannot access the backing list", the SPFx web part should not write directly to the list.

Use one of these patterns instead:

| Pattern | Notes |
| --- | --- |
| Power Automate mediated submission | SPFx calls a workflow endpoint or writes to a controlled intake mechanism. The workflow writes to the list with its own permissions. |
| Azure Function API | SPFx calls an API secured with Entra ID. The function writes to SharePoint using application permissions or managed identity. |
| Future provisioning API | A productized API can validate requests, enforce governance, write to the list, and trigger provisioning. |

This stricter model is better for enterprise governance but requires more setup than the V1 direct-submit model.

## List provisioning

Create the list only:

```powershell
pwsh ./scripts/New-SiteFactoryRequestsList.ps1 -SiteUrl https://contoso.sharepoint.com/sites/sitefactory
```

Create the list and apply the V1 permission model:

```powershell
pwsh ./scripts/New-SiteFactoryRequestsList.ps1 `
  -SiteUrl https://contoso.sharepoint.com/sites/sitefactory `
  -ConfigurePermissions `
  -RequestersGroup "Site Factory Requesters" `
  -AdministratorsGroup "Site Factory Administrators"
```

## Open governance decisions

- Whether V1 keeps direct user-context submission or moves immediately to workflow/API-mediated submission.
- Whether requesters should be able to read their own submitted requests.
- Whether administrators manage requests only through list views or through a future admin dashboard.
- Which identity provisions sites and updates request status.

## Future repository documentation

The following repository documentation items are planned but not required for the current V1 list provisioning step:

- GitHub Wiki for installation, configuration, usage, and troubleshooting.
- `CHANGELOG.md` following the Keep a Changelog structure.
- GitHub Actions build and validation workflow for future packaging and release automation.
