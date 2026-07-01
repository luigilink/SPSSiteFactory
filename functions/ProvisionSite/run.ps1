# Queue worker for SPSSiteFactory site provisioning.
#
# Triggered by a message on the sps-provisioning-requests queue. The message identifies
# the request site URL and the list item id. The worker connects app-only with PnP and
# delegates the provisioning flow to the shared SPSSiteFactory.Provisioning module.

param($QueueItem, $TriggerMetadata)

$ErrorActionPreference = 'Stop'

if ($QueueItem -is [System.String]) {
    $message = $QueueItem | ConvertFrom-Json
}
else {
    $message = $QueueItem
}

$requestSiteUrl = $message.requestSiteUrl
$itemId = [System.Int32]$message.itemId
$runId = [System.String]$TriggerMetadata.Id

if ([System.String]::IsNullOrWhiteSpace($requestSiteUrl) -or $itemId -le 0) {
    throw "Invalid provisioning message: $($QueueItem | Out-String)"
}

function Get-SPSSiteFactoryKeyVaultSecret {
    <#
        .SYNOPSIS
        Retrieve a Key Vault secret value using the Function's managed identity.

        .DESCRIPTION
        Uses the App Service / Functions managed identity endpoint (IDENTITY_ENDPOINT and
        IDENTITY_HEADER) to acquire a Key Vault token and read the secret. This avoids
        relying on the platform @Microsoft.KeyVault app-setting reference and works on Linux
        Functions where the certificate cannot be loaded from an X509 store.

        .PARAMETER SecretUri
        Full data-plane URI of the Key Vault secret (without an explicit version to always
        read the latest).
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $SecretUri
    )

    $identityEndpoint = $env:IDENTITY_ENDPOINT
    $identityHeader = $env:IDENTITY_HEADER

    if ([System.String]::IsNullOrWhiteSpace($identityEndpoint) -or [System.String]::IsNullOrWhiteSpace($identityHeader)) {
        throw 'Managed identity endpoint is not available; cannot read the certificate from Key Vault.'
    }

    $tokenResponse = Invoke-RestMethod -Method Get `
        -Uri "${identityEndpoint}?resource=https://vault.azure.net&api-version=2019-08-01" `
        -Headers @{ 'X-IDENTITY-HEADER' = $identityHeader }

    $secretResponse = Invoke-RestMethod -Method Get `
        -Uri "${SecretUri}?api-version=7.4" `
        -Headers @{ Authorization = "Bearer $($tokenResponse.access_token)" }

    return $secretResponse.value
}

$connectionParameters = if ($env:UseManagedIdentity -eq 'true') {
    Write-Information 'Connection mode: managed identity.'
    @{ UseManagedIdentity = $true }
}
elseif (-not [System.String]::IsNullOrWhiteSpace($env:CertificateSecretUri)) {
    Write-Information "Connection mode: Key Vault certificate secret ($($env:CertificateSecretUri))."
    @{
        TenantId                 = $env:TenantId
        ClientId                 = $env:ClientId
        CertificateBase64Encoded = Get-SPSSiteFactoryKeyVaultSecret -SecretUri $env:CertificateSecretUri
    }
}
elseif (-not [System.String]::IsNullOrWhiteSpace($env:CertificateBase64)) {
    Write-Information 'Connection mode: inline base64 certificate.'
    @{
        TenantId                 = $env:TenantId
        ClientId                 = $env:ClientId
        CertificateBase64Encoded = $env:CertificateBase64
    }
}
else {
    Write-Information 'Connection mode: certificate thumbprint (local store).'
    @{
        TenantId              = $env:TenantId
        ClientId              = $env:ClientId
        CertificateThumbprint = $env:CertificateThumbprint
    }
}

Write-Information "Provisioning request item $itemId from $requestSiteUrl (run $runId)."

$siteUrl = Invoke-SPSSiteFactoryProvisioning `
    -RequestSiteUrl $requestSiteUrl `
    -ItemId $itemId `
    -ConnectionParameters $connectionParameters `
    -TenantUrl $env:TenantUrl `
    -RunId $runId

Write-Information "Provisioning completed for item $itemId. Site URL: $siteUrl."
