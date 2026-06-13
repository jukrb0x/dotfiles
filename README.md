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
packages/Brewfile
                 compatibility macOS Homebrew bundle
packages/Brewfile.required
                 required macOS packages synced by chezmoi apply
packages/Brewfile.optional
                 optional macOS apps and tools
packages/Brewfile.fonts
                 optional macOS fonts
packages/Brewfile.toolchains
                 optional macOS toolchains
setup.sh         legacy macOS Apple Silicon bootstrap
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

### 2. Required State

`chezmoi apply` owns state that the managed dotfiles need in order to work:

- shell/editor configuration files
- lightweight PATH setup
- required command-line tools
- required editor compiler/runtime dependencies

On Windows, required packages are declared in:

- `packages/windows-winget-required.txt`
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
synchronized by `chezmoi apply`. Optional apps, fonts, and toolchains live in
separate Brewfiles under `packages/` and are installed only by explicit scripts.

See [docs/macos.md](docs/macos.md) for fresh setup, existing-machine migration,
daily maintenance, and the required-vs-optional Homebrew model.

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
