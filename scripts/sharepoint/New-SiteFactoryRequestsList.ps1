<#PSScriptInfo
    .VERSION 0.1.0

    .GUID 8f8d9f1d-0d0f-4f8e-9a48-7a47a9b43b7d

    .AUTHOR luigilink (Jean-Cyril DROUHIN)

    .COPYRIGHT

    .TAGS
    script powershell sharepoint online sitefactory provisioning

    .LICENSEURI
    https://github.com/luigilink/SPSSiteFactory/blob/main/LICENSE

    .PROJECTURI
    https://github.com/luigilink/SPSSiteFactory

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    PnP.PowerShell

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
    Create or update the SPSSiteFactory SharePoint request list.

    .DESCRIPTION
    New-SiteFactoryRequestsList.ps1 provisions the SiteFactoryRequests list used by the SPSSiteFactory SPFx web part.
    The script is idempotent: it creates the list and missing fields, keeps existing fields, and can optionally configure
    the V1 direct-submit governance model.

    .PARAMETER SiteUrl
    Target SharePoint Online site URL that will host the SiteFactoryRequests list.

    .PARAMETER RequestersGroup
    SharePoint group granted Contribute permissions on the SiteFactoryRequests list when ConfigurePermissions is used.

    .PARAMETER AdministratorsGroup
    SharePoint group granted Full Control permissions on the SiteFactoryRequests list when ConfigurePermissions is used.

    .PARAMETER ClientId
    Optional Entra ID application client ID used by PnP.PowerShell interactive authentication.

    .PARAMETER LogPath
    Optional log file path. When omitted, logs are written under a local logs folder next to this script.

    .PARAMETER ConfigurePermissions
    Configure the V1 direct-submit permission model on the list.

    .PARAMETER SkipConnect
    Reuse the current PnP.PowerShell context instead of connecting interactively.

    .EXAMPLE
    .\New-SiteFactoryRequestsList.ps1 -SiteUrl https://contoso.sharepoint.com/sites/sitefactory

    .EXAMPLE
    .\New-SiteFactoryRequestsList.ps1 -SiteUrl https://contoso.sharepoint.com/sites/sitefactory `
        -ConfigurePermissions `
        -RequestersGroup 'Site Factory Requesters' `
        -AdministratorsGroup 'Site Factory Administrators'

    .NOTES
    FileName:   New-SiteFactoryRequestsList.ps1
    Author:     luigilink (Jean-Cyril DROUHIN)
    Version:    0.1.0
    Licence:    MIT License
    Requires:   PowerShell 7.2 or later, PnP.PowerShell

    .LINK
    https://github.com/luigilink/SPSSiteFactory
#>
#Requires -Version 7.2
#Requires -PSEdition Core
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $SiteUrl,

    [Parameter()]
    [System.String]
    $RequestersGroup,

    [Parameter()]
    [System.String]
    $AdministratorsGroup,

    [Parameter()]
    [System.String]
    $ClientId,

    [Parameter()]
    [System.String]
    $LogPath,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $ConfigurePermissions,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $SkipConnect
)

#region Initialization
$ErrorActionPreference = 'Stop'

$spsSiteFactoryVersion = '0.1.0'
$listTitle = 'SiteFactoryRequests'

if ([System.String]::IsNullOrWhiteSpace($LogPath)) {
    $baseDir = if ([System.String]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
    $logDir = Join-Path -Path $baseDir -ChildPath 'logs'
    $LogPath = Join-Path -Path $logDir -ChildPath ('New-SiteFactoryRequestsList_' + (Get-Date -Format 'yyyy-MM-dd_H-mm') + '.log')
}

$script:LogFile = $LogPath
#endregion

#region functions
function Write-SPSSiteFactoryLog {
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateSet('Error', 'Information', 'Warning', 'Success')]
        [System.String]
        $Level = 'Information'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level.ToUpperInvariant(), $Message

    switch ($Level) {
        'Error' {
            Write-Error -Message $line -ErrorAction Continue
        }
        'Warning' {
            Write-Warning -Message $line
        }
        default {
            Write-Output $line
        }
    }

    if (-not [System.String]::IsNullOrWhiteSpace($script:LogFile)) {
        try {
            $logFolder = Split-Path -Path $script:LogFile -Parent
            if (-not [System.String]::IsNullOrWhiteSpace($logFolder) -and -not (Test-Path -Path $logFolder)) {
                New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
            }
            Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
        }
        catch {
            Write-Warning -Message "Unable to write log file '$script:LogFile'. Exception: $($_.Exception.Message)"
        }
    }
}

