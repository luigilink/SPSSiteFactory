#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Modules\SPSSiteFactory.Provisioning\SPSSiteFactory.Provisioning.psd1'
    Import-Module $modulePath -Force
}

Describe 'Resolve-SPSSiteFactorySiteAlias' {
    It 'lowercases and hyphenates a friendly alias' {
        Resolve-SPSSiteFactorySiteAlias -Alias 'Project Alpha' | Should -Be 'project-alpha'
    }

    It 'removes unsupported characters' {
        Resolve-SPSSiteFactorySiteAlias -Alias 'Projet Alpha!' | Should -Be 'projet-alpha'
    }

    It 'collapses repeated and trailing hyphens' {
        Resolve-SPSSiteFactorySiteAlias -Alias '  Hello   World--Team  ' | Should -Be 'hello-world-team'
    }

    It 'returns an empty string when nothing is usable' {
        Resolve-SPSSiteFactorySiteAlias -Alias '???' | Should -Be ''
    }
}

Describe 'Test-SPSSiteFactoryRequest' {
    It 'returns no errors for a valid request' {
        $request = @{
            SiteName       = 'Project Alpha'
            SiteAlias      = 'project-alpha'
            SiteType       = 'TeamSite'
            PrimaryOwner   = 'amber@contoso.com'
            SecondaryOwner = 'adil@contoso.com'
        }
        Test-SPSSiteFactoryRequest -Request $request | Should -BeNullOrEmpty
    }

    It 'flags a missing site name' {
        $request = @{
            SiteName       = ''
            SiteAlias      = 'project-alpha'
            SiteType       = 'TeamSite'
            PrimaryOwner   = 'amber@contoso.com'
            SecondaryOwner = 'adil@contoso.com'
        }
        Test-SPSSiteFactoryRequest -Request $request | Should -Contain 'SiteName is required.'
    }

    It 'flags an invalid alias' {
        $request = @{
            SiteName       = 'Project Alpha'
            SiteAlias      = 'Project Alpha'
            SiteType       = 'TeamSite'
            PrimaryOwner   = 'amber@contoso.com'
            SecondaryOwner = 'adil@contoso.com'
        }
        Test-SPSSiteFactoryRequest -Request $request | Should -Contain 'SiteAlias must contain only lowercase letters, numbers, and hyphens.'
    }

    It 'flags an unsupported site type' {
        $request = @{
            SiteName       = 'Project Alpha'
            SiteAlias      = 'project-alpha'
            SiteType       = 'WikiSite'
            PrimaryOwner   = 'amber@contoso.com'
            SecondaryOwner = 'adil@contoso.com'
        }
        Test-SPSSiteFactoryRequest -Request $request | Should -Contain 'SiteType must be one of: TeamSite, CommunicationSite.'
    }

    It 'flags identical owners' {
        $request = @{
            SiteName       = 'Project Alpha'
            SiteAlias      = 'project-alpha'
            SiteType       = 'TeamSite'
            PrimaryOwner   = 'amber@contoso.com'
            SecondaryOwner = 'amber@contoso.com'
        }
        Test-SPSSiteFactoryRequest -Request $request | Should -Contain 'PrimaryOwner and SecondaryOwner must be different.'
    }
}
