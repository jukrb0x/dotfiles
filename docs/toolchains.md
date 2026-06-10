# Windows toolchains

Toolchains are separate from app installation because they manage language
versions, PATH behavior, project runtimes, and global developer commands.

## Defaults

- Node/npm: `fnm`
- pnpm: Corepack-managed pnpm
- Python: `uv`
- Rust: `rustup`
- Go: WinGet stable Go
- Bun: WinGet Bun

Run:

```powershell
pwsh ./scripts/install-windows-toolchains.ps1
```

Nushell initializes `fnm` through JSON output:

```nu
fnm env --json | from json | load-env
```

Then `FNM_MULTISHELL_PATH` is prepended to `PATH`, which lets Nushell resolve
`node`, `npm`, and Corepack-managed package managers. This follows the approach
discussed in Schniz/fnm#463 without adding a third-party helper.

pnpm is activated through Corepack after the LTS Node version is installed.

## LunarVim

The macOS setup already installs LunarVim from
`.chezmoiscripts/run_onchange_before_install-packages.sh`.

On Windows, this repo manages:

- LunarVim config
- `lvim.bat`
- `lvim.ps1`

The actual LunarVim installation runs at the end of:

```powershell
pwsh ./scripts/install-windows-toolchains.ps1
```

The script uses LunarVim's official Windows PowerShell installer command for the
`release-1.4/neovim-0.9` branch. The official Windows installer can be
interactive; this repo does not try to invent a silent mode around it.

LunarVim's official Windows prerequisites include Neovim, Git, make, Python,
npm/Node, cargo, ripgrep, and PowerShell 7. This repo installs most of those
through the app, Scoop, and toolchain scripts. Neovim providers are intentionally
not managed separately here; LunarVim's installer/runtime should handle what it
needs.
