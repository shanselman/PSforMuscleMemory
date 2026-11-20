# PSforMuscleMemory

Use familiar `cmd.exe` shortcuts in PowerShell. Try `cd %temp%`: the first Enter shows `cd $env:TEMP`; the second runs it. Ordinary PowerShell commands still run on the first Enter.

## Get started

Requires PowerShell 7.2+ and PSReadLine 2.2+ in an interactive terminal.

Install from PowerShell Gallery with PowerShellGet, then enable it for this session:

```powershell
Install-Module -Name PSforMuscleMemory -Repository PSGallery -Scope CurrentUser
Import-Module PSforMuscleMemory
Enable-PSforMuscleMemory
```

To enable it in future sessions, add the `Import-Module` and `Enable-PSforMuscleMemory` lines to the file at `$PROFILE` (create it if it doesn't exist). Run `Disable-PSforMuscleMemory` to turn it off for the current session. Importing the module alone doesn't change your Enter key. The module doesn't support PSReadLine Vi mode or custom Enter bindings.

If you prefer to clone this repo, run `Import-Module .\PSforMuscleMemory.psd1` from the clone, then `Enable-PSforMuscleMemory`.

## What works

| Shortcut | What it does |
| --- | --- |
| `cd /d path` | Changes folder and drive. |
| `dir /b [path]`, `dir /a [path]` | Lists just the names, or includes hidden and system items, respectively. |
| `dir /s [path-or-filename-pattern]` | Lists recursively; `dir /s *.txt` finds matching files under the current folder. |
| `dir /o:n [path]`, `dir /o:-d [path]` | Sorts by name or by newest first, respectively. |
| `where filename-pattern` | On Windows only, searches the current folder and `PATH` using `where.exe`. |
| `sort filename` | Sorts lines in one file. |
| `rd /s [/q] path`, `del /s filename-pattern` | Previews removing a folder tree or matching files under the current folder. `del /s` never matches folders. |
| `copy /y source destination`, `move /y source destination` | Previews copying or moving one source to one destination. |

Use one command at a time. Quote literal paths with spaces. The DOS shortcuts don't support extra switches, PowerShell expressions, pipes, or redirection. `where` and `del /s` take a filename pattern, not a path.

`%NAME%` works in unquoted arguments to `cd` and the DOS shortcuts above. Names aren't case-sensitive. Undefined names and quoted arguments are left alone. The preview shows a `$env:` reference, not its value; the second Enter uses the current value.

## Safety

Translated removal, copy, and move commands always include `-WhatIf`, even with `rd /s /q`. **Don't remove `-WhatIf` unless you intend to run the real operation.** Editing a translation makes it a new command. Ordinary PowerShell commands (including `rd`, `del`, `copy`, and `move` without the DOS switches above), scripts, and other ways of submitting commands are not protected.

## Tests

Run `.\tests\PSforMuscleMemory.Tests.ps1` in a fresh `pwsh -NoProfile` session. The tests leave a fixture in your temp folder.

## Publish a release

Maintainers need the repository secret `PSGALLERY_API_KEY` set to a PowerShell Gallery API key. To release a new version, bump `ModuleVersion` in `PSforMuscleMemory.psd1`, update its release notes, and commit and push those changes to `main`. Then tag that commit and push the tag, for example:

```powershell
git tag v0.2.1
git push origin v0.2.1
```

The tag must exactly match `v<ModuleVersion>`. The GitHub Action runs the Windows PowerShell tests, validates the manifest, and publishes only the manifest, module, README, and LICENSE to the official PowerShell Gallery using PowerShellGet. Check the action run for the result. Version `0.2.0` is already published; use a new version for each release.

## License

[MIT](LICENSE)
