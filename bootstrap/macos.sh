#!/usr/bin/env bash
set -euo pipefail

repo_url="${DOTFILES_REPO_URL:-https://github.com/jukrb0x/dotfiles.git}"
brew_bin="/opt/homebrew/bin/brew"
chezmoi_source="$HOME/.local/share/chezmoi"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap supports macOS arm64 only." >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This bootstrap supports macOS arm64 only." >&2
  exit 1
fi

if [[ ! -x "$brew_bin" ]]; then
  echo "Homebrew is missing; installing Homebrew."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
