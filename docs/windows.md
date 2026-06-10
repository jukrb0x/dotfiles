# Windows setup

Windows setup is intentionally split by chosen installer source. The rule is
not "GUI uses winget, CLI uses Scoop"; choose the source that is most official,
readable, and stable for each tool.

## Bootstrap

Start with only the tools needed to fetch and inspect the dotfiles:

```powershell
winget install --id Git.Git --exact --source winget --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id twpayne.chezmoi --exact --source winget --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
```

Initialize the repo, but do not apply immediately:

```powershell
chezmoi init https://github.com/jukrb0x/dotfiles.git
chezmoi cd
```

Create local Git identity before applying the managed Git config:

```powershell
notepad $HOME\.gitconfig.local
```

Example local identity:

```ini
[user]
    name = Your Name
    email = you@example.com

[commit]
    gpgsign = false
```

Preview the apply set:

```powershell
chezmoi managed --include files
chezmoi diff
```

Apply only after the diff looks right:

```powershell
chezmoi apply
```

Then install Windows apps and CLI tools:

```powershell
pwsh ./scripts/set-windows-user-path.ps1
pwsh ./scripts/install-windows-apps.ps1
pwsh ./scripts/install-windows-fonts.ps1
pwsh ./scripts/install-windows-scoop.ps1
pwsh ./scripts/install-windows-toolchains.ps1
pwsh ./scripts/install-windows-lunarvim.ps1
```

## WinGet

Use `winget` for Windows apps and tools whose official Windows install path is
clear through WinGet:

```powershell
pwsh ./scripts/install-windows-apps.ps1
```

The WinGet script is ordered by setup flow:

- foundation tools
- secrets app
- editors
- terminals
- shell runtime tools
- command-line tools with clear WinGet packages
- developer tools
- IDEs

1Password is installed as an app, but secrets and private identity still live
outside the dotfiles repo. Add the 1Password CLI only when a dotfile workflow
actually needs `op`.

The script uses WinGet's non-interactive flags for normal WinGet packages:

- `--silent`
- `--disable-interactivity`
- `--accept-source-agreements`
- `--accept-package-agreements`

Raycast for Windows is intentionally not included in the script for now. It is a
Microsoft Store package, and WinGet/Store acquisition can hang or fail even when
`winget install raycast` works manually. Install it manually from the official
Raycast Windows page or Microsoft Store until that path is reliable enough to
script.

Starship is installed here because the official Starship Windows instructions
list `winget install --id Starship.Starship`.

Nushell is also installed here instead of Scoop because it is the daily shell,
not just an interchangeable CLI utility. Nushell's official Windows docs list
both WinGet and Scoop; WinGet now supports user-scope Nushell installs by
default.

Some CLI tools also live in the WinGet script when their project docs point at
WinGet directly, or when the WinGet package is clearly newer/better maintained:

- `zoxide`: official Windows recommendation is WinGet
- `lazygit`: official Windows install docs list WinGet
- `ripgrep`: official docs list both Scoop and WinGet, and the WinGet MSVC
  package is current
- `eza`: official docs list both, with a clear WinGet package
- `tlrc`: official docs list both, with a clear WinGet package
- `delta`: official docs list both, with a clear WinGet package
- `dust` and `duf`: WinGet packages are current and clear
- `btop`: WinGet is used because the Scoop package's install script can fail
  when its default config file already exists in the extracted app directory

## Fonts

Install terminal/editor fonts separately:

```powershell
pwsh ./scripts/install-windows-fonts.ps1
```

The font script installs current-user fonts for:

- JetBrains Mono from JetBrains' official release
- Meslo Nerd Font for terminals
- Monaspace Nerd Font, GitHub's type family patched with Nerd Font glyphs

It downloads JetBrains Mono from JetBrains' official release and terminal Nerd
Fonts from the Nerd Fonts GitHub releases. Fonts are registered under the
current user's Windows font registry, and the registry names are read from the
font metadata instead of guessed from filenames.

Use the upstream font name for JetBrains editor settings:

- Editor font: `JetBrains Mono`
- Terminal font: `MesloLGM Nerd Font Mono` unless another Meslo size variant
  is preferred
- Monaspace Nerd Font: Nerd Fonts exposes GitHub's Monaspace family as
  `Monaspice...`; use `MonaspiceNe NFM` for a good default mono variant

## Scoop

Use Scoop for small command-line utilities where Scoop gives a clean,
portable, user-scoped install. The script installs Scoop if it is missing, then
installs every package listed in `packages/windows-scoop.txt`:

```powershell
pwsh ./scripts/install-windows-scoop.ps1
```

Scoop is a per-user package manager by default, but this Windows setup assumes
the terminal may run elevated. The script uses Scoop's official `-RunAsAdmin`
installer switch when Scoop is missing.

This is the Windows equivalent of keeping a small Brewfile-like CLI list.
Scoop is command-line/script-friendly by design; the script installs packages in
one `scoop install ...` call.

The Scoop list is intentionally small. It currently keeps tools like `bat`,
`fd`, and `fzf` where the official docs list both WinGet and Scoop and Scoop's
shim-based user install is simple, plus `make` where the WinGet option is less
appealing for this setup.

## TODO

- Revisit whether any low-risk Windows setup should move into
  `.chezmoiscripts` after this manual bootstrap has been used successfully on a
  real machine.

## Toolchains

Keep language toolchain choices explicit:

- WSL: `wsl --install`
- Rust: `rustup`
- Python: `uv`
- Node: `fnm` plus Corepack-managed `pnpm`
- Go: WinGet stable Go for now
- Bun: WinGet Bun

See `docs/toolchains.md`.

Do not put private work identity, company paths, tokens, remotes, or emails in
the dotfiles repo.

## PATH

Windows command locations belong in the user `Path` environment variable, not in
shell profiles. Run this whenever a fresh machine is missing expected command
paths:

```powershell
pwsh ./scripts/set-windows-user-path.ps1
```

It ensures these user paths exist:

- `%USERPROFILE%\.local\bin`
- `%USERPROFILE%\scoop\shims`
- `%LOCALAPPDATA%\Microsoft\WinGet\Links`

Restart terminals after updating user environment variables.
