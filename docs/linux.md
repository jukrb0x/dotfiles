# Linux

Linux setup follows the same three-layer model as macOS and Windows:

- bootstrap: install platform prerequisites, Homebrew for Linux, and chezmoi
- required state: apply managed dotfiles and required Linuxbrew packages
- optional setup: install heavier language runtimes, LunarVim, or machine preferences explicitly

The goal is a Mac-like zsh environment on Linux, not a copy of macOS paths.
Shared shell files are templated so Linux receives the zsh, Oh My Zsh,
Powerlevel10k, tmux, editor, Git, and CLI-tool configuration while macOS-only
apps and SDK paths stay on macOS.

## Required Packages

Required Linux packages live in:

- `packages/Brewfile.required`
- `packages/Brewfile.linux.required`

During `chezmoi apply`, the Linux chezmoi onchange script checks that Homebrew
is present and runs:

```shell
brew bundle --file=packages/Brewfile.required install
brew bundle --file=packages/Brewfile.linux.required install
```

Use `packages/Brewfile.required` for CLI tools shared with macOS when the
Homebrew formula name is portable. Keep Linux-only formulae in
`packages/Brewfile.linux.required` and macOS-only formulae such as
`pinentry-mac` in the macOS Brewfile.

## Shell

Linux uses zsh as the default shell:

```shell
chsh -s "$(command -v zsh)"
```

## Optional Toolchains

Optional Linux toolchains live in:

- `packages/Brewfile.toolchains`
- `packages/Brewfile.linux.toolchains`

Install them explicitly:

```shell
chezmoi cd
bash ./scripts/install-linux-toolchains.sh
```

This script also installs LunarVim with the official Linux/macOS installer,
matching the Windows and macOS model where LunarVim setup is explicit rather
than part of routine `chezmoi apply`.

Docker is intentionally not installed through Linuxbrew. On WSL, install Docker
Engine through apt and systemd with:

```shell
chezmoi cd
bash ./scripts/install-wsl-docker.sh
```

See [wsl.md](wsl.md) for the Docker verification steps.

## Optional Apps And Fonts

Shared optional Homebrew packages can be installed explicitly:

```shell
chezmoi cd
bash ./scripts/install-linux-apps.sh
```

There is no Linux fonts script yet. Add `scripts/install-linux-fonts.sh` only
when targeting a full Linux desktop where user-font installation can be handled
without distro-specific assumptions.

## Local Private Config

Keep machine-specific Linux values in local files:

- `~/.zshrc.local.pre`
- `~/.zshrc.local`
- `~/.zprofile.local`
- `~/.gitconfig.local`

These are intentionally unmanaged and can hold proxy, worktree, credential, or
host-specific settings.
