#!/usr/bin/env bash
set -euo pipefail

repo_url="${DOTFILES_REPO_URL:-https://github.com/jukrb0x/dotfiles.git}"
brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
chezmoi_source="$HOME/.local/share/chezmoi"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This bootstrap supports dnf-based Linux distributions only." >&2
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "dnf is required for this CentOS-like bootstrap." >&2
  exit 1
fi

install_dnf_prerequisites() {
  dnf -y group install "Development Tools"
  dnf -y install procps-ng curl file git zsh
}

linuxbrew_owner() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi

  logname 2>/dev/null || true
}

if [[ ! -x "$brew_bin" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    install_dnf_prerequisites

    owner="$(linuxbrew_owner)"
    if [[ -n "$owner" ]]; then
      owner_group="$(id -gn "$owner")"
      mkdir -p /home/linuxbrew
      chown -R "$owner:$owner_group" /home/linuxbrew
    fi

    echo "Re-run this bootstrap as your normal Linux user to install Homebrew." >&2
    exit 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo bash -c "$(declare -f install_dnf_prerequisites); install_dnf_prerequisites"
  else
    echo "Install dnf prerequisites first as root:" >&2
    echo "  dnf -y group install 'Development Tools'" >&2
    echo "  dnf -y install procps-ng curl file git zsh" >&2
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
