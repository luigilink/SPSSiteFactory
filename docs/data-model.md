# Data model

The initial data model is centered on a SharePoint list named `SiteFactoryRequests`.

## SiteFactoryRequests

| Column | Type | Required | Description |
| --- | --- | --- | --- |
| Title | Single line of text | Yes | Friendly request title. |
| SiteName | Single line of text | Yes | Display name of the requested site. |
| SiteAlias | Single line of text | Yes | URL-friendly site alias. |
| SiteType | Choice | Yes | Requested site type, such as `TeamSite` or `CommunicationSite`. |
| TemplateKey | Choice or text | No | Provisioning template to apply. |
| Description | Multiple lines of text | No | Business description of the site. |
| BusinessJustification | Multiple lines of text | Yes | Reason for requesting the site. |
| PrimaryOwner | Person or Group | Yes | Main business owner of the site. |
| SecondaryOwner | Person or Group | Yes | Backup owner of the site. |
| HubSite | Choice or lookup | No | Optional hub site association. |
| Sensitivity | Choice | No | Business sensitivity or classification. |
| Status | Choice | Yes | Request lifecycle status. |
| SiteUrl | Hyperlink | No | Final site URL after provisioning. |
| ProvisioningLog | Multiple lines of text | No | Human-readable provisioning result or error details. |
| RequestedBy | Person or Group | Yes | User who submitted the request. |
| RequestedDate | Date and time | Yes | Request submission date. |
| ApprovedBy | Person or Group | No | Approver for governed scenarios. |
| ApprovedDate | Date and time | No | Approval date. |

## Status values

| Status | Meaning |
| --- | --- |
| Draft | Request is being prepared. |
| Submitted | Request has been submitted. |
| Approved | Request has been approved for provisioning. |
| Provisioning | Provisioning is in progress. |
| Completed | Site was created successfully. |
| Failed | Provisioning failed and needs attention. |

## Validation rules

- `SiteAlias` must be URL-safe.
- `SiteAlias` must be unique.
- `PrimaryOwner` and `SecondaryOwner` should be different users.
- `BusinessJustification` is required before submission.
- `SiteType` must map to a supported provisioning path.

## Provisioning helper

The initial list can be created with the PnP PowerShell helper script:

```powershell
pwsh ./scripts/sharepoint/New-SiteFactoryRequestsList.ps1 -SiteUrl https://contoso.sharepoint.com/sites/sitefactory
```

The script requires PowerShell 7.2 or later and PnP.PowerShell. It is idempotent and creates the fields expected by the SPFx submission service.

To apply the V1 direct-submit permission model:

```powershell
pwsh ./scripts/sharepoint/New-SiteFactoryRequestsList.ps1 `
  -SiteUrl https://contoso.sharepoint.com/sites/sitefactory `
  -ConfigurePermissions `
  -RequestersGroup "Site Factory Requesters" `
  -AdministratorsGroup "Site Factory Administrators"
```

## Permission model

The current V1 SPFx implementation writes directly to the `SiteFactoryRequests` list using the current user's SharePoint context. This means requesters must have permission to create list items.

The recommended V1 model is:

| Role | Permission |
| --- | --- |
| Requesters | Contribute on `SiteFactoryRequests`, with list item read/write restricted to their own items. |
| Administrators | Full Control on `SiteFactoryRequests`. |
| Provisioning identity | Permission level required by the selected provisioning engine. |

The list can be hidden from site navigation, but hiding is not a security boundary. If the requirement is that requesters have access to the form but no direct permission to the backing list, the project should move the submission step behind a trusted workflow or API such as Power Automate, Azure Function, or another app-only backend.
