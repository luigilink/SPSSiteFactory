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

## Getting started

Use Node 22 before installing or running the project:

```bash
nvm use
npm install
npm run build
```

Start the local SPFx workbench:

```bash
npm run start
```

## Documentation

- [Roadmap](ROADMAP.md)
- [Architecture](docs/architecture.md)
- [Data model](docs/data-model.md)
- [Design guidelines](docs/design-guidelines.md)
- [Provisioning flow](docs/provisioning-flow.md)

## Status

This project is in early implementation phase. The initial SPFx React web part has been scaffolded and the next goal is to replace the generated sample UI with the first site request form.
