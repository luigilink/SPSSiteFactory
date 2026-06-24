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

$connectionParameters = @{
    TenantId              = $env:TenantId
    ClientId              = $env:ClientId
    CertificateThumbprint = $env:CertificateThumbprint
}

Write-Information "Provisioning request item $itemId from $requestSiteUrl (run $runId)."

$siteUrl = Invoke-SPSSiteFactoryProvisioning `
    -RequestSiteUrl $requestSiteUrl `
    -ItemId $itemId `
    -ConnectionParameters $connectionParameters `
    -TenantUrl $env:TenantUrl `
    -RunId $runId

Write-Information "Provisioning completed for item $itemId. Site URL: $siteUrl."
