# Windows setup

Windows setup is split into three paths:

1. Bootstrap: install only the minimum tools needed to run chezmoi reliably.
2. Chezmoi apply: maintain required state for managed dotfiles.
3. Optional setup: install heavier apps, fonts, IDEs, and preference-driven tools.

## Bootstrap

Bootstrap is intentionally small. It is only responsible for making `chezmoi
apply` possible on a fresh Windows machine:

- Git
- PowerShell 7
- chezmoi
- current-user PowerShell execution policy

Run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
powershell -ExecutionPolicy Bypass -File ./bootstrap/windows.ps1
```

Then open PowerShell 7 and initialize/apply the dotfiles:

```powershell
chezmoi init https://github.com/jukrb0x/dotfiles.git
chezmoi apply
```

If the repo is already initialized:

```powershell
chezmoi apply
```

## Automatic Required State

`chezmoi apply` owns only the state required for managed dotfiles to work.
These scripts live in `home/.chezmoiscripts` and are templated so they only run
on Windows:

- `run_after_10-windows-user-path.ps1.tmpl`
- `run_onchange_after_20-windows-winget-required.ps1.tmpl`
- `run_onchange_after_30-windows-scoop-required.ps1.tmpl`
- `run_onchange_after_40-windows-msys2-required.ps1.tmpl`

Required package lists live in `packages/`:

- `windows-winget-required.txt`
- `windows-scoop-required.txt`
- `windows-msys2-required.txt`

Use this rule when deciding whether something belongs there:

- Put it in required if a managed shell/editor config needs it to start or work.
- Keep it manual if it is a GUI app, font, IDE, large language environment, or personal preference.

## Daily Maintenance

For normal dotfiles updates:

```powershell
chezmoi update
```

For local source changes:

```powershell
chezmoi apply
```

`run_onchange_` scripts rerun only when their rendered script content changes.
The Windows package scripts include a checksum of their package-list file, so
editing a required package list triggers the matching package sync.

## Optional Machine Setup

These scripts are explicit bootstrap helpers, not automatic required state:

```powershell
chezmoi cd
pwsh ./scripts/install-windows-apps.ps1
pwsh ./scripts/install-windows-fonts.ps1
pwsh ./scripts/install-windows-scoop.ps1
pwsh ./scripts/install-windows-toolchains.ps1
```

Use them when you want the fuller machine setup. They should not duplicate
packages already owned by `packages/*-required.txt`.

## WinGet

Required WinGet packages are synchronized by chezmoi from
`packages/windows-winget-required.txt`.

Optional WinGet apps and tools live in `scripts/install-windows-apps.ps1`.
This keeps GUI apps, IDEs, and preference-heavy tools out of routine
`chezmoi apply` runs.

## Scoop

Required Scoop packages are synchronized by chezmoi from
`packages/windows-scoop-required.txt`.

Optional Scoop packages live in `packages/windows-scoop.txt` and are installed
by:

```powershell
pwsh ./scripts/install-windows-scoop.ps1
```

Scoop is per-user by default. The install script uses Scoop's official
`-RunAsAdmin` installer switch when Scoop is missing, because this setup may run
from an elevated terminal.

## Fonts

Fonts are optional machine setup, not required dotfiles state:

```powershell
pwsh ./scripts/install-windows-fonts.ps1
```

The font script installs current-user fonts for JetBrains Mono, Meslo Nerd Font,
and Monaspace Nerd Font.

## Toolchains

Required editor/compiler dependencies are synchronized by chezmoi:

- MSYS2 from `packages/windows-winget-required.txt`
- MSYS2 UCRT64 GCC from `packages/windows-msys2-required.txt`

Optional language toolchains are installed explicitly:

```powershell
pwsh ./scripts/install-windows-toolchains.ps1
```

The optional toolchain script installs language managers/runtimes such as `fnm`,
`uv`, `rustup`, Go, and Bun, then runs the LunarVim Windows installer.

## PATH

Windows command locations belong in the user `Path` environment variable, not in
shell profiles. `chezmoi apply` runs the PATH script automatically, and the same
logic can be run manually if needed:

```powershell
pwsh ./scripts/set-windows-user-path.ps1
```

It ensures these user paths exist:

- `%APPDATA%\..\bin`
- `%USERPROFILE%\.local\bin`
- `%USERPROFILE%\scoop\shims`
- `%LOCALAPPDATA%\Microsoft\WinGet\Links`
- `C:\msys64\ucrt64\bin`

Managed paths are placed before existing user paths so uv's Python launchers win
over the Microsoft Store aliases in `%LOCALAPPDATA%\Microsoft\WindowsApps`.

Restart terminals after updating user environment variables. GUI-launched tools
may need a sign out/sign in cycle before they inherit the updated user PATH.