function Test-SPSSiteFactoryPrerequisite {
    param ()

    Write-SPSSiteFactoryLog -Message 'Checking prerequisites ...'

    if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
        $catchMessage = @"
PowerShell 7 or later is required.
Current PowerShell version: $($PSVersionTable.PSVersion)
Current PowerShell edition: $($PSVersionTable.PSEdition)
Run this script with pwsh.
"@
        Write-Error -Message $catchMessage
    }

    if (-not (Get-Module -ListAvailable -Name 'PnP.PowerShell')) {
        $catchMessage = @"
PnP.PowerShell module is not installed.
Install it with:
Install-Module PnP.PowerShell -Scope CurrentUser
"@
        Write-Error -Message $catchMessage
    }

    Write-SPSSiteFactoryLog -Message 'Prerequisites are valid.' -Level Success
}

function Connect-SPSSiteFactoryOnline {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Url,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Skip
    )

    if ($Skip) {
        Write-SPSSiteFactoryLog -Message 'Skipping PnP connection (-SkipConnect); reusing the existing context.' -Level Warning
        return
    }

    Write-SPSSiteFactoryLog -Message "Connecting to $Url ..."

    $connectParams = @{
        Url         = $Url
        Interactive = $true
    }

    # PnP.PowerShell 2.x and later may require an Entra ID application ID for interactive authentication.
    if (-not [System.String]::IsNullOrWhiteSpace($ApplicationId)) {
        $connectParams['ClientId'] = $ApplicationId
    }

    try {
        Connect-PnPOnline @connectParams

        if ($null -eq (Get-PnPContext)) {
            throw "Connection to '$Url' did not establish a PnP context."
        }

        Write-SPSSiteFactoryLog -Message "Connected to $Url" -Level Success
    }
    catch {
        $catchMessage = @"
An error occurred while connecting to SharePoint Online.
SiteUrl: $Url
Exception: $($_.Exception.Message)
"@
        Write-Error -Message $catchMessage
    }
}

function Add-SPSSiteFactoryList {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Title
    )

    $list = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue

    if ($null -eq $list) {
        Write-SPSSiteFactoryLog -Message "Creating list '$Title' ..."
        New-PnPList -Title $Title -Template GenericList -EnableContentTypes:$false | Out-Null
        Write-SPSSiteFactoryLog -Message "List '$Title' created." -Level Success
    }
    else {
        Write-SPSSiteFactoryLog -Message "List '$Title' already exists - skipping."
    }
}

function Add-SPSSiteFactoryField {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $List,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InternalName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [Parameter()]
        [System.Boolean]
        $Required = $false,

        [Parameter()]
        [System.String[]]
        $Choices = @()
    )

    $field = Get-PnPField -List $List -Identity $InternalName -ErrorAction SilentlyContinue

    if ($null -ne $field) {
        Write-SPSSiteFactoryLog -Message "Field '$InternalName' already exists - skipping."
        return
    }

    Write-SPSSiteFactoryLog -Message "Creating $Type field '$InternalName' ($DisplayName) ..."

    try {
        if ($Type -eq 'Choice') {
            Add-PnPField -List $List -InternalName $InternalName -DisplayName $DisplayName -Type $Type -Required:$Required -Choices $Choices | Out-Null
        }
        else {
            Add-PnPField -List $List -InternalName $InternalName -DisplayName $DisplayName -Type $Type -Required:$Required | Out-Null
        }

        Write-SPSSiteFactoryLog -Message "Field '$InternalName' created." -Level Success
    }
    catch {
        $catchMessage = @"
An error occurred while creating field '$InternalName'.
List: $List
DisplayName: $DisplayName
Type: $Type
Exception: $($_.Exception.Message)
"@
        Write-Error -Message $catchMessage
    }
}

