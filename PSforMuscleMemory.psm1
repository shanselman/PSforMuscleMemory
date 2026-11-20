using namespace System.Management.Automation.Language

$script:enabled = $false
$script:originalEnter = $null
$script:originalEditMode = $null
$script:bindingName = 'PSforMuscleMemory-ValidateEnter'
$script:bindingDescription = 'Translate supported cmd.exe muscle-memory commands'
$script:whereInvalidPattern = '^[/-]|[\\/:\[\]"<>|\x00\r\n]'

function ConvertTo-MuscleMemoryLiteral {
    param([string] $Value, [string] $Usage)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.StartsWith('/') -or $Value.StartsWith('-') -or
        $Value.IndexOfAny([char[]]@("`0", "`r", "`n")) -ge 0) {
        throw $Usage
    }
    return "'" + ($Value -replace "['\u2018\u2019\u201A\u201B]", '$&$&') + "'"
}

function ConvertTo-MuscleMemoryOperand {
    param($Argument, [string] $Usage)

    $literal = ConvertTo-MuscleMemoryLiteral $Argument.Value $Usage
    if ($Argument.Expression) { return $Argument.Expression }
    return $literal
}

function ConvertFrom-MuscleMemoryCd {
    param([object[]] $Arguments, [string] $Usage)

    if ($Arguments.Count -ne 2 -or $Arguments[0].Value -ine '/d') { throw $Usage }
    $literal = ConvertTo-MuscleMemoryOperand $Arguments[1] $Usage
    return "Microsoft.PowerShell.Management\Set-Location -LiteralPath $literal"
}

