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
- `~/.config/yarn/global/package.json`
- `~/.gnupg/gpg-agent.conf`
- Logseq settings, until Windows usage is confirmed
- `.chezmoiscripts/run_onchange_before_install-packages.sh`
- Homebrew setup through `Brewfile` and `setup.sh`

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
- 1Password-managed secrets
- private or account-specific Git settings
- folder-based Git identity rules
- Work/company hostnames, domains, credentials, remotes, and email addresses
