@{
    # PSScriptAnalyzer settings for SPSSiteFactory.
    # Used by the pester.yml code-quality job and locally:
    #   Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1

    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Azure Functions entry points receive binding parameters (e.g. $Request,
        # $TriggerMetadata, $QueueItem) that are not always referenced. This rule would
        # flag them as unused even though the runtime requires them.
        'PSReviewUnusedParameter',

        # Write-Host is used intentionally for interactive script feedback.
        'PSAvoidUsingWriteHost'
    )

    Rules        = @{
        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSUseConsistentIndentation = @{
            Enable          = $true
            Kind            = 'space'
            IndentationSize = 4
        }
    }
}
