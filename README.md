# PSforMuscleMemory

Use familiar cmd.exe commands in PowerShell, with a chance to review the translation:

```powershell
dir /s 'my folder'  # Lists recursively
rd /s 'my folder'   # Previews recursive removal; does not delete
```

Press Enter once to see the PowerShell command, then Enter again to run it. Other commands run on the first Enter. Editing the rewrite makes it fresh input, so an ordinary PowerShell command runs immediately.

## Get started

Requires PowerShell 7.2+ and PSReadLine 2.2+ in an interactive terminal. Clone the repository and enable the module for the current session:

```powershell
git clone https://github.com/shanselman/PSforMuscleMemory.git
Set-Location PSforMuscleMemory
Import-Module .\PSforMuscleMemory.psd1
Enable-PSforMuscleMemory
```

To turn it off, run `Disable-PSforMuscleMemory`. It restores the original Enter binding if it has not been changed since enabling. Importing the module alone does not enable it or change your profile.

Enable refuses Vi mode and custom Enter bindings. It preserves an existing validation hook with `AcceptLine`, but refuses `ValidateAndAcceptLine` with a validation hook because that hook could alter a preview. Installing such a hook afterward blocks Enter until the conflict is removed or the module is disabled.

## Safety and supported syntax

Every `rd /s` translation includes **`-WhatIf`**; there is no deletion mode. This is not a general deletion safeguard: normal PowerShell commands, scripts, alternate accept bindings, and commands entered while disabled are not protected. Editing away `-WhatIf` removes preview protection and can permit real deletion.

Use `dir /s [path]` or `rd /s path`, with the switch and path in either order. `dir /s` alone lists the current directory. Commands and `/s` are case-insensitive. Paths are literal: `dir /s *.txt` is not a recursive filename-pattern search. Quote paths with spaces. Paths beginning with `/` or `-`, variables, other switches, pipelines, redirections, and multiple commands are not supported. Unsupported `rd /s` input is rejected. No `-Force` is added.

## Tests

Run `.\tests\PSforMuscleMemory.Tests.ps1`. The tests leave a uniquely named fixture in the system temporary directory rather than deleting it. Automated checks passed on Windows with PowerShell 7.7 and PSReadLine 2.2 and 2.4.5. Both commands were also verified interactively with PowerShell 7.7 in a normal-profile terminal using `AcceptLine` and an existing validation hook.
