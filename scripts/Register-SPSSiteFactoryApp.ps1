<#PSScriptInfo
    .VERSION 0.1.0

    .GUID 2c7e4b9a-3d61-4f0a-9b8c-1e5a7d2f6c34

    .AUTHOR luigilink (Jean-Cyril DROUHIN)

    .COPYRIGHT

    .TAGS
    script powershell azure entra appregistration sharepoint sitefactory

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
    Register the Entra ID application used by the SPSSiteFactory Function app.

    .DESCRIPTION
    Register-SPSSiteFactoryApp.ps1 creates the Entra ID application registration that the
    provisioning Function app uses for PnP app-only authentication. It relies on the
    PnP.PowerShell Register-PnPAzureADApp cmdlet, which creates the application, generates
    a self-signed certificate, uploads it, and requests the required SharePoint and Microsoft
    Graph application permissions.

    Granting admin consent is a privileged operation. The cmdlet opens the consent prompt
    interactively; an Entra ID administrator must approve the permissions.

    .PARAMETER ApplicationName
    Display name of the Entra ID application registration.

    .PARAMETER Tenant
    Tenant domain, for example contoso.onmicrosoft.com.

    .PARAMETER OutPath
    Folder where the generated certificate files are written. Defaults to a local certs
    folder next to this script (covered by .gitignore).

    .PARAMETER CertificatePassword
    Secure password protecting the generated PFX certificate.

    .PARAMETER LogPath
    Optional log file path. When omitted, logs are written under a local logs folder.

    .EXAMPLE
    $pwd = Read-Host -AsSecureString
    .\Register-SPSSiteFactoryApp.ps1 -ApplicationName 'SPSSiteFactory' -Tenant 'contoso.onmicrosoft.com' -CertificatePassword $pwd

    .NOTES
    FileName:   Register-SPSSiteFactoryApp.ps1
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
    [Parameter()]
    [System.String]
    $ApplicationName = 'SPSSiteFactory',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Tenant,

    [Parameter()]
    [System.String]
    $OutPath,

    [Parameter()]
    [System.Security.SecureString]
    $CertificatePassword,

    [Parameter()]
    [System.String]
    $LogPath
)

#region Initialization
$ErrorActionPreference = 'Stop'

$spsSiteFactoryVersion = '0.1.0'

$baseDir = if ([System.String]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }

if ([System.String]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path -Path $baseDir -ChildPath 'certs'
}

if ([System.String]::IsNullOrWhiteSpace($LogPath)) {
    $logDir = Join-Path -Path $baseDir -ChildPath 'logs'
    $LogPath = Join-Path -Path $logDir -ChildPath ('Register-SPSSiteFactoryApp_' + (Get-Date -Format 'yyyy-MM-dd_H-mm') + '.log')
}

$script:LogFile = $LogPath

$sharePointPermissions = @('Sites.FullControl.All')
$graphPermissions = @('Group.ReadWrite.All', 'User.Read.All')
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
#endregion

#region main
Write-SPSSiteFactoryLog -Message '--------------------------------------------------------------'
Write-SPSSiteFactoryLog -Message "SPSSiteFactory Script Version: $spsSiteFactoryVersion"
Write-SPSSiteFactoryLog -Message "Application name: $ApplicationName"
Write-SPSSiteFactoryLog -Message "Tenant: $Tenant"
Write-SPSSiteFactoryLog -Message "Certificate output: $OutPath"
Write-SPSSiteFactoryLog -Message "Log file: $script:LogFile"
Write-SPSSiteFactoryLog -Message '--------------------------------------------------------------'

try {
    Test-SPSSiteFactoryPrerequisite

    if (-not (Test-Path -Path $OutPath)) {
        New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
    }

    Write-SPSSiteFactoryLog -Message "Registering Entra ID application '$ApplicationName' ..."
    Write-SPSSiteFactoryLog -Message "Requesting SharePoint permissions: $($sharePointPermissions -join ', ')"
    Write-SPSSiteFactoryLog -Message "Requesting Microsoft Graph permissions: $($graphPermissions -join ', ')"
    Write-SPSSiteFactoryLog -Message 'An Entra ID administrator must grant admin consent when prompted.' -Level Warning

    $registerParams = @{
        ApplicationName                  = $ApplicationName
        Tenant                           = $Tenant
        OutPath                          = $OutPath
        Interactive                      = $true
        SharePointApplicationPermissions = $sharePointPermissions
        GraphApplicationPermissions      = $graphPermissions
    }

    if ($null -ne $CertificatePassword) {
        $registerParams['CertificatePassword'] = $CertificatePassword
    }

    $app = Register-PnPAzureADApp @registerParams

    Write-SPSSiteFactoryLog -Message 'Application registered successfully.' -Level Success
    Write-SPSSiteFactoryLog -Message "ClientId: $($app.'AzureAppId/ClientId')"
    Write-SPSSiteFactoryLog -Message "Certificate thumbprint: $($app.'Certificate Thumbprint')"
    Write-SPSSiteFactoryLog -Message 'Set ClientId and CertificateThumbprint on the Function app, and upload the generated PFX (or use Key Vault).'
    Write-SPSSiteFactoryLog -Message 'Completed successfully.' -Level Success

    $app
}
catch {
    $catchMessage = @"
SPSSiteFactory application registration failed.
ApplicationName: $ApplicationName
Tenant: $Tenant
Exception: $($_.Exception.Message)
StackTrace: $($_.ScriptStackTrace)
"@
    Write-SPSSiteFactoryLog -Message $catchMessage -Level Error
    throw
}
Exit
#endregion
