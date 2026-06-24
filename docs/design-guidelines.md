# Design guidelines

SPSSiteFactory should feel like a governed internal product, not a raw technical form.

## V1 design goals

- Improve readability with clear sections and visual hierarchy.
- Use spacing, cards, and guidance messages to reduce friction.
- Use SharePoint theme tokens where possible so the form fits naturally in Microsoft 365.
- Keep the UI professional, calm, and trustworthy.
- Avoid over-customization in V1; prioritize clarity and maintainability.

## V1 visual direction

The initial form should include:

- a clear header explaining the purpose of the request;
- grouped sections for site information, ownership, and justification;
- contextual helper text for fields such as site alias and owners;
- visible validation messages;
- a request summary before submission;
- restrained use of color for status and guidance.

## Color usage

| Use case | Direction |
| --- | --- |
| Primary actions | Use the current SharePoint theme primary color. |
| Informational guidance | Use subtle blue or neutral message styling. |
| Success state | Use Fluent UI success message styling. |
| Validation errors | Use Fluent UI error color tokens. |
| Cards and panels | Use neutral backgrounds and borders. |

## Future branding customization

Future versions may allow organizations to configure visual identity without changing the core SPFx code.

Candidate options:

- company logo;
- primary accent color;
- secondary accent color;
- welcome or help text;
- form header illustration;
- template-specific guidance text;
- tenant-level branding configuration list.

This should remain optional. SPSSiteFactory should always provide a clean default theme that works without custom configuration.
