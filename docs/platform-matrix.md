# Platform matrix

## Shared

- `~/.gitconfig`, with OS-specific rendering and local includes for private data
- `~/.gitignore_global`
- `~/.vimrc`
- `~/.ideavimrc`
- `~/.config/nvim/init.lua`
- `~/.config/lvim/config.lua`

## macOS only

- `~/.sleep` and `~/.wakeup`
- `~/.config/ghostty/config`
- `~/.config/karabiner/karabiner.json`
- required Homebrew sync through `packages/Brewfile.required`, `packages/Brewfile.macos.required`, and the macOS chezmoi onchange script
- optional Homebrew setup through `packages/Brewfile.optional`, `packages/Brewfile.macos.optional`, `packages/Brewfile.fonts`, `packages/Brewfile.toolchains`, `packages/Brewfile.macos.toolchains`, and the matching `scripts/install-macos-*.sh` commands

## macOS and Linux

- `~/.zshrc`
- `~/.zsh_aliases`
- `~/.zprofile`
- `~/.p10k.zsh`
- `~/.tmux` and `~/.tmux.conf*`
- `~/.gnupg/gpg-agent.conf`, rendered with platform-specific pinentry

## Linux only

- required Linuxbrew sync through `packages/Brewfile.required`, `packages/Brewfile.linux.required`, and the Linux chezmoi onchange script
- optional Linuxbrew setup through `packages/Brewfile.optional`, `packages/Brewfile.toolchains`, `packages/Brewfile.linux.toolchains`, and the matching `scripts/install-linux-*.sh` commands

## WSL only

- WSL bootstrap through `bootstrap/wsl.sh`

## Windows only

- `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
- `~/AppData/Roaming/nushell/config.nu`
- `~/AppData/Roaming/nushell/env.nu`
- `~/.local/bin/lvim.bat`
- `~/.local/bin/lvim.ps1`
- current-user font installation through `scripts/install-windows-fonts.ps1`
- Windows package notes under `packages/windows-*`

## Machine-local

- `~/.gitconfig.local`
- `~/.gitconfig-work`
- `~/.gitconfig-personal`
- `~/.zshrc.local.pre`
- `~/.zshrc.local`
- `~/.zprofile.local`
- 1Password-managed secrets
- private or account-specific Git settings
- folder-based Git identity rules
- Work/company hostnames, domains, credentials, remotes, and email addresses
