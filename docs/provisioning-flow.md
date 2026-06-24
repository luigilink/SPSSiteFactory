# Provisioning flow

This document describes the target provisioning flow for SPSSiteFactory.

## V1 flow

```text
1. User opens the SPFx request form.
2. User enters site metadata, owners, and justification.
3. SPFx validates required fields and URL alias.
4. SPFx creates an item in SiteFactoryRequests.
5. Workflow picks up the submitted request.
6. Workflow sets status to Provisioning.
7. Workflow creates the SharePoint Online site.
8. Workflow updates SiteUrl, ProvisioningLog, and Status.
```

## Status transitions

```text
Draft
  -> Submitted
  -> Approved
  -> Provisioning
  -> Completed

Provisioning
  -> Failed
```

For the first MVP, the `Approved` step may be optional if the project starts without an approval workflow.

## Provisioning responsibilities

The provisioning layer should:

- validate that the request is still eligible for provisioning;
- create the requested SharePoint Online site;
- apply the selected template when available;
- assign primary and secondary owners;
- write the final site URL back to the request item;
- write meaningful error details when provisioning fails.

## Candidate provisioning engines

| Engine | Strengths | Trade-offs |
| --- | --- | --- |
| Power Automate | Quick MVP, easy to connect to SharePoint list events. | Less flexible for advanced provisioning logic and source control. |
| Azure Function | More robust, testable, and product-like. | Requires more initial setup. |
| GitHub Actions | Useful for packaging and release. | Not ideal as the primary runtime for per-request provisioning. |

## Current recommendation

Start with the simplest working path for V1, while keeping the model compatible with a later Azure Function-based provisioning engine.
