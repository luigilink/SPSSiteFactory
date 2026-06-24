# Cold-start initialization for the SPSSiteFactory Function app.
#
# App-only PnP connections target a specific site, so the connection is established
# per invocation by the provisioning module rather than globally here. This file only
# imports the shared provisioning module and validates the required configuration.

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Modules/SPSSiteFactory.Provisioning/SPSSiteFactory.Provisioning.psd1" -Force

$requiredSettings = @('TenantId', 'ClientId', 'AdminSiteUrl')
$missingSettings = @($requiredSettings | Where-Object -FilterScript { [System.String]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable($_)) })

if ($missingSettings.Count -gt 0) {
    Write-Warning "SPSSiteFactory Function app is missing settings: $($missingSettings -join ', ')"
}
