using namespace System.Management.Automation.Language

$script:enabled = $false
$script:originalEnter = $null
$script:originalEditMode = $null
$script:bindingName = 'PSforMuscleMemory-ValidateEnter'
$script:bindingDescription = 'Translate supported cmd.exe muscle-memory commands'

function ConvertFrom-MuscleMemoryCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Line)

    $tokens = $null
    $parseErrors = $null
    $ast = [Parser]::ParseInput($Line, [ref] $tokens, [ref] $parseErrors)
    $commands = @($ast.FindAll({ param($node) $node -is [CommandAst] }, $true))
    $attempts = @($commands | Where-Object {
        $_.GetCommandName() -in @('dir', 'rd') -and
        @($_.FindAll({
            param($node)
            ($node -is [StringConstantExpressionAst] -or $node -is [ExpandableStringExpressionAst]) -and
            $node.Value.StartsWith('/s', [StringComparison]::OrdinalIgnoreCase)
        }, $true)).Count -gt 0
    })

    if ($attempts.Count -eq 0) { return $Line }

    $usage = 'Unsupported dir /s or rd /s input. Use only dir /s [literal-path] or rd /s literal-path, without other commands or switches.'
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
    $switches = @($elements | Where-Object { $_.Value -ieq '/s' })
    $paths = @($elements | Where-Object { $_.Value -ine '/s' })
    $isRemoval = $command.GetCommandName() -ieq 'rd'
    if ($switches.Count -ne 1 -or $paths.Count -gt 1 -or ($isRemoval -and $paths.Count -ne 1)) {
        throw $usage
    }

    $path = if ($paths.Count -eq 0) { '.' } else { $paths[0].Value }
    if ([string]::IsNullOrWhiteSpace($path) -or $path.StartsWith('/') -or $path.StartsWith('-') -or
        $path.IndexOfAny([char[]]@("`0", "`r", "`n")) -ge 0) {
        throw $usage
    }
    $literal = "'" + $path.Replace("'", "''") + "'"
    if ($isRemoval) {
        return "Microsoft.PowerShell.Management\Remove-Item -LiteralPath $literal -Recurse -WhatIf"
    }
    return "Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $literal -Recurse"
}

$script:translator = ${function:ConvertFrom-MuscleMemoryCommand}

function Enable-PSforMuscleMemory {
    [CmdletBinding()]
    param()

    if ($script:enabled) { return }
    Import-Module PSReadLine -MinimumVersion 2.2 -ErrorAction Stop
    $options = Get-PSReadLineOption
    $binding = Get-PSReadLineKeyHandler -Chord Enter
    if ($options.EditMode -eq 'Vi') {
        throw 'PSforMuscleMemory does not support PSReadLine Vi mode.'
    }
    if ($null -ne $options.CommandValidationHandler) {
        throw 'PSforMuscleMemory cannot enable while a PSReadLine command-validation handler is installed.'
    }
    if ($null -eq $binding -or $binding.Group -eq 'Custom' -or
        $binding.Function -notin @('AcceptLine', 'ValidateAndAcceptLine')) {
        throw 'PSforMuscleMemory cannot replace the existing Enter binding.'
    }
    $script:originalEnter = $binding.Function
    $script:originalEditMode = $options.EditMode

    Set-PSReadLineKeyHandler -Chord Enter -BriefDescription $script:bindingName -Description $script:bindingDescription -ScriptBlock {
        param($key, $arg)
        if ($null -ne (Get-PSReadLineOption).CommandValidationHandler) {
            [Console]::Error.WriteLine('PSforMuscleMemory: a command-validation handler was installed; remove it or disable PSforMuscleMemory before accepting input.')
            return
        }
        $line = $null
        $cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref] $line, [ref] $cursor)
        try {
            $translated = & $script:translator $line
        } catch {
            [Console]::Error.WriteLine("PSforMuscleMemory: $($_.Exception.Message)")
            return
        }
        if ($translated -cne $line) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $translated)
        }
        if ($script:originalEnter -eq 'ValidateAndAcceptLine') {
            [Microsoft.PowerShell.PSConsoleReadLine]::ValidateAndAcceptLine($key, $arg)
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine($key, $arg)
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
