#region module variables
$script:SiteRequestListTitle = 'SiteFactoryRequests'

$script:SiteRequestStatus = @{
    Draft        = 'Draft'
    Submitted    = 'Submitted'
    Approved     = 'Approved'
    Provisioning = 'Provisioning'
    Completed    = 'Completed'
    Failed       = 'Failed'
}

$script:SupportedSiteTypes = @('TeamSite', 'CommunicationSite')
#endregion

#region pure helpers
function Resolve-SPSSiteFactorySiteAlias {
    <#
        .SYNOPSIS
        Normalize a requested site alias into a URL-safe value.

        .DESCRIPTION
        Lowercases the alias, replaces whitespace with hyphens, removes unsupported
        characters, and collapses repeated or trailing hyphens so the result matches
        the SPFx alias rule: lowercase letters, numbers, and hyphens only.

        .PARAMETER Alias
        The requested alias to normalize.

        .EXAMPLE
        Resolve-SPSSiteFactorySiteAlias -Alias 'Project Alpha!'
        # returns 'project-alpha'
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Alias
    )

    $normalized = $Alias.Trim().ToLowerInvariant()
    $normalized = $normalized -replace '\s+', '-'
    $normalized = $normalized -replace '[^a-z0-9-]', ''
    $normalized = $normalized -replace '-{2,}', '-'
    $normalized = $normalized.Trim('-')

    return $normalized
}

function Test-SPSSiteFactoryRequest {
    <#
        .SYNOPSIS
        Validate a site request payload before provisioning.

        .DESCRIPTION
        Returns an array of human-readable validation errors. An empty array means the
        request is valid. This helper is pure (no SharePoint calls) so it can be unit
        tested without a tenant.

        .PARAMETER Request
        A hashtable or object exposing SiteName, SiteAlias, SiteType, PrimaryOwner, and
        SecondaryOwner.
    #>
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]
        $Request
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    if ([System.String]::IsNullOrWhiteSpace($Request['SiteName'])) {
        $errors.Add('SiteName is required.')
    }

    $alias = [System.String]$Request['SiteAlias']
    if ([System.String]::IsNullOrWhiteSpace($alias)) {
        $errors.Add('SiteAlias is required.')
    }
    elseif ($alias -cnotmatch '^[a-z0-9-]+$') {
        $errors.Add('SiteAlias must contain only lowercase letters, numbers, and hyphens.')
    }

    if ($Request['SiteType'] -notin $script:SupportedSiteTypes) {
        $errors.Add("SiteType must be one of: $($script:SupportedSiteTypes -join ', ').")
    }

    if ([System.String]::IsNullOrWhiteSpace($Request['PrimaryOwner'])) {
        $errors.Add('PrimaryOwner is required.')
    }

    if ([System.String]::IsNullOrWhiteSpace($Request['SecondaryOwner'])) {
        $errors.Add('SecondaryOwner is required.')
    }

    if (-not [System.String]::IsNullOrWhiteSpace($Request['PrimaryOwner']) -and
        $Request['PrimaryOwner'] -eq $Request['SecondaryOwner']) {
        $errors.Add('PrimaryOwner and SecondaryOwner must be different.')
    }

    return $errors.ToArray()
}
#endregion

#region connection
function Connect-SPSSiteFactory {
    <#
        .SYNOPSIS
        Open an app-only PnP connection to a SharePoint Online site.

        .DESCRIPTION
        Wraps Connect-PnPOnline using an Entra ID application (client id) and a
        certificate thumbprint. Falling back to interactive auth is only intended for
        local development.

        .PARAMETER Url
        Target site URL to connect to.

        .PARAMETER TenantId
        Entra ID tenant id.

        .PARAMETER ClientId
        Entra ID application (client) id.

        .PARAMETER CertificateThumbprint
        Certificate thumbprint used for app-only authentication.

        .PARAMETER Interactive
        Use interactive authentication instead of app-only (local development only).
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Url,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $ClientId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Interactive
    )

    try {
        if ($Interactive) {
            Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId
            return
        }

        Connect-PnPOnline -Url $Url -ClientId $ClientId -Tenant $TenantId -Thumbprint $CertificateThumbprint

        if ($null -eq (Get-PnPContext)) {
            throw "Connection to '$Url' did not establish a PnP context."
        }
    }
    catch {
        $catchMessage = @"
An error occurred while connecting to SharePoint Online.
Url: $Url
Exception: $($_.Exception.Message)
"@
        throw $catchMessage
    }
}
#endregion

