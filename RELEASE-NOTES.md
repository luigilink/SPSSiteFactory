# SPSSiteFactory - Release Notes

## Unreleased

### Added

- SPFx site request web part (`spfx/`)
  - Scaffold SPFx React solution hosting the `SiteRequest` web part
  - Site request form with a redesigned UX, client-side validation, and SCSS styling
  - People picker backed by `PeopleSearchService`
  - Submit requests to the `SiteFactoryRequests` list via `SiteRequestService`
  - Best-effort call to the provisioning Azure Function via `ProvisioningService` (`AadHttpClient`), with a non-blocking notice if the trigger fails (the request is already saved)
  - Web part properties for the Function URL and Entra resource URI, plus a `webApiPermissionRequests` declaration for admin approval
  - Typed models and constants (`ISiteRequestPayload`, `IPeoplePickerUser`, `siteRequestConstants`)
- SharePoint and provisioning automation (`scripts/`, `functions/`)
  - `New-SiteFactoryRequestsList.ps1` provisions and governs the `SiteFactoryRequests` list (typed fields, choices, item-level security, group permissions) with structured logging, top-level try/catch, `-ClientId` interactive auth, approved-verb functions, and `-WhatIf`/`-Confirm` support
  - `Register-SPSSiteFactoryApp.ps1` registers the Entra ID application
  - Azure Functions PowerShell app: `SubmitSiteRequest` and `ProvisionSite` HTTP triggers, the `SPSSiteFactory.Provisioning` module (with `-WhatIf`/`-Confirm` on site creation) and Pester tests, plus `host.json`, `profile.ps1`, `requirements.psd1`, and `local.settings.json.example`
- Infrastructure (`infra/`)
  - `main.bicep` and example parameters to deploy the required Azure resources
- Documentation (`docs/`)
  - `architecture.md`, `data-model.md`, `provisioning-flow.md`, `design-guidelines.md`, `prerequisites.md`, `azure-setup.md`, `Getting-Started.md`, `Home.md`
- Repository governance
  - Add `CODE_OF_CONDUCT.md`, `RELEASE-NOTES.md`, and `CHANGELOG.md`
  - Add `.github/` content: `CONTRIBUTING.md`, `PULL_REQUEST_TEMPLATE.md`, issue templates (bug, feature, documentation, improvement, config), and workflows
    - `release.yml` — package the `scripts/` folder as a tag-named release artifact
    - `pester.yml` — run PowerShell Pester tests
    - `wiki.yml` — publish documentation to the repository wiki
  - Add `PSScriptAnalyzerSettings.psd1` for PowerShell linting
  - Add code of conduct badge to `README.md`
  - Add `ROADMAP.md` with the UX and branding roadmap

### Changed

- `README.md`
  - Add vision, planned architecture, prerequisites, requirements, and changelog sections
  - Point documentation to the GitHub wiki and add Documentation, Roadmap, Change log, and Code of conduct sections
- Reorganize the repository — move the SPFx solution under `spfx/` and flatten the `scripts/` folder
- `PULL_REQUEST_TEMPLATE.md` — remove examples and unit-test tasks
- `.gitignore` — ignore SPFx and Azure Functions build outputs and secret files (e.g. `.env`, Azure Storage deploy keys)

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
