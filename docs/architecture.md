# Architecture

SPSSiteFactory is organized around three independent layers: user experience, request tracking, and provisioning.

## Logical components

```text
+---------------------+
| SPFx request form   |
| React web part      |
+---------------------+
          |
          v
+-----------------------------+
| SharePoint request list     |
| SiteFactoryRequests         |
+-----------------------------+
          |
          v
+-----------------------------+
| Provisioning orchestrator   |
| Power Automate / Function   |
+-----------------------------+
          |
          v
+-----------------------------+
| SharePoint Online site      |
+-----------------------------+
```

## Component responsibilities

| Component | Responsibility |
| --- | --- |
| SPFx request form web part | Capture and validate user input before submission. |
| SharePoint request list | Store request metadata, ownership, status, logs, and final site URL. |
| Provisioning orchestrator | Execute the provisioning process and update request status. |
| Provisioning templates | Define reusable site configuration patterns. |
| Admin views | Help administrators monitor requests and failures. |

## V1 architecture direction

The V1 architecture should stay intentionally simple:

- The SPFx React web part writes requests to the `SiteFactoryRequests` list.
- The provisioning workflow reads list items and updates status fields.
- Provisioning errors are stored on the request item for traceability.
- Site creation supports a limited number of well-known site types.

## Future architecture direction

Later versions may introduce:

- Azure Function-based provisioning API;
- Microsoft Graph integration;
- PnP provisioning templates;
- richer admin dashboard;
- lifecycle review jobs;
- GitHub Actions build and release pipeline.
