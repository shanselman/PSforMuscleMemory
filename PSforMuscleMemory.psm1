using namespace System.Management.Automation.Language

$script:enabled = $false
$script:originalEnter = $null
$script:originalEditMode = $null
$script:bindingName = 'PSforMuscleMemory-ValidateEnter'
$script:bindingDescription = 'Translate supported cmd.exe muscle-memory commands'

function ConvertTo-MuscleMemoryLiteral {
    param([string] $Value, [string] $Usage)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.StartsWith('/') -or $Value.StartsWith('-') -or
        $Value.IndexOfAny([char[]]@("`0", "`r", "`n")) -ge 0) {
        throw $Usage
    }
    return "'" + ($Value -replace "['\u2018\u2019\u201A\u201B]", '$&$&') + "'"
}

function ConvertFrom-MuscleMemoryCd {
    param([string[]] $Arguments, [string] $Usage)

    if ($Arguments.Count -ne 2 -or $Arguments[0] -ine '/d') { throw $Usage }
    $literal = ConvertTo-MuscleMemoryLiteral $Arguments[1] $Usage
    return "Microsoft.PowerShell.Management\Set-Location -LiteralPath $literal"
}

function ConvertFrom-MuscleMemoryDir {
    param([string[]] $Arguments, [string] $Usage)

    $modes = @('/s', '/b', '/a', '/o:n', '/o:-d')
    $switches = @($Arguments | Where-Object { $_ -in $modes })
    $paths = @($Arguments | Where-Object { $_ -notin $modes })
    if ($switches.Count -ne 1 -or $paths.Count -gt 1) { throw $Usage }
    $path = if ($paths.Count -eq 0) { '.' } else { $paths[0] }
    $literal = ConvertTo-MuscleMemoryLiteral $path $Usage

    switch -CaseSensitive ($switches[0].ToLowerInvariant()) {
        '/b' {
            if ($path.IndexOfAny([char[]]@('*', '?')) -ge 0) { throw $Usage }
            return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $literal -Name"
        }
        '/a' {
            if ($path.IndexOfAny([char[]]@('*', '?')) -ge 0) { throw $Usage }
            return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $literal -Force"
        }
        '/o:n' {
            if ($path.IndexOfAny([char[]]@('*', '?')) -ge 0) { throw $Usage }
            return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $literal | Microsoft.PowerShell.Utility\Sort-Object -Property Name"
        }
        '/o:-d' {
            if ($path.IndexOfAny([char[]]@('*', '?')) -ge 0) { throw $Usage }
            return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $literal | Microsoft.PowerShell.Utility\Sort-Object -Property LastWriteTime -Descending"
        }
        '/s' {
            if ($path.IndexOfAny([char[]]@('*', '?')) -ge 0) {
                if ($path.IndexOfAny([char[]]@('\', '/', '[', ']')) -ge 0) { throw $Usage }
                return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter $literal -Recurse"
            }
            return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $literal -Recurse"
        }
    }
    throw $Usage
}

function ConvertFrom-MuscleMemoryRd {
    param([string[]] $Arguments, [string] $Usage)

    $recursive = @($Arguments | Where-Object { $_ -ieq '/s' })
    $quiet = @($Arguments | Where-Object { $_ -ieq '/q' })
    $paths = @($Arguments | Where-Object { $_ -ine '/s' -and $_ -ine '/q' })
    if ($recursive.Count -ne 1 -or $quiet.Count -gt 1 -or $paths.Count -ne 1) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryLiteral $paths[0] $Usage
    return "Microsoft.PowerShell.Management\Remove-Item -LiteralPath $literal -Recurse -WhatIf"
}

function ConvertFrom-MuscleMemoryDel {
    param([string[]] $Arguments, [string] $Usage)

    $recursive = @($Arguments | Where-Object { $_ -ieq '/s' })
    $patterns = @($Arguments | Where-Object { $_ -ine '/s' })
    if ($recursive.Count -ne 1 -or $patterns.Count -ne 1) { throw $Usage }
    $pattern = $patterns[0]
    if ($pattern.IndexOfAny([char[]]@('\', '/', '[', ']')) -ge 0) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryLiteral $pattern $Usage
    return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter $literal -Recurse -File | Microsoft.PowerShell.Management\Remove-Item -WhatIf"
}

function ConvertFrom-MuscleMemoryWhere {
    param([string[]] $Arguments, [string] $Usage)

    if ($Arguments.Count -ne 1 -or $Arguments[0].IndexOfAny([char[]]'\/:[]"<>|') -ge 0) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryLiteral $Arguments[0] $Usage
    if (-not $IsWindows) { throw 'The DOS-style where command requires Windows where.exe.' }
    $application = "$([Environment]::SystemDirectory)\where.exe"
    $quotedApplication = ConvertTo-MuscleMemoryLiteral $application $Usage
    return "& $quotedApplication $literal"
}

function ConvertFrom-MuscleMemorySort {
    param([string[]] $Arguments, [string] $Usage)

    if ($Arguments.Count -ne 1) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryLiteral $Arguments[0] $Usage
    return "Microsoft.PowerShell.Management\Get-Content -LiteralPath $literal | Microsoft.PowerShell.Utility\Sort-Object"
}

function ConvertFrom-MuscleMemoryCopy {
    param([string[]] $Arguments, [string] $Usage)

    $overwrite = @($Arguments | Where-Object { $_ -ieq '/y' })
    $paths = @($Arguments | Where-Object { $_ -ine '/y' })
    if ($overwrite.Count -ne 1 -or $paths.Count -ne 2) { throw $Usage }
    $source = ConvertTo-MuscleMemoryLiteral $paths[0] $Usage
    $destination = ConvertTo-MuscleMemoryLiteral $paths[1] $Usage
    return "Microsoft.PowerShell.Management\Copy-Item -LiteralPath $source -Destination $destination -WhatIf"
}

function ConvertFrom-MuscleMemoryMove {
    param([string[]] $Arguments, [string] $Usage)

    $overwrite = @($Arguments | Where-Object { $_ -ieq '/y' })
    $paths = @($Arguments | Where-Object { $_ -ine '/y' })
    if ($overwrite.Count -ne 1 -or $paths.Count -ne 2) { throw $Usage }
    $source = ConvertTo-MuscleMemoryLiteral $paths[0] $Usage
    $destination = ConvertTo-MuscleMemoryLiteral $paths[1] $Usage
    return "Microsoft.PowerShell.Management\Move-Item -LiteralPath $source -Destination $destination -WhatIf"
}

function ConvertFrom-MuscleMemoryCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Line)

    $tokens = $null
    $parseErrors = $null
    $ast = [Parser]::ParseInput($Line, [ref] $tokens, [ref] $parseErrors)
    $commands = @($ast.FindAll({ param($node) $node -is [CommandAst] }, $true))
    $attempts = @($commands | Where-Object {
        $name = $_.GetCommandName()
        if ($name -notin @('cd', 'dir', 'rd', 'del', 'where', 'sort', 'copy', 'move')) { return $false }
        $elements = @($_.CommandElements | Select-Object -Skip 1)
        $isSingleCommandPipeline = $_.Parent -is [PipelineAst] -and $_.Parent.PipelineElements.Count -eq 1
        if ($name -ieq 'where') {
            # Where-Object filters can contain slash-prefixed values or script blocks.
            if ($isSingleCommandPipeline -and $elements.Count -eq 1 -and
                ($elements[0] -is [StringConstantExpressionAst] -or $elements[0] -is [ExpandableStringExpressionAst])) {
                return $true
            }
            foreach ($element in $elements) {
                if ($element -is [CommandParameterAst]) { break }
                if ($element -is [StringConstantExpressionAst] -and
                    $element.Value -match '^/(?:[a-z][a-z0-9]*|\?)(?::.*)?$') {
                    return $true
                }
            }
            return $false
        }
        $hasDosSwitch = @($_.FindAll({
            param($node)
            ($node -is [StringConstantExpressionAst] -or $node -is [ExpandableStringExpressionAst]) -and
            $node.Value.StartsWith('/')
        }, $true)).Count -gt 0
        $isSortPath = $isSingleCommandPipeline -and $name -ieq 'sort' -and $elements.Count -gt 0 -and
            $elements[0].Extent.Text -match '([\\/]|[.][^\\/]+)$'
        $hasDosSwitch -or $isSortPath
    })

    if ($attempts.Count -eq 0) { return $Line }

    $usage = 'Unsupported DOS-style command. Use cd /d path, dir /b [path], dir /s [path-or-filename-pattern], dir /a [path], dir /o:n [path], dir /o:-d [path], rd /s [/q] path, del /s filename-pattern, where filename-pattern, sort filename, copy /y source destination, or move /y source destination.'
    $command = $attempts[0]
    if ($parseErrors.Count -ne 0 -or $attempts.Count -ne 1 -or $commands.Count -ne 1 -or
        $command.InvocationOperator -ne [TokenKind]::Unknown -or
        $Line.Trim() -cne $command.Extent.Text -or $command.Redirections.Count -ne 0) {
        throw $usage
    }

    $elements = @($command.CommandElements | Select-Object -Skip 1)
    if (@($elements | Where-Object { $_ -isnot [StringConstantExpressionAst] }).Count -ne 0) {
        throw $usage
    }
    $arguments = @($elements | ForEach-Object { $_.Value })

    switch ($command.GetCommandName().ToLowerInvariant()) {
        'cd' { return ConvertFrom-MuscleMemoryCd $arguments $usage }
        'dir' { return ConvertFrom-MuscleMemoryDir $arguments $usage }
        'rd' { return ConvertFrom-MuscleMemoryRd $arguments $usage }
        'del' { return ConvertFrom-MuscleMemoryDel $arguments $usage }
        'where' { return ConvertFrom-MuscleMemoryWhere $arguments $usage }
        'sort' { return ConvertFrom-MuscleMemorySort $arguments $usage }
        'copy' { return ConvertFrom-MuscleMemoryCopy $arguments $usage }
        'move' { return ConvertFrom-MuscleMemoryMove $arguments $usage }
    }
}

$script:translator = ${function:ConvertFrom-MuscleMemoryCommand}

function Invoke-MuscleMemoryLine {
    param([string] $Line, [scriptblock] $Replace, [scriptblock] $Accept)

    $translated = & $script:translator $Line
    if ($translated -cne $Line) {
        & $Replace $translated
        return
    }
    & $Accept
}

function Enable-PSforMuscleMemory {
    [CmdletBinding()]
    param()

    if ($script:enabled) { return }
    $readLine = @(Get-Module PSReadLine)
    if ($readLine.Count -eq 0) {
        Import-Module PSReadLine -MinimumVersion 2.2 -ErrorAction Stop
    } elseif (@($readLine | Where-Object { $_.Version -lt [version]'2.2' }).Count -gt 0) {
        throw 'PSforMuscleMemory requires PSReadLine 2.2 or newer.'
    }
    $options = Get-PSReadLineOption
    $binding = Get-PSReadLineKeyHandler -Chord Enter
    if ($options.EditMode -eq 'Vi') {
        throw 'PSforMuscleMemory does not support PSReadLine Vi mode.'
    }
    if ($null -eq $binding -or $binding.Group -eq 'Custom' -or
        $binding.Function -notin @('AcceptLine', 'ValidateAndAcceptLine')) {
        throw 'PSforMuscleMemory cannot replace the existing Enter binding.'
    }
    if ($binding.Function -eq 'ValidateAndAcceptLine' -and $null -ne $options.CommandValidationHandler) {
        throw 'PSforMuscleMemory cannot safely use ValidateAndAcceptLine with an existing command-validation handler.'
    }
    $script:originalEnter = $binding.Function
    $script:originalEditMode = $options.EditMode

    Set-PSReadLineKeyHandler -Chord Enter -BriefDescription $script:bindingName -Description $script:bindingDescription -ScriptBlock {
        param($key, $arg)
        if ($script:originalEnter -eq 'ValidateAndAcceptLine' -and
            $null -ne (Get-PSReadLineOption).CommandValidationHandler) {
            [Console]::Error.WriteLine('PSforMuscleMemory: ValidateAndAcceptLine cannot safely run with a command-validation handler; remove it or disable PSforMuscleMemory before accepting input.')
            return
        }
        $line = $null
        $cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref] $line, [ref] $cursor)
        try {
            Invoke-MuscleMemoryLine $line {
                param($translated)
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $translated)
            } {
                if ($script:originalEnter -eq 'ValidateAndAcceptLine') {
                    [Microsoft.PowerShell.PSConsoleReadLine]::ValidateAndAcceptLine($key, $arg)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine($key, $arg)
                }
            }
        } catch {
            [Console]::Error.WriteLine("PSforMuscleMemory: $($_.Exception.Message)")
        }
    }
    $script:enabled = $true
}

function Disable-PSforMuscleMemory {
    [CmdletBinding()]
    param()

    if (-not $script:enabled) { return }
    $binding = Get-PSReadLineKeyHandler -Chord Enter
    if ((Get-PSReadLineOption).EditMode -eq $script:originalEditMode -and
        $null -ne $binding -and $binding.Group -eq 'Custom' -and
        $binding.Function -ceq $script:bindingName -and $binding.Description -ceq $script:bindingDescription) {
        Set-PSReadLineKeyHandler -Chord Enter -Function $script:originalEnter
    }
    $script:enabled = $false
}

$ExecutionContext.SessionState.Module.OnRemove = { Disable-PSforMuscleMemory }
Export-ModuleMember -Function ConvertFrom-MuscleMemoryCommand, Enable-PSforMuscleMemory, Disable-PSforMuscleMemory
