#!/usr/bin/env bash
set -euo pipefail

repo_url="${DOTFILES_REPO_URL:-https://github.com/jukrb0x/dotfiles.git}"
brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
chezmoi_bin="$(dirname -- "$brew_bin")/chezmoi"
chezmoi_source="$HOME/.local/share/chezmoi"

if [[ "$(uname -s)" != "Linux" ]] || ! grep -qi microsoft /proc/version; then
  echo "This bootstrap supports Ubuntu on WSL only." >&2
  exit 1
fi

install_apt_prerequisites() {
  apt-get update
  apt-get install -y build-essential ca-certificates curl file git procps zsh
}

linuxbrew_owner() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi

  logname 2>/dev/null || true
}

ensure_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    return
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y zsh
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y zsh
  else
    echo "zsh is required. Install it with: apt-get install -y zsh" >&2
    exit 1
  fi
}

print_next_steps() {
  echo "Next step: load Linuxbrew in this shell, then review and apply changes."
  echo "  eval \"\$($brew_bin shellenv)\""
  echo "  chezmoi diff"
  echo "  chezmoi apply"
  echo "  chsh -s \"$(command -v zsh)\""
  echo "Then start a new login session to use zsh."
  echo "If you do not want to change this shell's environment, use:"
  echo "  \"$chezmoi_bin\" diff"
  echo "  \"$chezmoi_bin\" apply"
}

if [[ ! -x "$brew_bin" ]]; then
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get is required for this WSL bootstrap." >&2
    exit 1
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    install_apt_prerequisites

    owner="$(linuxbrew_owner)"
    if [[ -n "$owner" ]]; then
      owner_group="$(id -gn "$owner")"
      mkdir -p /home/linuxbrew
      chown -R "$owner:$owner_group" /home/linuxbrew
    fi

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

ensure_zsh

if [[ ! -x "$chezmoi_bin" ]]; then
  echo "chezmoi is missing; installing chezmoi with Homebrew."
  brew install chezmoi
fi

if [[ -d "$chezmoi_source/.git" ]]; then
  echo "chezmoi is already initialized at $chezmoi_source."
  print_next_steps
  exit 0
fi

echo "Initializing chezmoi from $repo_url."
"$chezmoi_bin" init "$repo_url"

echo "chezmoi initialization completed without applying changes."
print_next_steps
