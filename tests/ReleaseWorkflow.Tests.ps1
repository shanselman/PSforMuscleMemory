$ErrorActionPreference = 'Stop'
Import-Module PowerShellGet -MinimumVersion 2.2.5 -MaximumVersion 2.99

$workflow = Get-Content -LiteralPath "$PSScriptRoot\..\.github\workflows\publish.yml" -Raw
# Execute only the endpoint guard, never the publishing step.
$match = [regex]::Match($workflow, '(?ms)^          if \(\$repository\.SourceLocation.*?(?=^          PowerShellGet\\Publish-Module)')
if (-not $match.Success) { throw 'Could not find the workflow endpoint guard.' }
$guard = [scriptblock]::Create($match.Value)
$official = & (Get-Module PowerShellGet) {
    [pscustomobject]@{
        SourceLocation = $script:PSGallerySourceUri
        PublishLocation = $script:PSGalleryPublishUri
    }
}
if (-not $official.SourceLocation -or -not $official.PublishLocation) {
    throw 'PowerShellGet Gallery constants are missing.'
}

foreach ($repository in @(
    $official
    [pscustomobject]@{
        SourceLocation = $official.SourceLocation.TrimEnd('/') + '/'
        PublishLocation = $official.PublishLocation.TrimEnd('/')
    }
)) {
    & $guard
}

foreach ($repository in @(
    [pscustomobject]@{
        SourceLocation = 'https://example.com/api/v2'
        PublishLocation = $official.PublishLocation
    }
    [pscustomobject]@{
        SourceLocation = $official.SourceLocation
        PublishLocation = 'https://example.com/api/v2/package/'
    }
)) {
    $rejected = $false
    try { & $guard } catch {
        if ($_.Exception.Message -cne 'PSGallery must use the official PowerShell Gallery source and publish endpoints.') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'The workflow accepted a non-Gallery endpoint.' }
}
Write-Output 'Release workflow endpoint tests passed. No publishing command invoked.'