function Add-SPSSiteFactoryUserField {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $List,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InternalName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.Boolean]
        $Required = $false
    )

    Add-SPSSiteFactoryField -List $List -InternalName $InternalName -DisplayName $DisplayName -Type User -Required $Required
}

function Set-SPSSiteFactoryListGovernance {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $List,

        [Parameter()]
        [System.String]
        $Requesters,

        [Parameter()]
        [System.String]
        $Administrators
    )

    Write-SPSSiteFactoryLog -Message "Applying governance settings to '$List' ..."

    try {
        Set-PnPList -Identity $List -Hidden $true | Out-Null
        Set-PnPList -Identity $List -ReadSecurity 2 -WriteSecurity 2 | Out-Null
        Set-PnPList -Identity $List -BreakRoleInheritance -CopyRoleAssignments:$false -ClearSubscopes:$true | Out-Null

        if (-not [System.String]::IsNullOrWhiteSpace($Requesters)) {
            Write-SPSSiteFactoryLog -Message "Granting 'Contribute' to group '$Requesters'."
            Set-PnPListPermission -Identity $List -Group $Requesters -AddRole 'Contribute' | Out-Null
        }
        else {
            Write-SPSSiteFactoryLog -Message "No requesters group supplied - skipping 'Contribute' grant." -Level Warning
        }

        if (-not [System.String]::IsNullOrWhiteSpace($Administrators)) {
            Write-SPSSiteFactoryLog -Message "Granting 'Full Control' to group '$Administrators'."
            Set-PnPListPermission -Identity $List -Group $Administrators -AddRole 'Full Control' | Out-Null
        }
        else {
            Write-SPSSiteFactoryLog -Message "No administrators group supplied - skipping 'Full Control' grant." -Level Warning
        }

        Write-SPSSiteFactoryLog -Message "Governance settings applied to '$List'." -Level Success
    }
    catch {
        $catchMessage = @"
An error occurred while applying list governance.
List: $List
RequestersGroup: $Requesters
AdministratorsGroup: $Administrators
Exception: $($_.Exception.Message)
"@
        Write-Error -Message $catchMessage
    }
}

function Set-SPSSiteFactoryDefaultField {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $List
    )

    Write-SPSSiteFactoryLog -Message "Renaming default 'Title' column to 'Request Title'."
    Set-PnPField -List $List -Identity 'Title' -Values @{ Title = 'Request Title' } | Out-Null
}

function Add-SPSSiteFactoryListView {
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $List,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Title,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Fields,

        [Parameter()]
        [System.Boolean]
        $SetAsDefault = $false
    )

    $view = Get-PnPView -List $List -Identity $Title -ErrorAction SilentlyContinue

    if ($null -ne $view) {
        Write-SPSSiteFactoryLog -Message "View '$Title' already exists - skipping."
        return
    }

    Write-SPSSiteFactoryLog -Message "Creating view '$Title' ..."

    try {
        Add-PnPView -List $List -Title $Title -Fields $Fields -ViewType Html -SetAsDefault:$SetAsDefault | Out-Null
        Write-SPSSiteFactoryLog -Message "View '$Title' created." -Level Success
    }
    catch {
        $catchMessage = @"
An error occurred while creating view '$Title'.
List: $List
Fields: $($Fields -join ', ')
Exception: $($_.Exception.Message)
"@
        Write-Error -Message $catchMessage
    }
}
#endregion

