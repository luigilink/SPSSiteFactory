using namespace System.Net

# HTTP intake for SPSSiteFactory site requests.
#
# The SPFx web part first creates the request item in the SiteFactoryRequests list,
# then calls this endpoint with the request site URL and the new item id. This function
# only validates the message and enqueues it, then returns 202 Accepted immediately so
# the user experience never waits for the (slow, asynchronous) site provisioning.

param($Request, $TriggerMetadata)

$ErrorActionPreference = 'Stop'

$body = $Request.Body
$requestSiteUrl = $body.requestSiteUrl
$itemId = $body.itemId

$validationErrors = [System.Collections.Generic.List[string]]::new()

if ([System.String]::IsNullOrWhiteSpace($requestSiteUrl)) {
    $validationErrors.Add('requestSiteUrl is required.')
}

if (-not ($itemId -as [System.Int32]) -or [System.Int32]$itemId -le 0) {
    $validationErrors.Add('itemId must be a positive integer.')
}

if ($validationErrors.Count -gt 0) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ errors = $validationErrors.ToArray() }
        })
    return
}

$message = @{
    requestSiteUrl = [System.String]$requestSiteUrl
    itemId         = [System.Int32]$itemId
    enqueuedAt     = (Get-Date).ToString('o')
} | ConvertTo-Json -Compress

Push-OutputBinding -Name ProvisioningQueue -Value $message

Write-Information "Enqueued provisioning request for item $itemId on $requestSiteUrl."

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Accepted
        Body       = @{
            status = 'Queued'
            itemId = [System.Int32]$itemId
        }
    })
