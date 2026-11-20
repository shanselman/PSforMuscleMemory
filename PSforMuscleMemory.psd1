@{
    RootModule = 'PSforMuscleMemory.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'e8098a42-ef0e-40be-b470-81822ad51c87'
    Author = 'PSforMuscleMemory contributors'
    Description = 'Opt-in cmd.exe muscle-memory translations with preview-only removal.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @('ConvertFrom-MuscleMemoryCommand', 'Enable-PSforMuscleMemory', 'Disable-PSforMuscleMemory')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