#region main
Write-SPSSiteFactoryLog -Message '--------------------------------------------------------------'
Write-SPSSiteFactoryLog -Message "SPSSiteFactory Script Version: $spsSiteFactoryVersion"
Write-SPSSiteFactoryLog -Message "Target site: $SiteUrl"
Write-SPSSiteFactoryLog -Message "List title: $listTitle"
Write-SPSSiteFactoryLog -Message "Log file: $script:LogFile"
Write-SPSSiteFactoryLog -Message '--------------------------------------------------------------'

try {
    Test-SPSSiteFactoryPrerequisite
    Connect-SPSSiteFactoryOnline -Url $SiteUrl -ApplicationId $ClientId -Skip:$SkipConnect

    Add-SPSSiteFactoryList -Title $listTitle

    Add-SPSSiteFactoryField -List $listTitle -InternalName 'SiteName' -DisplayName 'Site Name' -Type Text -Required $true
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'SiteAlias' -DisplayName 'Site Alias' -Type Text -Required $true
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'SiteType' -DisplayName 'Site Type' -Type Choice -Required $true -Choices @('TeamSite', 'CommunicationSite')
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'TemplateKey' -DisplayName 'Template Key' -Type Text
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'Description' -DisplayName 'Description' -Type Note
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'BusinessJustification' -DisplayName 'Business Justification' -Type Note -Required $true
    Add-SPSSiteFactoryUserField -List $listTitle -InternalName 'PrimaryOwner' -DisplayName 'Primary Owner' -Required $true
    Add-SPSSiteFactoryUserField -List $listTitle -InternalName 'SecondaryOwner' -DisplayName 'Secondary Owner' -Required $true
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'HubSite' -DisplayName 'Hub Site' -Type Text
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'Sensitivity' -DisplayName 'Sensitivity' -Type Choice -Choices @('Public', 'Internal', 'Confidential')
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'Status' -DisplayName 'Status' -Type Choice -Required $true -Choices @('Draft', 'Submitted', 'Approved', 'Provisioning', 'Completed', 'Failed')
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'SiteUrl' -DisplayName 'Site Url' -Type URL
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'ProvisioningLog' -DisplayName 'Provisioning Log' -Type Note
    Add-SPSSiteFactoryUserField -List $listTitle -InternalName 'RequestedBy' -DisplayName 'Requested By' -Required $true
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'RequestedDate' -DisplayName 'Requested Date' -Type DateTime -Required $true
    Add-SPSSiteFactoryUserField -List $listTitle -InternalName 'ApprovedBy' -DisplayName 'Approved By'
    Add-SPSSiteFactoryField -List $listTitle -InternalName 'ApprovedDate' -DisplayName 'Approved Date' -Type DateTime

    Set-SPSSiteFactoryDefaultField -List $listTitle
    Add-SPSSiteFactoryListView -List $listTitle -Title 'All Requests' -Fields @(
        'Title',
        'SiteName',
        'SiteAlias',
        'SiteType',
        'Status',
        'PrimaryOwner',
        'SecondaryOwner',
        'RequestedBy',
        'RequestedDate',
        'SiteUrl'
    ) -SetAsDefault $true

    if ($ConfigurePermissions) {
        Set-SPSSiteFactoryListGovernance -List $listTitle -Requesters $RequestersGroup -Administrators $AdministratorsGroup
    }
    else {
        Write-SPSSiteFactoryLog -Message 'Permissions not configured. Use -ConfigurePermissions to apply the V1 governance model.' -Level Warning
    }

    Write-SPSSiteFactoryLog -Message "List '$listTitle' is ready on $SiteUrl" -Level Success
    Write-SPSSiteFactoryLog -Message 'Completed successfully.' -Level Success
}
catch {
    $catchMessage = @"
SPSSiteFactory list provisioning failed.
SiteUrl: $SiteUrl
ListTitle: $listTitle
Exception: $($_.Exception.Message)
StackTrace: $($_.ScriptStackTrace)
"@
    Write-SPSSiteFactoryLog -Message $catchMessage -Level Error
    throw
}
Exit
#endregion
