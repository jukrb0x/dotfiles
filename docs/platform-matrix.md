# Platform matrix

## Shared

- `~/.gitconfig`, with OS-specific rendering and local includes for private data
- `~/.gitignore_global`
- `~/.vimrc`
- `~/.ideavimrc`
- `~/.config/nvim/init.lua`
- `~/.config/lvim/config.lua`

## macOS only

- `~/.zshrc`
- `~/.zsh_aliases`
- `~/.p10k.zsh`
- `~/.tmux` and `~/.tmux.conf*`
- `~/.sleep` and `~/.wakeup`
- `~/.config/ghostty/config`
- `~/.config/karabiner/karabiner.json`
- `~/.gnupg/gpg-agent.conf`
- required Homebrew sync through `packages/Brewfile.required` and the macOS chezmoi onchange script
- optional Homebrew setup through `packages/Brewfile.optional`, `packages/Brewfile.fonts`, `packages/Brewfile.toolchains`, and the matching `scripts/install-macos-*.sh` commands

## Windows only

- `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
- `~/AppData/Roaming/nushell/config.nu`
- `~/AppData/Roaming/nushell/env.nu`
- `~/.local/bin/lvim.bat`
- `~/.local/bin/lvim.ps1`
- current-user font installation through `scripts/install-windows-fonts.ps1`
- Windows package notes under `packages/windows-*.txt`

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
