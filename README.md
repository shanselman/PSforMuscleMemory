# PSforMuscleMemory

Use familiar cmd.exe commands in PowerShell, with a chance to review the translation:

```powershell
cd /d 'D:\my folder' # Changes location, including drive
dir /b               # Lists bare names
dir /s *.txt         # Lists matching filenames recursively
dir /a               # Includes hidden and system entries
dir /o:n             # Lists by name, ascending
dir /o:-d            # Lists newest entries first
rd /s /q 'my folder' # Previews recursive removal; does not delete
del /s *.txt         # Previews matching file removal; does not delete
where git*           # Searches the current directory and PATH
sort file.txt        # Sorts lines in a file
copy /y source dest   # Previews a copy; does not overwrite
move /y source dest   # Previews a move; does not overwrite
```

Press Enter once to see the PowerShell command, then Enter again to run it. Other commands run on the first Enter. Editing the rewrite makes it fresh input, so an ordinary PowerShell command runs immediately.

## Get started

Requires PowerShell 7.2+ and PSReadLine 2.2+ in an interactive terminal.

### PowerShell Gallery (after publication)

Use the `Install-Module` command from PowerShellGet to install for your user account, then import and enable the module for the current session:

```powershell
Install-Module -Name PSforMuscleMemory -Repository PSGallery -Scope CurrentUser
Import-Module PSforMuscleMemory
Enable-PSforMuscleMemory
```

### Clone from GitHub

To try the module before publication, clone the repository and enable it for the current session:

```powershell
git clone https://github.com/shanselman/PSforMuscleMemory.git
Set-Location PSforMuscleMemory
Import-Module .\PSforMuscleMemory.psd1
Enable-PSforMuscleMemory
```

To turn it off, run `Disable-PSforMuscleMemory`. It restores the original Enter binding if it has not been changed since enabling. Importing the module alone does not enable it or change your profile.

Enable refuses Vi mode and custom Enter bindings. It preserves an existing validation hook with `AcceptLine`, but refuses `ValidateAndAcceptLine` with a validation hook because that hook could alter a preview. Installing such a hook afterward blocks Enter until the conflict is removed or the module is disabled.

## Safety and supported syntax

Every `rd /s`, `del /s`, `copy /y`, and `move /y` translation includes **`-WhatIf`**; there is no deletion or overwrite mode. `rd /s /q` remains preview-only despite cmd.exe's quiet-delete meaning. `del /s` previews matching files in the current directory tree and never removes directories. `copy /y` and `move /y` preview one literal source and destination; they do not overwrite or move files. This is not a general safeguard: normal PowerShell commands, scripts, alternate accept bindings, and commands entered while disabled are not protected. Editing away `-WhatIf` removes preview protection and can permit real deletion or overwrite.

Supported forms are `cd /d path`, `dir /b [path]`, `dir /s [path-or-filename-pattern]`, `dir /a [path]`, `dir /o:n [path]`, `dir /o:-d [path]`, `rd /s [/q] path`, `del /s filename-pattern`, `where filename-pattern`, `sort filename`, `copy /y source destination`, and `move /y source destination`. Paths are literal and may be quoted; quote paths with spaces. `dir /s *.txt` and `del /s *.txt` match filenames recursively in the current directory tree; `del /s` patterns must be filename-only. `dir /a` includes hidden and system entries. The supported `/o` options sort by name ascending or modification time newest first.

On Windows, `where` calls the system `where.exe` to search the current directory and PATH for all matches. It accepts one filename pattern (`*` and `?` are allowed), without search locations or extra switches. This shorthand is unavailable outside Windows. Standalone `sort filename` sorts lines from one literal file; PowerShell pipelines such as `gci | sort Name.Length` pass through unchanged. Copy and move previews require `/y` and exactly one literal source and destination; unflagged PowerShell copy and move commands pass through unchanged and are not previewed. Commands and switches are case-insensitive. Variables, expressions, unsupported switches, pipelines, redirections, and multiple commands are rejected for attempted DOS forms. Other commands pass through unchanged.

## Tests

Run `.\tests\PSforMuscleMemory.Tests.ps1` in a fresh PowerShell session (`pwsh -NoProfile`). The suite checks translations, pass-through, preview safety, and the two-Enter flow. It leaves a uniquely named fixture in the system temporary directory rather than deleting it.

## License

[MIT](LICENSE)
