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

Nushell initializes `fnm` through JSON output:

```nu
fnm env --json | from json | load-env
```

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

The script uses LunarVim's official Windows PowerShell installer command for the
`release-1.4/neovim-0.9` branch. The official Windows installer can be
interactive; this repo does not try to invent a silent mode around it.

Some LunarVim plugins compile native Treesitter-related components, so this repo
installs MSYS2 UCRT64 GCC and exposes `gcc.exe` on the user PATH. Neovim
providers are intentionally not managed separately here; LunarVim's installer or
runtime should handle what it needs.
