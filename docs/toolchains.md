# Windows toolchains

Toolchains are split by ownership:

- Required editor/compiler dependencies are synchronized by `chezmoi apply`.
- Optional language runtimes are installed explicitly with scripts.

## Required

Required packages are the tools managed dotfiles need in order to work:

- Neovim: `packages/windows-winget-required.txt`
- ripgrep: `packages/windows-winget-required.txt`
- make: `packages/windows-scoop-required.txt`
- MSYS2: `packages/windows-winget-required.txt`
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

On Windows, this repo manages:

- LunarVim config
- `lvim.bat`
- `lvim.ps1`
- required compiler/editor dependencies through `chezmoi apply`

The actual LunarVim installation runs at the end of:

```powershell
pwsh ./scripts/install-windows-toolchains.ps1
```

The script uses the Windows PowerShell installer from the `jukrb0x/LunarVim`
fork on the `codex/nvim-012-legacy-treesitter` branch. This branch keeps
LunarVim's legacy plugin graph intact and shadows the archived
`nvim-treesitter` query predicate module with a Neovim 0.12-compatible version.
The installer can be
interactive; this repo does not try to invent a silent mode around it.

Some LunarVim plugins compile native Treesitter-related components, so this repo
installs MSYS2 UCRT64 GCC and exposes `gcc.exe` on the user PATH. The Windows
toolchain script also installs the prebuilt `tree-sitter` CLI into
`~/.local/bin` for parser installs and updates. Neovim providers are
intentionally not managed separately here; LunarVim's installer or runtime
should handle what it needs.
