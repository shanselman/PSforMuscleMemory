# PSforMuscleMemory

An opt-in PowerShell module for two cmd.exe habits:

```powershell
dir /s 'my folder'  # Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath 'my folder' -Recurse
rd /s 'my folder'   # Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'my folder' -Recurse -WhatIf
```

`dir /s` without a path lists the current directory. The switch and path may appear in either order. Commands and `/s` are case-insensitive. Supply one literal path (quoted if necessary); variables, expansions, other switches, pipelines, redirections, and multiple commands are not supported. Paths beginning with `/` or `-` are not supported in this prototype. Paths are treated literally, including wildcard characters. No `-Force` is added.

For a supported command, the first Enter rewrites the line without running it. Review the PowerShell command, then press Enter again to run it. If you edit the rewrite, the next Enter treats it as fresh input: another supported muscle-memory command is rewritten for review; an ordinary PowerShell command runs immediately.

## Try it

Requires PowerShell 7.2 or newer and PSReadLine 2.2 or newer in an interactive host. Tested with PowerShell 7.7 and PSReadLine 2.2 on Windows. Clone this repository, then:

```powershell
Import-Module .\PSforMuscleMemory.psd1
Enable-PSforMuscleMemory
dir /s .
rd /s '.\folder to preview'
Disable-PSforMuscleMemory
Remove-Module PSforMuscleMemory
```

Run the examples from the repository directory. Importing alone does not change key bindings. Enable installs a session-only Enter handler; disable or module removal restores the original Enter binding if it is still ours. Enable refuses Vi mode, an existing custom Enter binding, or an existing PSReadLine command-validation handler rather than replacing them. If a validation handler is installed afterward, Enter refuses to execute until the conflict is removed or this module is disabled.

## Safety boundary

Every `rd /s` translation is a **preview**, always using `-WhatIf`; there is no deletion mode or opt-out. Unsupported `rd /s` input seen by this Enter handler is rejected instead of running the `rd` alias. Editing the rewritten line can turn it into an ordinary PowerShell command, which is not protected: removing `-WhatIf` can allow actual deletion. This is not a general deletion safeguard: native PowerShell commands, `rd` without `/s`, scripts, alternate PSReadLine accept bindings, other hosts, and commands entered while disabled are outside its scope. Do not rely on it as a security boundary. Changing PSReadLine settings or key bindings while enabled can bypass or disrupt interception.

For a pure translation without enabling interactive interception, use `ConvertFrom-MuscleMemoryCommand 'rd /s .\example'`. It returns the translated command as text, returns unrelated input unchanged, and throws for unsupported attempted translations. It does not execute the returned text.

## Tests

Run `.\tests\PSforMuscleMemory.Tests.ps1` in PowerShell 7. The filesystem test creates a uniquely named fixture under the system temporary directory and leaves it there so the test never performs live deletion.
