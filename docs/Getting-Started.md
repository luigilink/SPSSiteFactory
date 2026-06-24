# Getting Started

## Prerequisites

- Node.js 22 (the SPFx solution pins it via `spfx/.nvmrc`)
- PowerShell 7.2 or later and the `PnP.PowerShell` module
- A dedicated SharePoint Online site to host the web part and the request list
- A SharePoint Online tenant app catalog for deploying the SPFx package

See [Prerequisites](./Prerequisites) for the full governance and permission details.

## Build the SPFx solution

The SPFx solution lives in `spfx/`. Use Node 22 before installing or running it:

```bash
cd spfx
nvm use
npm install
npm run build
```

Start the local SharePoint workbench:

```bash
cd spfx
npm run start
```

## Provision the request list

Create the `SiteFactoryRequests` list with PnP PowerShell:

```powershell
pwsh ./scripts/New-SiteFactoryRequestsList.ps1 -SiteUrl https://contoso.sharepoint.com/sites/spssitefactory
```

Create the list and apply the V1 direct-submit permission model:

```powershell
pwsh ./scripts/New-SiteFactoryRequestsList.ps1 `
  -SiteUrl https://contoso.sharepoint.com/sites/spssitefactory `
  -ConfigurePermissions `
  -RequestersGroup "Site Factory Requesters" `
  -AdministratorsGroup "Site Factory Administrators"
```

## Deploy the provisioning backend

The provisioning backend is an Azure Function (PowerShell + PnP). Follow
[Azure Setup](./Azure-Setup) to deploy the resources, register the Entra ID
application, and publish the Function app.

## Next Step

For the next steps, go to the [Architecture](./Architecture) and
[Provisioning Flow](./Provisioning-Flow) pages.

## Change log

A full list of changes in each version can be found in the
[change log](https://github.com/luigilink/SPSSiteFactory/blob/main/CHANGELOG.md).
