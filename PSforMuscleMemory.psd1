@{
    RootModule = 'PSforMuscleMemory.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'e8098a42-ef0e-40be-b470-81822ad51c87'
    Author = 'Scott Hanselman and PSforMuscleMemory contributors'
    Description = 'Use familiar cmd.exe commands in PowerShell with opt-in PSReadLine review and preview-only removal, copy, and move translations.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @('ConvertFrom-MuscleMemoryCommand', 'Enable-PSforMuscleMemory', 'Disable-PSforMuscleMemory')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            ProjectUri = 'https://github.com/shanselman/PSforMuscleMemory'
            LicenseUri = 'https://github.com/shanselman/PSforMuscleMemory/blob/main/LICENSE'
            Tags = @('PowerShell', 'PSReadLine', 'cmd', 'DOS', 'CommandLine')
            ReleaseNotes = 'Review supported cmd.exe translations before execution. Translated removal, copy, and move commands use -WhatIf. The DOS-style where command requires Windows.'
        }
    }
}