#region data access
function Get-SPSSiteFactoryRequest {
    <#
        .SYNOPSIS
        Read a site request list item.

        .DESCRIPTION
        Returns a hashtable of the request fields. The current PnP connection must point
        at the site hosting the SiteFactoryRequests list.

        .PARAMETER ItemId
        List item id of the request.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Int32]
        $ItemId
    )

    $item = Get-PnPListItem -List $script:SiteRequestListTitle -Id $ItemId -ErrorAction Stop

    return @{
        Id                    = $ItemId
        SiteName              = $item['SiteName']
        SiteAlias             = $item['SiteAlias']
        SiteType              = $item['SiteType']
        TemplateKey           = $item['TemplateKey']
        BusinessJustification = $item['BusinessJustification']
        PrimaryOwner          = $item.FieldValues['PrimaryOwner'].Email
        SecondaryOwner        = $item.FieldValues['SecondaryOwner'].Email
        Status                = $item['Status']
    }
}

function Set-SPSSiteFactoryRequestStatus {
    <#
        .SYNOPSIS
        Update the status and provisioning tracking fields of a request item.

        .DESCRIPTION
        Writes the lifecycle status and any supplied provisioning tracking values back to
        the SiteFactoryRequests list. The current PnP connection must point at the site
        hosting the list.

        .PARAMETER ItemId
        List item id of the request.

        .PARAMETER Status
        New lifecycle status value.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Int32]
        $ItemId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Draft', 'Submitted', 'Approved', 'Provisioning', 'Completed', 'Failed')]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $SiteUrl,

        [Parameter()]
        [System.String]
        $ProvisioningLog,

        [Parameter()]
        [System.String]
        $RunId,

        [Parameter()]
        [Nullable[System.DateTime]]
        $StartedDate,

        [Parameter()]
        [Nullable[System.DateTime]]
        $CompletedDate
    )

    $values = @{
        Status                  = $Status
        LastProvisioningAttempt = (Get-Date)
    }

    if (-not [System.String]::IsNullOrWhiteSpace($SiteUrl)) { $values['SiteUrl'] = $SiteUrl }
    if (-not [System.String]::IsNullOrWhiteSpace($ProvisioningLog)) { $values['ProvisioningLog'] = $ProvisioningLog }
    if (-not [System.String]::IsNullOrWhiteSpace($RunId)) { $values['ProvisioningRunId'] = $RunId }
    if ($null -ne $StartedDate) { $values['ProvisioningStartedDate'] = $StartedDate }
    if ($null -ne $CompletedDate) { $values['ProvisioningCompletedDate'] = $CompletedDate }

    if ($PSCmdlet.ShouldProcess("Request item $ItemId", "Set status to $Status")) {
        Set-PnPListItem -List $script:SiteRequestListTitle -Identity $ItemId -Values $values -ErrorAction Stop | Out-Null
    }
}
#endregion

