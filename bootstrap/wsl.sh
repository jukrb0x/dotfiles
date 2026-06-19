#!/usr/bin/env bash
set -euo pipefail

repo_url="${DOTFILES_REPO_URL:-https://github.com/jukrb0x/dotfiles.git}"
brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
chezmoi_source="$HOME/.local/share/chezmoi"

if [[ "$(uname -s)" != "Linux" ]] || ! grep -qi microsoft /proc/version; then
  echo "This bootstrap supports Ubuntu on WSL only." >&2
  exit 1
fi

install_apt_prerequisites() {
  apt-get update
  apt-get install -y build-essential ca-certificates curl file git procps zsh
}

if [[ ! -x "$brew_bin" ]]; then
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get is required for this WSL bootstrap." >&2
    exit 1
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    install_apt_prerequisites
    mkdir -p /home/linuxbrew
    chown -R "${SUDO_USER:-$(logname)}:${SUDO_USER:-$(logname)}" /home/linuxbrew
    echo "Re-run this bootstrap as your normal WSL user to install Homebrew." >&2
    exit 0
  fi

  if sudo -n true >/dev/null 2>&1; then
    sudo bash -c "$(declare -f install_apt_prerequisites); install_apt_prerequisites"
  else
    echo "Install apt prerequisites first, for example from Windows:" >&2
    echo "  wsl.exe -d Ubuntu -u root -- bash -lc 'apt-get update && apt-get install -y build-essential ca-certificates curl file git procps zsh'" >&2
    exit 1
  fi

  echo "Homebrew is missing; installing Homebrew for Linux."
  NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$("$brew_bin" shellenv)"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi is missing; installing chezmoi with Homebrew."
  brew install chezmoi
fi

if [[ -d "$chezmoi_source/.git" ]]; then
  echo "chezmoi is already initialized at $chezmoi_source."
  echo "Next step: run chezmoi diff."
  exit 0
fi

echo "Initializing chezmoi from $repo_url."
chezmoi init "$repo_url"

echo "chezmoi initialization completed without applying changes."
echo "Next step: run chezmoi diff before chezmoi apply."
