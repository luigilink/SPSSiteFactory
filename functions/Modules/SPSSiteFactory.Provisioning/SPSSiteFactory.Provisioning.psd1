@{
    RootModule        = 'SPSSiteFactory.Provisioning.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b3d2f7a1-9c4e-4e2a-8f1b-2a6c5d4e7f90'
    Author            = 'luigilink (Jean-Cyril DROUHIN)'
    CompanyName       = 'luigilink'
    Copyright         = '(c) luigilink. MIT License.'
    Description       = 'Host-agnostic provisioning logic for SPSSiteFactory site requests. Designed to run inside an Azure Function, an Azure Automation runbook, or interactively.'
    PowerShellVersion = '7.4'
    # PnP.PowerShell is provided by the host (Function app requirements.psd1) and is
    # intentionally not declared here so the pure helpers can be imported without it.
    RequiredModules   = @()
    FunctionsToExport = @(
        'Connect-SPSSiteFactory',
        'Test-SPSSiteFactoryRequest',
        'Resolve-SPSSiteFactorySiteAlias',
        'Get-SPSSiteFactoryRequest',
        'Set-SPSSiteFactoryRequestStatus',
        'New-SPSSiteFactorySite',
        'Invoke-SPSSiteFactoryProvisioning'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('SharePoint', 'SPO', 'Provisioning', 'PnP', 'SPSSiteFactory')
            LicenseUri = 'https://github.com/luigilink/SPSSiteFactory/blob/main/LICENSE'
            ProjectUri = 'https://github.com/luigilink/SPSSiteFactory'
        }
    }
}