function ConvertFrom-MuscleMemoryDir {
    param([object[]] $Arguments, [string] $Usage)

    $modes = @('/s', '/b', '/a', '/o:n', '/o:-d')
    $switches = @($Arguments | Where-Object { $_.Value -in $modes })
    $paths = @($Arguments | Where-Object { $_.Value -notin $modes })
    if ($switches.Count -ne 1 -or $paths.Count -gt 1) { throw $Usage }
    $path = if ($paths.Count -eq 0) { '.' } else { $paths[0].Value }
    $literal = if ($paths.Count -eq 0) { "'.'" } else { ConvertTo-MuscleMemoryOperand $paths[0] $Usage }

    switch -CaseSensitive ($switches[0].Value.ToLowerInvariant()) {
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
    param([object[]] $Arguments, [string] $Usage)

    $recursive = @($Arguments | Where-Object { $_.Value -ieq '/s' })
    $quiet = @($Arguments | Where-Object { $_.Value -ieq '/q' })
    $paths = @($Arguments | Where-Object { $_.Value -ine '/s' -and $_.Value -ine '/q' })
    if ($recursive.Count -ne 1 -or $quiet.Count -gt 1 -or $paths.Count -ne 1) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryOperand $paths[0] $Usage
    return "Microsoft.PowerShell.Management\Remove-Item -LiteralPath $literal -Recurse -WhatIf"
}

function ConvertFrom-MuscleMemoryDel {
    param([object[]] $Arguments, [string] $Usage)

    $recursive = @($Arguments | Where-Object { $_.Value -ieq '/s' })
    $patterns = @($Arguments | Where-Object { $_.Value -ine '/s' })
    if ($recursive.Count -ne 1 -or $patterns.Count -ne 1) { throw $Usage }
    $pattern = $patterns[0].Value
    if ($pattern.IndexOfAny([char[]]@('\', '/', '[', ']')) -ge 0) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryOperand $patterns[0] $Usage
    return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath '.' -Filter $literal -Recurse -File | Microsoft.PowerShell.Management\Remove-Item -WhatIf"
}

function ConvertFrom-MuscleMemoryWhere {
    param([object[]] $Arguments, [string] $Usage)

    if ($Arguments.Count -ne 1 -or $Arguments[0].Value -match $script:whereInvalidPattern) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryOperand $Arguments[0] $Usage
    if (-not $IsWindows) { throw 'The DOS-style where command requires Windows where.exe.' }
    $application = "$([Environment]::SystemDirectory)\where.exe"
    $quotedApplication = ConvertTo-MuscleMemoryLiteral $application $Usage
    if ($Arguments[0].Expression) {
        # Native where.exe could interpret a changed value as a switch or search location.
        return ('& {{ param([string] $pattern) if ([string]::IsNullOrWhiteSpace($pattern) -or $pattern -match ''{0}'') {{ throw ''Expected a where.exe filename pattern.'' }}; & {1} $pattern }} {2}' -f $script:whereInvalidPattern, $quotedApplication, $literal)
    }
    return "& $quotedApplication $literal"
}

function ConvertFrom-MuscleMemorySort {
    param([object[]] $Arguments, [string] $Usage)

    if ($Arguments.Count -ne 1) { throw $Usage }
    $literal = ConvertTo-MuscleMemoryOperand $Arguments[0] $Usage
    return "Microsoft.PowerShell.Management\Get-Content -LiteralPath $literal | Microsoft.PowerShell.Utility\Sort-Object"
}

function ConvertFrom-MuscleMemoryCopy {
    param([object[]] $Arguments, [string] $Usage)

    $overwrite = @($Arguments | Where-Object { $_.Value -ieq '/y' })
    $paths = @($Arguments | Where-Object { $_.Value -ine '/y' })
    if ($overwrite.Count -ne 1 -or $paths.Count -ne 2) { throw $Usage }
    $source = ConvertTo-MuscleMemoryOperand $paths[0] $Usage
    $destination = ConvertTo-MuscleMemoryOperand $paths[1] $Usage
    return "Microsoft.PowerShell.Management\Copy-Item -LiteralPath $source -Destination $destination -WhatIf"
}

function ConvertFrom-MuscleMemoryMove {
    param([object[]] $Arguments, [string] $Usage)

    $overwrite = @($Arguments | Where-Object { $_.Value -ieq '/y' })
    $paths = @($Arguments | Where-Object { $_.Value -ine '/y' })
    if ($overwrite.Count -ne 1 -or $paths.Count -ne 2) { throw $Usage }
    $source = ConvertTo-MuscleMemoryOperand $paths[0] $Usage
    $destination = ConvertTo-MuscleMemoryOperand $paths[1] $Usage
    return "Microsoft.PowerShell.Management\Move-Item -LiteralPath $source -Destination $destination -WhatIf"
}

function Convert-MuscleMemoryEnvironmentArgument {
    param([StringConstantExpressionAst] $Element, [switch] $AllowUnquoted)

    $text = $Element.Extent.Text
    $argument = [pscustomobject]@{ Value = $Element.Value; Expression = $null }
    if (-not $text.Contains('%') -or $Element.StringConstantType -ne [StringConstantType]::BareWord -or
        $text -match '[''"`\u2018-\u201f]' -or $text -cne $Element.Value) {
        return $argument
    }

    $resolved = $expression = ''
    $offset = 0
    foreach ($match in [regex]::Matches($text, '%([A-Za-z0-9_]+)%')) {
        $name = $match.Groups[1].Value
        if ($IsWindows) { $name = $name.ToUpperInvariant() }
        $value = [Environment]::GetEnvironmentVariable($name)
        if ($null -eq $value -and -not $IsWindows) {
            # Use the actual spelling for PowerShell's case-sensitive Env: drive.
            $name = [Environment]::GetEnvironmentVariables().Keys | Where-Object { $_ -ieq $name } | Select-Object -First 1
            if ($null -ne $name) { $value = [Environment]::GetEnvironmentVariable($name) }
        }
        if ($null -eq $value) { continue }

        $prefix = $text.Substring($offset, $match.Index - $offset)
        $resolved += $prefix + $value
        $expression += $prefix.Replace('$', '`$') + '${env:' + $name + '}'
        if ($AllowUnquoted -and $match.Length -eq $text.Length) {
            $argument.Value = $value
            $argument.Expression = '$env:' + $name
            return $argument
        }
        $offset = $match.Index + $match.Length
    }
    if ($offset -gt 0) {
        $suffix = $text.Substring($offset)
        $argument.Value = $resolved + $suffix
        $argument.Expression = '"' + $expression + $suffix.Replace('$', '`$') + '"'
    }
    return $argument
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
        if ($name -in @('where', 'sort')) {
            # Filters and sort properties can contain slash text that is not a switch.
            if ($isSingleCommandPipeline -and $elements.Count -gt 0 -and
                ($elements[0] -is [StringConstantExpressionAst] -or $elements[0] -is [ExpandableStringExpressionAst])) {
                if ($name -ieq 'where' -and $elements.Count -eq 1) { return $true }
                if ($name -ieq 'sort' -and $elements[0].Extent.Text -match '([\\/]|[.][^\\/]+)$') { return $true }
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
        return @($_.FindAll({
            param($node)
            ($node -is [StringConstantExpressionAst] -or $node -is [ExpandableStringExpressionAst]) -and
            $node.Value.StartsWith('/')
        }, $true)).Count -gt 0
    })

    if ($commands.Count -eq 0) { return $Line }
    $usage = 'Unsupported DOS-style command. Use cd /d path, dir /b [path], dir /s [path-or-filename-pattern], dir /a [path], dir /o:n [path], dir /o:-d [path], rd /s [/q] path, del /s filename-pattern, where filename-pattern, sort filename, copy /y source destination, or move /y source destination.'
    $command = $commands[0]
    if ($parseErrors.Count -ne 0 -or $commands.Count -ne 1 -or
        $command.InvocationOperator -ne [TokenKind]::Unknown -or
        $Line.Trim() -cne $command.Extent.Text -or $command.Redirections.Count -ne 0) {
        if ($attempts.Count -gt 0) { throw $usage }
        return $Line
    }

    $elements = @($command.CommandElements | Select-Object -Skip 1)
    if ($attempts.Count -eq 0) {
        # Do not silently retarget ordinary PowerShell operations such as rd or copy.
        if ($command.GetCommandName() -ine 'cd' -or $elements.Count -ne 1 -or
            $elements[0] -isnot [StringConstantExpressionAst]) { return $Line }
        $argument = Convert-MuscleMemoryEnvironmentArgument $elements[0] -AllowUnquoted
        if (-not $argument.Expression) { return $Line }
        $extent = $elements[0].Extent
        return $Line.Remove($extent.StartOffset, $extent.EndOffset - $extent.StartOffset).Insert($extent.StartOffset, $argument.Expression)
    }

    if (@($elements | Where-Object { $_ -isnot [StringConstantExpressionAst] }).Count -ne 0) {
        throw $usage
    }
    $arguments = @(foreach ($element in $elements) {
        $argument = Convert-MuscleMemoryEnvironmentArgument $element
        # A value substituted into a path must not be reinterpreted as a DOS switch.
        if ($argument.Expression -and $argument.Value -match '^[/\-]') { throw $usage }
        $argument
    })

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
