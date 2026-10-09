# Toolchains

Toolchains are split by ownership:

- Required editor/compiler dependencies are synchronized by `chezmoi apply`.
- Optional language runtimes are installed explicitly with scripts.

## Required

Required packages are the tools managed dotfiles need in order to work:

- Neovim: `packages/windows-winget-required.psd1`
- ripgrep: `packages/windows-winget-required.psd1`
- make: `packages/windows-scoop-required.txt`
- MSYS2: `packages/windows-winget-required.psd1`
- MSYS2 UCRT64 GCC: `packages/windows-msys2-required.txt`

These are applied by Windows scripts in `home/.chezmoiscripts`.

MSYS2 is installed with WinGet because it is the official Windows distribution
for the MinGW-w64 environment this setup needs. GCC itself is installed with
MSYS2's `pacman`, not Scoop, so native builds use the matching UCRT64 runtime,
headers, libraries, and package ecosystem.

## Optional

Run the explicit full toolchain bootstrap when setting up a machine manually:

```powershell
pwsh ./scripts/install-windows-toolchains.ps1
```

This installs:

- Node/npm: `fnm`
- pnpm: Corepack-managed pnpm
- Python: `uv`
- Rust: `rustup`
- Go: WinGet stable Go
- Bun: WinGet Bun
- tree-sitter CLI: WinGet `tree-sitter.tree-sitter-cli` with
  `Version = "0.26"` in `packages/windows-winget-toolchains.psd1`

Python is installed with `uv python install`. If `python` is missing, or if it
only resolves to the Microsoft Store alias in `WindowsApps`, the script uses
`uv python install --default` so uv creates `python.exe`, `python3.exe`, and
versioned Python launchers. The Windows PATH script puts uv's executable
directories before the Microsoft Store aliases so plain `python` resolves to
uv-managed Python when uv owns the default launcher.

Nushell initializes `fnm` through JSON output:

```nu
fnm env --json | from json | load-env
```

Before running `fnm`, Nushell sets `XDG_STATE_HOME` to
`$env.LOCALAPPDATA/state`. `fnm` uses that state directory for
`FNM_MULTISHELL_PATH` before falling back to `XDG_CACHE_HOME`; this keeps the
per-shell Node shims out of `%TEMP%`.

Then `FNM_MULTISHELL_PATH` is prepended to `PATH`, which lets Nushell resolve
`node`, `npm`, and Corepack-managed package managers.

pnpm is activated through Corepack after the LTS Node version is installed.

## LunarVim

LunarVim installation is explicit on all platforms. `chezmoi apply` manages
`~/.config/lvim/config.lua` and required editor packages; Windows also gets
`lvim.bat` and `lvim.ps1`. Runtime installation lives in dedicated scripts:

| Platform | Install LunarVim only | Install toolchains and LunarVim |
| --- | --- | --- |
| macOS | `bash ./scripts/install-lunarvim.sh` | `bash ./scripts/install-macos-toolchains.sh` |
| Linux / WSL | `bash ./scripts/install-lunarvim.sh` | `bash ./scripts/install-linux-toolchains.sh` |
| Windows | `pwsh ./scripts/install-lunarvim.ps1` | `pwsh ./scripts/install-windows-toolchains.ps1` |

Run these commands from the source repo (`chezmoi cd`) after `chezmoi apply`.
Every toolchain script accepts `--no-lvim` to install language toolchains only.
The standalone Unix installer also forwards upstream arguments, such as
`--no-install-dependencies`. By default it allows upstream dependency prompts.

All platforms read `packages/lunarvim.env`, which selects the
`jukrb0x/LunarVim` fork and `codex/nvim-012-modern-treesitter` branch. Change
that manifest to update the source for all platforms together. This fork carries
compatibility fixes for modern Neovim and Treesitter. The platform wrappers
download the matching upstream Bash or PowerShell installer.

The Unix installer creates `~/.local/bin/lvim`; managed zsh already adds that
directory to PATH. Open a new shell and run `lvim` after installation. Existing
runtime/cache directories are backed up by upstream before replacement; the
managed `config.lua` is retained. Plugin downloads require network access.

Some LunarVim plugins compile native Treesitter-related components, so this repo
installs MSYS2 UCRT64 GCC and exposes `gcc.exe` on the user PATH. The Windows
toolchain script installs `tree-sitter.tree-sitter-cli` through WinGet with a
`0.26.*` version prefix from `packages/windows-winget-toolchains.psd1` for
parser installs and updates. Neovim providers are intentionally not managed
separately here; LunarVim's installer or runtime should handle what it needs.
