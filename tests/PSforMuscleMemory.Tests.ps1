$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\..\PSforMuscleMemory.psd1" -Force

function Assert-Equal($actual, $expected) {
    if ($actual -cne $expected) { throw "Expected [$expected], got [$actual]" }
}
function Assert-Rejected($line) {
    $rejected = $false
    try { ConvertFrom-MuscleMemoryCommand $line | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw "Expected rejection: $line" }
}
function Assert-True($condition, $message) {
    if (-not $condition) { throw $message }
}

Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /s') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Recurse"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'DiR "a b" /S') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath 'a b' -Recurse"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "RD /s 'a''b'") "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'a''b' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'rd "a[1]" /S') "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'a[1]' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "rd /s 'a''; Write-Host nope'") "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'a''; Write-Host nope' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'Get-ChildItem .') 'Get-ChildItem .'
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'rd folder') 'rd folder'

@(
    'rd /s',
    'rd /s /q',
    'rd /s x -WhatIf:$false',
    'rd /s x -Confirm:$false',
    'rd /s x -Force',
    'rd /s x y',
    'rd /s /s x',
    'rd /s $path',
    'rd /s "a$path"',
    'rd /s (Get-Item x)',
    'rd /s x; rd y',
    'rd /s x | Out-Null',
    'rd /s x > output.txt',
    '& rd /s x',
    'rd /s,x -Recurse',
    'rd /s:$false x',
    'rd /s` x',
    'dir /s x /q',
    'rd /s ""'
) | ForEach-Object { Assert-Rejected $_ }

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("PSforMuscleMemory-" + [guid]::NewGuid())
$nested = Join-Path $fixture 'nested'
$file = Join-Path $nested 'keep.txt'
New-Item -ItemType Directory -Path $nested | Out-Null
Set-Content -LiteralPath $file -Value 'keep'
$escaped = $fixture.Replace("'", "''")
$translated = ConvertFrom-MuscleMemoryCommand "rd /s '$escaped'"
Assert-True ($translated.EndsWith(' -Recurse -WhatIf')) 'Translation must include explicit WhatIf.'
$WhatIfPreference = $false
$PSDefaultParameterValues['*:WhatIf'] = $false
& ([scriptblock]::Create($translated))
$PSDefaultParameterValues.Remove('*:WhatIf')
Assert-True (Test-Path -LiteralPath $fixture -PathType Container) 'Preview removed the fixture.'
Assert-True (Test-Path -LiteralPath $file -PathType Leaf) 'Preview removed the nested file.'

Import-Module PSReadLine -MinimumVersion 2.2
$original = Get-PSReadLineKeyHandler -Chord Enter
Assert-True ($null -eq (Get-PSReadLineOption).CommandValidationHandler) 'Test requires no existing validation handler.'
try {
    Enable-PSforMuscleMemory
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function 'PSforMuscleMemory-ValidateEnter'
    Enable-PSforMuscleMemory
    Disable-PSforMuscleMemory
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function $original.Function

    Set-PSReadLineKeyHandler -Chord Enter -ScriptBlock {} -BriefDescription 'ExistingTestHandler'
    $rejected = $false
    try { Enable-PSforMuscleMemory } catch { $rejected = $true }
    Assert-True $rejected 'Existing custom Enter binding must not be overwritten.'
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function 'ExistingTestHandler'
    Set-PSReadLineKeyHandler -Chord Enter -Function $original.Function

    Set-PSReadLineOption -CommandValidationHandler { param($commandAst) }
    $rejected = $false
    try { Enable-PSforMuscleMemory } catch { $rejected = $true }
    Assert-True $rejected 'Existing validation handler must not be overwritten.'
    Assert-True ($null -ne (Get-PSReadLineOption).CommandValidationHandler) 'Existing validation handler was lost.'
    Set-PSReadLineOption -CommandValidationHandler $null

    Set-PSReadLineKeyHandler -Chord Enter -Function ValidateAndAcceptLine
    Enable-PSforMuscleMemory
    Disable-PSforMuscleMemory
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function 'ValidateAndAcceptLine'
    Set-PSReadLineKeyHandler -Chord Enter -Function $original.Function

    $editMode = (Get-PSReadLineOption).EditMode
    Set-PSReadLineOption -EditMode Vi
    $rejected = $false
    try { Enable-PSforMuscleMemory } catch { $rejected = $true }
    Assert-True $rejected 'Vi mode must not be modified.'
    Set-PSReadLineOption -EditMode $editMode
    Set-PSReadLineKeyHandler -Chord Enter -Function $original.Function

    Enable-PSforMuscleMemory
    Set-PSReadLineKeyHandler -Chord Enter -ScriptBlock {} -BriefDescription 'ReplacementTestHandler'
    Disable-PSforMuscleMemory
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function 'ReplacementTestHandler'
    Set-PSReadLineKeyHandler -Chord Enter -Function $original.Function

    Enable-PSforMuscleMemory
    Remove-Module PSforMuscleMemory
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function $original.Function
} finally {
    Set-PSReadLineOption -CommandValidationHandler $null
    Set-PSReadLineKeyHandler -Chord Enter -Function $original.Function
}

Write-Host "All tests passed. Preview fixture retained at $fixture"
