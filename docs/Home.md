# SPSSiteFactory - SharePoint Online Site Factory

SPSSiteFactory is a governed site request and provisioning solution for SharePoint Online,
built with an SPFx web part, a SharePoint request list, and an automated provisioning backend.

## Key Features

- SPFx React web part (`SiteRequest`) that hosts a guided site request form with people pickers, live URL preview, and selectable site type cards.
- SharePoint list (`SiteFactoryRequests`) provisioned by an idempotent PnP PowerShell script, including fields, a custom admin view, and provisioning tracking columns.
- Provisioning backend as an Azure Function (PowerShell + PnP): an HTTP intake that enqueues requests and a queue worker that creates the site and updates the request status.
- Host-agnostic provisioning module reusable in an Azure Automation runbook or interactively.
- Governance options: a V1 direct-submit permission model and a stricter workflow/API-mediated model for tenants where requesters must not access the backing list.
- Azure infrastructure as Bicep, plus an Entra ID app registration helper script for app-only authentication.

## Documentation

For details on architecture, configuration, and operations, explore the links below:

- [Prerequisites](./Prerequisites)
- [Architecture](./Architecture)
- [Data Model](./Data-Model)
- [Provisioning Flow](./Provisioning-Flow)
- [Provisioning Function](./Provisioning-Function)
- [Azure Setup](./Azure-Setup)
- [Design Guidelines](./Design-Guidelines)
