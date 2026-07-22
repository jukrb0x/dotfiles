<h1>
    <samp>dotfiles</samp>
</h1>

This is my personal operating environment: shell, editor, terminal, packages,
fonts, and the small defaults that make a computer feel like mine.

It is public for two reasons:

- to show my taste in tools and workflows
- to be a practical reference for anyone building their own managed environment,
  software setup, and dotfiles system

The repo is managed with [chezmoi](https://www.chezmoi.io/). If you are new to
dotfiles, [dotfiles.github.io](https://dotfiles.github.io/) is a good starting
point.

> [!TIP]
> Copy the ideas, not the whole thing blindly. The useful pattern here is how the
> environment is organized: minimal bootstrap, declarative required state, and
> explicit optional setup.

## What This Manages

- dotfiles with `chezmoi`
- shell configuration for PowerShell, Nushell, and zsh
- Neovim/LunarVim configuration
- Git defaults
- terminal/editor command shims
- package lists for required and optional tools
- Windows bootstrap and setup automation
- macOS Apple Silicon setup through the existing Homebrew flow
- Linux setup through Linuxbrew and shared zsh config
- WSL setup through Ubuntu prerequisites plus the Linux layer
- fonts and visual environment preferences

## Design Philosophy

A dotfiles repo should not be a giant mystery installer. It should explain what
kind of machine it wants to create, and it should make each layer easy to reason
about.

This repo is moving toward this model:

- **bootstrap** installs only the minimum tools required to run chezmoi
- **chezmoi apply** manages dotfiles and required runtime state
- **optional scripts** install heavier preferences such as apps, fonts, IDEs,
  and language runtimes

That separation keeps daily dotfile maintenance boring, while still making a new
machine fast to set up.

## Layout

```text
bootstrap/       minimal platform bootstrap scripts
home/            chezmoi source root, applied to $HOME
packages/        platform package manifests
scripts/         explicit optional setup/maintenance scripts
docs/            platform notes and setup decisions
packages/Brewfile.required
                 required cross-platform Homebrew packages synced by chezmoi apply
packages/Brewfile.macos.required
                 required macOS-only Homebrew packages synced by chezmoi apply
packages/Brewfile.linux.required
                 required Linux-only Homebrew packages synced by chezmoi apply
packages/Brewfile.optional
                 optional cross-platform Homebrew packages
packages/Brewfile.macos.optional
                 optional macOS-only Homebrew packages and casks
packages/Brewfile.fonts
                 optional macOS fonts
packages/Brewfile.toolchains
                 optional cross-platform Homebrew toolchains
packages/Brewfile.macos.toolchains
                 optional macOS-only Homebrew toolchains
packages/Brewfile.linux.toolchains
                 optional Linux-only Homebrew toolchains
```

## Setup Model

### 1. Bootstrap

Bootstrap is the smallest dependency chain needed to start chezmoi.

Windows bootstrap installs:

- Git
- PowerShell 7
- chezmoi

macOS bootstrap currently installs:

- Homebrew
- chezmoi

Linux bootstrap currently installs:

- dnf or apt prerequisites, depending on the entry point
- Homebrew for Linux
- chezmoi

### 2. Required State

`chezmoi apply` owns state that the managed dotfiles need in order to work:

- shell/editor configuration files
- lightweight PATH setup
- required command-line tools
- required editor compiler/runtime dependencies

On Windows, required packages are declared in:

- `packages/windows-winget-required.psd1`
- `packages/windows-scoop-required.txt`
- `packages/windows-msys2-required.txt`

Those lists are synchronized by Windows scripts in `home/.chezmoiscripts`.

### 3. Optional Setup

Optional scripts install larger or preference-heavy tools. They are run
explicitly, not as part of every `chezmoi apply`:

- GUI apps
- fonts
- IDEs
- optional CLI tools
- language runtimes/toolchains

This is where personal taste belongs when it is useful but not required for the
dotfiles to function.

## Windows

The Windows setup is the cleanest expression of the current model.

Fresh machine bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File ./bootstrap/windows.ps1
```

Then open PowerShell 7 and run:

```powershell
chezmoi init https://github.com/jukrb0x/dotfiles.git
chezmoi apply
```

Daily update:

```powershell
chezmoi update
```

Optional setup:

```powershell
chezmoi cd
pwsh ./scripts/install-windows-apps.ps1
pwsh ./scripts/install-windows-fonts.ps1
pwsh ./scripts/install-windows-scoop.ps1
pwsh ./scripts/install-windows-toolchains.ps1
```

Optional WinGet apps are declared in
`packages/windows-winget-apps.psd1`, including Microsoft Store entries that
need `PackageName` and `Source`.

WinGet upgrades are explicit. Preview available upgrades with:

```powershell
pwsh ./scripts/update-windows-winget.ps1
```

Upgrade only packages declared in this repo's WinGet manifests with:

```powershell
pwsh ./scripts/update-windows-winget.ps1 --managed
```

On Windows, RMUX is installed from the immutable personal fork Release pinned in
`packages/windows-rmux.psd1`, with a public-download path and authenticated `gh`
fallback. See `docs/windows.md` for update and file-lock behavior.

See [docs/windows.md](docs/windows.md) and
[docs/toolchains.md](docs/toolchains.md) for the current Windows setup model.

## macOS

macOS Apple Silicon bootstrap installs the minimum tools needed to initialize
chezmoi:

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/macos.sh)"
```

To use a fork or another remote, override the repo URL:

```shell
DOTFILES_REPO_URL=https://github.com/you/dotfiles.git /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/macos.sh)"
```

The bootstrap installs Homebrew only when it is missing, installs chezmoi only
when it is missing, and runs `chezmoi init` without applying changes.

Review the pending changes before applying them:

```shell
chezmoi diff
chezmoi apply
```

Do not skip `chezmoi diff`; the bootstrap is intentionally safe and does not run
`chezmoi apply` or `chezmoi init --apply`.

Required macOS packages are declared in `packages/Brewfile.required` and
`packages/Brewfile.macos.required`, then synchronized by `chezmoi apply`.
Optional apps, fonts, and toolchains live in separate Brewfiles under
`packages/` and are installed only by explicit scripts.

See [docs/macos.md](docs/macos.md) for fresh setup, existing-machine migration,
daily maintenance, and the required-vs-optional Homebrew model.

## Linux

Linux uses Homebrew for Linux, sharing the zsh-oriented shell setup with macOS
while keeping macOS-only paths and apps out of Linux.

CentOS-like bootstrap, including CentOS Stream, RHEL, Rocky Linux, AlmaLinux,
and Fedora-like hosts:

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/centos.sh)"
```

To use a fork or another remote, override the repo URL:

```shell
DOTFILES_REPO_URL=https://github.com/you/dotfiles.git /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jukrb0x/dotfiles/main/bootstrap/centos.sh)"
```

The bootstrap uses `dnf` for Linuxbrew prerequisites, installs Homebrew for
Linux when missing, installs chezmoi through Homebrew, and initializes without
applying changes.

See [docs/linux.md](docs/linux.md) for Linuxbrew package sync, shared shell
notes, and the local-run form of the bootstrap.

## WSL

See [docs/wsl.md](docs/wsl.md) for Ubuntu bootstrap, networking, and
default-shell notes.

## Maintenance

Preview changes before applying:

```shell
chezmoi diff
```

Apply local source changes:

```shell
chezmoi apply
```

Update from the remote repo and apply:

```shell
chezmoi update
```

Edit the source repo:

```shell
chezmoi cd
```

## Notes For Borrowing

If you are using this repo as a reference, start with the structure rather than
the package choices:

- keep bootstrap small
- keep required dependencies declarative
- make optional setup explicit
- make scripts idempotent
- document why a tool belongs in one layer instead of another

Your tools will differ from mine. The boundary between bootstrap, required state,
and optional taste is the part worth borrowing.

## References

- [chezmoi](https://www.chezmoi.io/)
- [dotfiles.github.io](https://dotfiles.github.io/)