#region provisioning
function New-SPSSiteFactorySite {
    <#
        .SYNOPSIS
        Create a SharePoint Online site for a request.

        .DESCRIPTION
        Creates a team site or a communication site using PnP.PowerShell and returns the
        created site URL.

        .PARAMETER SiteName
        Display name of the site.

        .PARAMETER SiteAlias
        URL-safe alias of the site.

        .PARAMETER SiteType
        TeamSite or CommunicationSite.

        .PARAMETER OwnerLogin
        Primary owner login or email.

        .PARAMETER TenantUrl
        Tenant base URL (required for communication sites to build the full URL).
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $SiteName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SiteAlias,

        [Parameter(Mandatory = $true)]
        [ValidateSet('TeamSite', 'CommunicationSite')]
        [System.String]
        $SiteType,

        [Parameter()]
        [System.String]
        $OwnerLogin,

        [Parameter()]
        [System.String]
        $TenantUrl
    )

    switch ($SiteType) {
        'TeamSite' {
            $createParams = @{
                Type  = 'TeamSite'
                Title = $SiteName
                Alias = $SiteAlias
            }
            if (-not [System.String]::IsNullOrWhiteSpace($OwnerLogin)) {
                $createParams['Owners'] = @($OwnerLogin)
            }
            $createdUrl = New-PnPSite @createParams -ErrorAction Stop
        }
        'CommunicationSite' {
            if ([System.String]::IsNullOrWhiteSpace($TenantUrl)) {
                throw 'TenantUrl is required to create a communication site.'
            }
            $siteFullUrl = ('{0}/sites/{1}' -f $TenantUrl.TrimEnd('/'), $SiteAlias)
            $createdUrl = New-PnPSite -Type CommunicationSite -Title $SiteName -Url $siteFullUrl -ErrorAction Stop
        }
    }

    # TODO (V2): apply a PnP provisioning template based on the request TemplateKey.

    return [System.String]$createdUrl
}

function Invoke-SPSSiteFactoryProvisioning {
    <#
        .SYNOPSIS
        Provision a SharePoint Online site from a submitted request.

        .DESCRIPTION
        Orchestrates the V1 provisioning flow:
        1. connect to the request site and mark the request as Provisioning;
        2. create the requested SharePoint Online site;
        3. write the result (Completed or Failed) and tracking fields back to the request.

        .PARAMETER RequestSiteUrl
        URL of the SharePoint site hosting the SiteFactoryRequests list.

        .PARAMETER ItemId
        List item id of the request to provision.

        .PARAMETER ConnectionParameters
        Hashtable of app-only connection parameters (TenantId, ClientId, CertificateThumbprint).

        .PARAMETER TenantUrl
        Tenant base URL used for communication site creation.

        .PARAMETER RunId
        Identifier of the current execution, stored on the request for traceability.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $RequestSiteUrl,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $ItemId,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $ConnectionParameters,

        [Parameter()]
        [System.String]
        $TenantUrl,

        [Parameter()]
        [System.String]
        $RunId
    )

    Connect-SPSSiteFactory @ConnectionParameters -Url $RequestSiteUrl
    $request = Get-SPSSiteFactoryRequest -ItemId $ItemId

    Set-SPSSiteFactoryRequestStatus -ItemId $ItemId -Status $script:SiteRequestStatus.Provisioning -RunId $RunId -StartedDate (Get-Date)

    try {
        $alias = Resolve-SPSSiteFactorySiteAlias -Alias $request.SiteAlias
        $siteUrl = New-SPSSiteFactorySite `
            -SiteName $request.SiteName `
            -SiteAlias $alias `
            -SiteType $request.SiteType `
            -OwnerLogin $request.PrimaryOwner `
            -TenantUrl $TenantUrl

        # Reconnect to the request site because site creation changes the active context.
        Connect-SPSSiteFactory @ConnectionParameters -Url $RequestSiteUrl
        Set-SPSSiteFactoryRequestStatus `
            -ItemId $ItemId `
            -Status $script:SiteRequestStatus.Completed `
            -SiteUrl $siteUrl `
            -CompletedDate (Get-Date) `
            -ProvisioningLog "Site created successfully at $siteUrl."

        return $siteUrl
    }
    catch {
        $failureMessage = $_.Exception.Message

        Connect-SPSSiteFactory @ConnectionParameters -Url $RequestSiteUrl
        Set-SPSSiteFactoryRequestStatus `
            -ItemId $ItemId `
            -Status $script:SiteRequestStatus.Failed `
            -CompletedDate (Get-Date) `
            -ProvisioningLog "Provisioning failed: $failureMessage"

        throw
    }
}
#endregion

Export-ModuleMember -Function @(
    'Connect-SPSSiteFactory',
    'Test-SPSSiteFactoryRequest',
    'Resolve-SPSSiteFactorySiteAlias',
    'Get-SPSSiteFactoryRequest',
    'Set-SPSSiteFactoryRequestStatus',
    'New-SPSSiteFactorySite',
    'Invoke-SPSSiteFactoryProvisioning'
)
