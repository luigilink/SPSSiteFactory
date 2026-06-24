# SPSSiteFactory

SharePoint Online site factory built with SPFx, SharePoint Lists, and automated provisioning workflows.

## Vision

SPSSiteFactory aims to provide a governed and extensible way to request, approve, provision, and track SharePoint Online sites.

The first version focuses on a simple but solid foundation:

- an SPFx React web part that hosts the site request form;
- a SharePoint list to store requests, metadata, status, and provisioning results;
- an automation layer to provision SharePoint Online sites;
- clear governance rules for naming, ownership, templates, and lifecycle.

## Planned architecture

```text
SPFx SiteRequest web part
request form UI
        |
        v
SharePoint list: SiteFactoryRequests
        |
        v
Provisioning workflow
        |
        v
SharePoint Online site
```

## SharePoint Framework solution

| Property | Value |
| --- | --- |
| Solution name | `sps-site-factory` |
| SPFx version | `1.23.0` |
| Component type | Web Part |
| Web part name | `SiteRequest` |
| Framework | React |
| Node version | `22` |

The business feature is still a site request form. For V1, this form is implemented as an SPFx React web part rather than a SharePoint list form customizer.

## Repository structure

```text
SPSSiteFactory/
├── spfx/        # SPFx solution (SiteRequest web part)
├── functions/   # Azure Function (PowerShell + PnP) provisioning backend
├── scripts/     # PnP PowerShell provisioning scripts
├── infra/       # Bicep infrastructure
├── docs/        # Documentation (published to the wiki)
└── .github/     # CI workflows and community files
```

## Getting started

The SPFx solution lives in `spfx/` and the provisioning automation in `scripts/`,
`functions/`, and `infra/`. Build the web part, provision the request list, and deploy
the backend by following the [Getting Started](https://github.com/luigilink/SPSSiteFactory/wiki/Getting-Started)
guide on the wiki.

## Documentation

Full documentation is published to the [SPSSiteFactory wiki](https://github.com/luigilink/SPSSiteFactory/wiki):

- [Getting Started](https://github.com/luigilink/SPSSiteFactory/wiki/Getting-Started)
- [Prerequisites](https://github.com/luigilink/SPSSiteFactory/wiki/Prerequisites)
- [Architecture](https://github.com/luigilink/SPSSiteFactory/wiki/Architecture)
- [Data Model](https://github.com/luigilink/SPSSiteFactory/wiki/Data-Model)
- [Provisioning Flow](https://github.com/luigilink/SPSSiteFactory/wiki/Provisioning-Flow)
- [Azure Setup](https://github.com/luigilink/SPSSiteFactory/wiki/Azure-Setup)

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the V1 to V4 plan.

## Change log

A full list of changes is available in the [change log](CHANGELOG.md).

## Code of conduct

This project adopts the [Contributor Covenant](CODE_OF_CONDUCT.md).
