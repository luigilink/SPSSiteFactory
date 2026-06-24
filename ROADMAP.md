# SPSSiteFactory Roadmap

SPSSiteFactory is a SharePoint Online site factory designed to standardize and automate site creation through an SPFx front end, SharePoint list-based request tracking, and automated provisioning workflows.

## Guiding principles

- Keep the first version simple, useful, and deployable.
- Store every request and provisioning outcome in SharePoint for traceability.
- Make governance visible to requesters before a site is created.
- Provide a clean and trustworthy user experience, not only a technical form.
- Separate the user experience, request data, and provisioning engine.
- Prefer extensible templates over hard-coded provisioning logic.

## V1 - Minimum viable site factory

Goal: allow users to submit site creation requests and provision basic SharePoint Online sites with traceable status.

### Scope

- SPFx React web part hosting the site request form.
- SharePoint list named `SiteFactoryRequests`.
- Request status lifecycle: `Draft`, `Submitted`, `Approved`, `Provisioning`, `Completed`, `Failed`.
- Support for basic site types:
  - Team site;
  - Communication site.
- Basic naming and URL validation.
- Site owner and secondary owner fields.
- Business justification field.
- Initial UX and visual design pass with clearer layout, spacing, colors, and guidance messages.
- Provisioning workflow triggered from a submitted or approved request.
- Provisioning result written back to the request item.
- Basic provisioning log and final site URL stored in the list.

### Exit criteria

- A requester can submit a site request from the SPFx UI.
- An administrator can review the request in the SharePoint list.
- A site can be provisioned from a valid request.
- The request item shows the final status, site URL, and provisioning result.
- The request form feels polished enough for an internal V1 preview.

## V2 - Governance and templates

Goal: add stronger governance, approval, and reusable site templates.

### Scope

- Approval workflow before provisioning.
- Template-driven provisioning definitions.
- Hub site association.
- Sensitivity and classification metadata.
- Initial members and visitors.
- Better provisioning logs.
- Retry or resume capability for failed requests.
- Admin dashboard for request follow-up.

### Exit criteria

- A request can go through an approval process.
- Templates can define site configuration consistently.
- Administrators can identify and troubleshoot failed provisioning attempts.

## V3 - Lifecycle and productization

Goal: evolve SPSSiteFactory into a more complete SharePoint Online site lifecycle management tool.

### Scope

- Lifecycle rules for review, expiration, and archival.
- Periodic owner review.
- Advanced admin dashboard.
- API layer for integrations.
- Configurable visual branding foundation for future company-specific customization.
- GitHub Actions for packaging and release.
- Multi-environment deployment guidance.
- Extended documentation and examples.

### Exit criteria

- SPSSiteFactory can support site creation and lifecycle review.
- The project has repeatable build, release, and deployment practices.
- Documentation is sufficient for another administrator or developer to deploy a working version.

## V4 - Enterprise customization

Goal: allow organizations to adapt the visual identity and request experience without changing the core product code.

### Scope

- Company-specific visual customization.
- Configurable logo, accent colors, and welcome text.
- Optional theme presets.
- Tenant-level or site-level UI configuration.
- Template-aware guidance text and form sections.

### Exit criteria

- An administrator can adjust key visual elements without rebuilding the SPFx package.
- The request form can align with an organization's branding while preserving SPSSiteFactory defaults.

## Open decisions

| Topic | Current direction | Status |
| --- | --- | --- |
| Provisioning engine | Power Automate for MVP, Azure Function as a possible evolution | Open |
| Authentication model | To be defined based on provisioning engine | Open |
| Template format | JSON-based templates | Proposed |
| SPFx shape | React web part hosting the request form for V1. List form customizer remains a possible future option. | Decided for V1 |
| Visual design | Improve V1 form polish now; defer deep company branding customization to V4. | Proposed |
| Deployment target | SharePoint Online tenant app catalog | Proposed |

## Next steps

1. Define the initial SharePoint list schema.
2. Decide whether V1 provisioning uses Power Automate or Azure Function.
3. Scaffold the SPFx project.
4. Build the first request form.
5. Implement the first provisioning path.
