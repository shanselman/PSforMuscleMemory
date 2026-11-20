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
function Invoke-TestEnter($line, $state) {
    & (Get-Module PSforMuscleMemory) {
        param($testLine, $state)
        Invoke-MuscleMemoryLine $testLine {
            param($replacement)
            $state.Line = $replacement
            $state.Rewrites++
        } {
            $state.Accepts++
        }
    } $line $state
}

Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /s') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Recurse"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'DiR "a b" /S') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath 'a b' -Recurse"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'cd /d D:\work') "Microsoft.PowerShell.Management\Set-Location -LiteralPath 'D:\work'"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "CD /D 'a''b'") "Microsoft.PowerShell.Management\Set-Location -LiteralPath 'a''b'"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /b') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Name"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /b "a b"') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath 'a b' -Name"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /s *.txt') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter '*.txt' -Recurse"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'DiR /S *.txt') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter '*.txt' -Recurse"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /a') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Force"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /o:n') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' | Microsoft.PowerShell.Utility\Sort-Object -Property Name"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'dir /o:-d') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' | Microsoft.PowerShell.Utility\Sort-Object -Property LastWriteTime -Descending"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "RD /s 'a''b'") "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'a''b' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'rd "a[1]" /S') "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'a[1]' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'rd /s /q folder') "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'folder' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'rd folder /q /s') "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'folder' -Recurse -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'del /s *.txt') "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter '*.txt' -Recurse -File | Microsoft.PowerShell.Management\Remove-Item -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "DeL /S 'keep me.txt'") "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter 'keep me.txt' -Recurse -File | Microsoft.PowerShell.Management\Remove-Item -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'sort file.txt') "Microsoft.PowerShell.Management\Get-Content -LiteralPath 'file.txt' | Microsoft.PowerShell.Utility\Sort-Object"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'copy /y source.txt target.txt') "Microsoft.PowerShell.Management\Copy-Item -LiteralPath 'source.txt' -Destination 'target.txt' -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "copy 'source file.txt' 'target file.txt' /Y") "Microsoft.PowerShell.Management\Copy-Item -LiteralPath 'source file.txt' -Destination 'target file.txt' -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'move /y source.txt target.txt') "Microsoft.PowerShell.Management\Move-Item -LiteralPath 'source.txt' -Destination 'target.txt' -WhatIf"
Assert-Equal (ConvertFrom-MuscleMemoryCommand "rd /s 'a''; Write-Host nope'") "Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'a''; Write-Host nope' -Recurse -WhatIf"
foreach ($codePoint in 0x2018, 0x2019, 0x201A, 0x201B) {
    $literalPath = "a$([char]$codePoint); Write-Host nope"
    $rewrite = ConvertFrom-MuscleMemoryCommand "rd /s `"$literalPath`""
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($rewrite, [ref]$tokens, [ref]$parseErrors)
    $commands = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
    Assert-True ($parseErrors.Count -eq 0 -and $ast.EndBlock.Statements.Count -eq 1 -and $commands.Count -eq 1) "Smart quote $codePoint escaped the literal path."
    $command = $commands[0]
    Assert-Equal ($command.GetCommandName()) 'Microsoft.PowerShell.Management\Remove-Item'
    Assert-Equal $command.CommandElements[1].ParameterName 'LiteralPath'
    Assert-Equal $command.CommandElements[2].Value $literalPath
    Assert-True ($command.CommandElements[-1].ParameterName -ceq 'WhatIf' -and $null -eq $command.CommandElements[-1].Argument) "Smart quote $codePoint lost explicit -WhatIf."
}
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'Get-ChildItem .') 'Get-ChildItem .'
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'rd folder') 'rd folder'
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'Get-ChildItem | where Name') 'Get-ChildItem | where Name'
@(
    "Get-Process | where Path -like '/api/*'"
    'Get-Process | where Path -like /api/*'
    "Get-Process | where Path -eq '/r'"
    'Get-Content log.txt | where { $_ -like ''/api/*'' }'
) | ForEach-Object {
    $state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
    Assert-Equal (ConvertFrom-MuscleMemoryCommand $_) $_
    Invoke-TestEnter $_ $state
    Assert-True ($state.Rewrites -eq 0 -and $state.Accepts -eq 1) "Expected pass-through on first Enter: $_"
}
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'sort Name') 'sort Name'
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'gci | sort Name.Length') 'gci | sort Name.Length'
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'copy a.txt b.txt') 'copy a.txt b.txt'
Assert-Equal (ConvertFrom-MuscleMemoryCommand 'move a.txt b') 'move a.txt b'

@(
    'cd /d .',
    'dir /b',
    'dir /s *.txt',
    'dir /a',
    'dir /o:n',
    'dir /o:-d',
    'rd /s /q folder',
    'del /s *.txt',
    'sort file.txt',
    'copy /y source.txt target.txt',
    'move /y source.txt target.txt'
    if ($IsWindows) { 'where git' }
) | ForEach-Object {
    $state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
    Invoke-TestEnter $_ $state
    Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 0) "First Enter did not only rewrite: $_"
    Invoke-TestEnter $state.Line $state
    Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 1) "Second Enter did not accept the rewrite: $_"
}

@(
    'cd /d',
    'cd /d -LiteralPath',
    'cd /d $path',
    'cd /d (Get-Location)',
    'cd /d x; Get-Location',
    'cd /x x',
    'dir /b /s .',
    'dir /b $path',
    'dir /s sub/*.txt',
    'dir /a /b',
    'dir /o:x',
    'dir /o:-d *.txt',
    'rd /s',
    'rd /s /q',
    'rd /s /q x -Force',
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
    'del /s',
    'del /s *.txt -Force',
    'del /s sub/*.txt',
    'del /s $pattern',
    'del /s (Get-ChildItem)',
    'del /s *.txt; Get-Location',
    'where git /r',
    "where git '/r'",
    'where /r . git | Out-Null',
    'where git; Get-Location',
    'where ''$PATH:git''',
    'where ''git" /r''',
    'sort file.txt /r',
    'sort file.txt -Descending',
    'copy /y source.txt',
    'copy /y source.txt target.txt extra.txt',
    'copy /y $source target.txt',
    'move /y source.txt target.txt -Force',
    'rd /s ""'
) | ForEach-Object { Assert-Rejected $_ }

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("PSforMuscleMemory-" + [guid]::NewGuid())
$nested = Join-Path $fixture 'nested'
$matchingDirectory = Join-Path $fixture 'fake.txt'
$file = Join-Path $nested 'keep.txt'
$hiddenFile = Join-Path $fixture 'hidden.dat'
$sourceFile = Join-Path $fixture 'source.dat'
$targetFile = Join-Path $fixture 'target.dat'
New-Item -ItemType Directory -Path $nested | Out-Null
Set-Content -LiteralPath $file -Value @('zeta', 'alpha')
Set-Content -LiteralPath $hiddenFile -Value 'hidden'
[System.IO.File]::SetAttributes($hiddenFile, [System.IO.File]::GetAttributes($hiddenFile) -bor [System.IO.FileAttributes]::Hidden)
Set-Content -LiteralPath $sourceFile -Value 'source'
Set-Content -LiteralPath $targetFile -Value 'target'
$escaped = $fixture.Replace("'", "''")
$originalLocation = Get-Location
try {
    Set-Location -LiteralPath $fixture
    $recursiveResults = @(& ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'dir /s *.txt'))))
    Assert-True ($recursiveResults.Count -eq 1 -and $recursiveResults[0].FullName -eq $file) 'dir /s *.txt must match nested filenames recursively.'
    $bareNames = @(& ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'dir /b'))))
    Assert-True ($bareNames -contains 'nested') 'dir /b must output bare child names.'
    $allNames = @(& ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'dir /a'))))
    Assert-True ($allNames.FullName -contains $hiddenFile) 'dir /a must include hidden entries.'
    $nameOrder = @(& ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'dir /o:n'))))
    Assert-True (($nameOrder.Name -join '|') -ceq (($nameOrder | Sort-Object Name).Name -join '|')) 'dir /o:n must sort by name.'
    $dateOrder = @(& ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'dir /o:-d'))))
    Assert-True (($dateOrder.LastWriteTime -join '|') -ceq (($dateOrder | Sort-Object LastWriteTime -Descending).LastWriteTime -join '|')) 'dir /o:-d must sort newest first.'
    $sortedLines = @(& ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'sort nested/keep.txt'))))
    Assert-True (($sortedLines -join '|') -ceq 'alpha|zeta') 'sort must sort file lines.'
    if ($IsWindows) {
        $nativeWhere = Join-Path ([Environment]::SystemDirectory) 'where.exe'
        $pathDir = Join-Path $fixture 'path-bin'
        $secondDir = Join-Path $fixture 'other-bin'
        New-Item -ItemType Directory -Path $pathDir, $secondDir | Out-Null
        $pathOnly = Join-Path $pathDir "native tool's.cmd"
        $firstMatch = Join-Path $pathDir 'native-multi.cmd'
        $secondMatch = Join-Path $secondDir 'native-multi.cmd'
        $localMatch = Join-Path $fixture 'native-local.cmd'
        foreach ($candidate in $pathOnly, $firstMatch, $secondMatch, $localMatch) {
            Set-Content -LiteralPath $candidate -Value '@echo off'
        }
        $savedPath = $env:PATH
        try {
            $env:PATH = "$pathDir;$secondDir"
            $PSNativeCommandUseErrorActionPreference = $false
            foreach ($case in @(
                @{ Pattern = "native tool's.cmd"; Matches = @($pathOnly); ExitCode = 0 }
                @{ Pattern = 'native-multi.cmd'; Matches = @($firstMatch, $secondMatch); ExitCode = 0 }
                @{ Pattern = 'native-loc?l.*'; Matches = @($localMatch); ExitCode = 0 }
                @{ Pattern = 'native-absent.cmd'; Matches = @(); ExitCode = 1 }
            )) {
                $expected = @(& $nativeWhere $case.Pattern 2>&1)
                $nativeExitCode = $LASTEXITCODE
                $quotedPattern = $case.Pattern.Replace("'", "''")
                $rewrite = [scriptblock]::Create((ConvertFrom-MuscleMemoryCommand "where '$quotedPattern'"))
                $actual = @(& $rewrite 2>&1)
                Assert-Equal $LASTEXITCODE $case.ExitCode
                Assert-Equal $LASTEXITCODE $nativeExitCode
                Assert-Equal ($actual -join "`n") ($expected -join "`n")
                if ($case.ExitCode -eq 0) {
                    Assert-Equal $actual.Count $case.Matches.Count
                    foreach ($match in $case.Matches) {
                        Assert-True ($actual -contains $match) "where did not find $match."
                    }
                }
            }
        } finally {
            $env:PATH = $savedPath
        }
    } else {
        Assert-Rejected 'where git'
    }

    New-Item -ItemType Directory -Path $matchingDirectory | Out-Null
    $delTranslation = ConvertFrom-MuscleMemoryCommand 'del /s *.txt'
    Assert-True ($delTranslation.Contains(' -WhatIf')) 'del /s translation must include explicit WhatIf.'
    $WhatIfPreference = $false
    $PSDefaultParameterValues['*:WhatIf'] = $false
    & ([scriptblock]::Create($delTranslation))
    Assert-True (Test-Path -LiteralPath $file -PathType Leaf) 'del /s preview removed a matching file.'
    Assert-True (Test-Path -LiteralPath $nested -PathType Container) 'del /s must not remove matching directories.'
    Assert-True (Test-Path -LiteralPath $matchingDirectory -PathType Container) 'del /s must not remove directories matching a file pattern.'
    & ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'copy /y source.dat target.dat')))
    Assert-True ([System.IO.File]::ReadAllText($targetFile).Trim() -eq 'target') 'copy /y preview overwrote the destination.'
    Assert-True (Test-Path -LiteralPath $sourceFile -PathType Leaf) 'copy /y preview changed the source.'
    & ([scriptblock]::Create((ConvertFrom-MuscleMemoryCommand 'move /y source.dat target.dat')))
    Assert-True ([System.IO.File]::ReadAllText($targetFile).Trim() -eq 'target') 'move /y preview overwrote the destination.'
    Assert-True (Test-Path -LiteralPath $sourceFile -PathType Leaf) 'move /y preview moved the source.'

    Set-Location -LiteralPath $nested
    $cdTranslation = ConvertFrom-MuscleMemoryCommand "cd /d '$escaped'"
    & ([scriptblock]::Create($cdTranslation))
    Assert-True ((Get-Location).Path -eq $fixture) 'cd /d must change the current location.'
} finally {
    Set-Location -LiteralPath $originalLocation.Path
}

$translated = ConvertFrom-MuscleMemoryCommand "rd /s /q '$escaped'"
Assert-True ($translated.EndsWith(' -Recurse -WhatIf')) 'Translation must include explicit WhatIf.'

$state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
Invoke-TestEnter "rd /s '$escaped'" $state
Assert-Equal $state.Line $translated
Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 0) 'First Enter must only rewrite.'
Assert-True (Test-Path -LiteralPath $file -PathType Leaf) 'First Enter changed the fixture.'
Invoke-TestEnter $state.Line $state
Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 1) 'Second Enter must accept the rewrite.'

$state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
Invoke-TestEnter "rd /s '$escaped'" $state
Invoke-TestEnter ($state.Line + ' -Verbose') $state
Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 1) 'An edited PowerShell rewrite must be treated as fresh input.'

$state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
Invoke-TestEnter 'dir /s .' $state
Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 0) 'First dir Enter must only rewrite.'
Invoke-TestEnter $state.Line $state
Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 1) 'Second dir Enter must accept the rewrite.'
$state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
Invoke-TestEnter 'dir /s .' $state
Invoke-TestEnter 'dir /s another' $state
Assert-Equal $state.Line "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath 'another' -Recurse"
Assert-True ($state.Rewrites -eq 2 -and $state.Accepts -eq 0) 'Edited shorthand must be rewritten again.'
Invoke-TestEnter 'Get-Location' $state
Assert-True ($state.Accepts -eq 1) 'An edited ordinary command must be accepted immediately.'
$state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
Invoke-TestEnter 'Get-Location' $state
Assert-True ($state.Rewrites -eq 0 -and $state.Accepts -eq 1) 'Unrelated commands must be accepted immediately.'
$state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
$rejected = $false
try { Invoke-TestEnter 'rd /s x -WhatIf:$false' $state } catch { $rejected = $true }
Assert-True ($rejected -and $state.Rewrites -eq 0 -and $state.Accepts -eq 0) 'Unsupported removal must not be rewritten or accepted.'

$WhatIfPreference = $false
$PSDefaultParameterValues['*:WhatIf'] = $false
& ([scriptblock]::Create($translated))
$PSDefaultParameterValues.Remove('*:WhatIf')
Assert-True (Test-Path -LiteralPath $fixture -PathType Container) 'Preview removed the fixture.'
Assert-True (Test-Path -LiteralPath $file -PathType Leaf) 'Preview removed the nested file.'

if (-not (Get-Module PSReadLine)) { Import-Module PSReadLine -MinimumVersion 2.2 }
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

    Set-PSReadLineKeyHandler -Chord Enter -Function AcceptLine
    Set-PSReadLineOption -CommandValidationHandler { param($commandAst) }
    $hook = (Get-PSReadLineOption).CommandValidationHandler
    Enable-PSforMuscleMemory
    Assert-True ([object]::ReferenceEquals($hook, (Get-PSReadLineOption).CommandValidationHandler)) 'Enable replaced the existing validation handler.'
    $state = [pscustomobject]@{ Line = ''; Rewrites = 0; Accepts = 0 }
    Invoke-TestEnter "rd /s '$escaped'" $state
    Assert-Equal $state.Line $translated
    Invoke-TestEnter $state.Line $state
    Assert-True ($state.Rewrites -eq 1 -and $state.Accepts -eq 1) 'Existing validation handler disrupted the two-Enter flow.'
    Disable-PSforMuscleMemory
    Assert-True ([object]::ReferenceEquals($hook, (Get-PSReadLineOption).CommandValidationHandler)) 'Disable replaced the existing validation handler.'
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function 'AcceptLine'

    Set-PSReadLineKeyHandler -Chord Enter -Function ValidateAndAcceptLine
    $rejected = $false
    try { Enable-PSforMuscleMemory } catch { $rejected = $true }
    Assert-True $rejected 'ValidateAndAcceptLine with a validation handler must be rejected.'
    Assert-True ([object]::ReferenceEquals($hook, (Get-PSReadLineOption).CommandValidationHandler)) 'Existing validation handler was lost.'
    Assert-Equal (Get-PSReadLineKeyHandler -Chord Enter).Function 'ValidateAndAcceptLine'
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
