# Provisioning flow

This document describes the target provisioning flow for SPSSiteFactory.

## V1 flow

```text
1. User opens the SPFx `SiteRequest` web part, which hosts the request form.
2. User enters site metadata, owners, and justification.
3. SPFx validates required fields and URL alias.
4. SPFx creates an item in SiteFactoryRequests.
5. Workflow picks up the submitted request.
6. Workflow records its run identifier and sets status to Provisioning.
7. Workflow creates the SharePoint Online site.
8. Workflow updates SiteUrl, ProvisioningLog, provisioning dates, and Status.
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
- record `ProvisioningRunId`, `LastProvisioningAttempt`, and `ProvisioningStartedDate`;
- create the requested SharePoint Online site;
- apply the selected template when available;
- assign primary and secondary owners;
- write the final site URL back to the request item;
- write `ProvisioningCompletedDate` when the request reaches `Completed` or `Failed`;
- write meaningful error details when provisioning fails.

## V1 tracking fields

| Field | Written by | Purpose |
| --- | --- | --- |
| Status | SPFx and provisioning engine | Current request lifecycle state. |
| ProvisioningRunId | Provisioning engine | Trace the Power Automate run or future API execution. |
| LastProvisioningAttempt | Provisioning engine | Show the latest processing attempt. |
| ProvisioningStartedDate | Provisioning engine | Show when the active attempt started. |
| ProvisioningCompletedDate | Provisioning engine | Show when provisioning finished or failed. |
| SiteUrl | Provisioning engine | Store the created SharePoint site URL. |
| ProvisioningLog | Provisioning engine | Store readable success or error details. |

## Power Automate V1 outline

1. Trigger when an item is created or modified.
2. Continue only when `Status` equals `Submitted` or `Approved`.
3. Update the item:
   - `Status = Provisioning`;
   - `ProvisioningRunId = workflow run id`;
   - `LastProvisioningAttempt = utcNow()`;
   - `ProvisioningStartedDate = utcNow()`.
4. Create the SharePoint Online site.
5. Apply basic ownership and template settings.
6. On success, update:
   - `Status = Completed`;
   - `SiteUrl = created site URL`;
   - `ProvisioningCompletedDate = utcNow()`;
   - `ProvisioningLog = success summary`.
7. On failure, update:
   - `Status = Failed`;
   - `ProvisioningCompletedDate = utcNow()`;
   - `ProvisioningLog = error summary`.

## Candidate provisioning engines

| Engine | Strengths | Trade-offs |
| --- | --- | --- |
| Power Automate | Quick MVP, easy to connect to SharePoint list events. | Less flexible for advanced provisioning logic and source control. |
| Azure Function | More robust, testable, and product-like. | Requires more initial setup. |
| GitHub Actions | Useful for packaging and release. | Not ideal as the primary runtime for per-request provisioning. |

## Current recommendation

Start with the simplest working path for V1, while keeping the model compatible with a later Azure Function-based provisioning engine.
