# SPSSiteFactory

SharePoint Online site factory built with SPFx, SharePoint Lists, and automated provisioning workflows.

## Vision

SPSSiteFactory aims to provide a governed and extensible way to request, approve, provision, and track SharePoint Online sites.

The first version focuses on a simple but solid foundation:

- an SPFx user experience to submit site creation requests;
- a SharePoint list to store requests, metadata, status, and provisioning results;
- an automation layer to provision SharePoint Online sites;
- clear governance rules for naming, ownership, templates, and lifecycle.

## Planned architecture

```text
SPFx request form
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

## Documentation

- [Roadmap](ROADMAP.md)
- [Architecture](docs/architecture.md)
- [Data model](docs/data-model.md)
- [Provisioning flow](docs/provisioning-flow.md)

## Status

This project is in early design phase. The initial goal is to define the MVP, repository structure, data model, and provisioning approach before scaffolding the SPFx application.
